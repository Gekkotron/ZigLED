#include "esp_zb_endpoint.h"
#include "esp_zigbee_core.h"
#include "ha/esp_zigbee_ha_standard.h"
#include "nwk/esp_zigbee_nwk.h"
#include "zdo/esp_zigbee_zdo_common.h"
#include "esp_log.h"
#include "esp_check.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "zig_bindings.h"
#include "sensor.h"

static const char *TAG = "ZIGLED_ZB";

#define EP_ID           1
#define EP_ID_SENSOR    2
#define MFG_CLUSTER_ID  0xFC01
#define MFG_CODE        0x1337

static volatile bool s_connected = false;

bool zigled_zb_connected(void) { return s_connected; }

static esp_err_t esp_zb_action_handler(esp_zb_core_action_callback_id_t id, const void *msg) {
    ESP_LOGI(TAG, "action id=0x%x", id);
    if (id != ESP_ZB_CORE_SET_ATTR_VALUE_CB_ID) return ESP_OK;
    const esp_zb_zcl_set_attr_value_message_t *m = msg;
    ESP_LOGI(TAG, "set_attr ep=%d cluster=0x%04x attr=0x%04x type=0x%x",
        m->info.dst_endpoint, m->info.cluster, m->attribute.id, m->attribute.data.type);
    switch (m->info.cluster) {
        case ESP_ZB_ZCL_CLUSTER_ID_ON_OFF:
            if (m->attribute.id == ESP_ZB_ZCL_ATTR_ON_OFF_ON_OFF_ID)
                zigled_on_onoff(*(bool *)m->attribute.data.value);
            break;
        case ESP_ZB_ZCL_CLUSTER_ID_LEVEL_CONTROL:
            if (m->attribute.id == ESP_ZB_ZCL_ATTR_LEVEL_CONTROL_CURRENT_LEVEL_ID)
                zigled_on_level(*(uint8_t *)m->attribute.data.value);
            break;
        case ESP_ZB_ZCL_CLUSTER_ID_COLOR_CONTROL: {
            static uint16_t last_x = 0, last_y = 0;
            if (m->attribute.id == ESP_ZB_ZCL_ATTR_COLOR_CONTROL_CURRENT_X_ID)
                last_x = *(uint16_t *)m->attribute.data.value;
            else if (m->attribute.id == ESP_ZB_ZCL_ATTR_COLOR_CONTROL_CURRENT_Y_ID)
                last_y = *(uint16_t *)m->attribute.data.value;
            zigled_on_color_xy(last_x, last_y);
            break;
        }
        case ESP_ZB_ZCL_CLUSTER_ID_IDENTIFY:
            if (m->attribute.id == ESP_ZB_ZCL_ATTR_IDENTIFY_IDENTIFY_TIME_ID)
                zigled_on_identify(*(uint16_t *)m->attribute.data.value);
            break;
        case MFG_CLUSTER_ID:
            ESP_LOGI(TAG, "mfg cluster write attr=0x%04x", m->attribute.id);
            switch (m->attribute.id) {
                case 0x0000: zigled_on_mfg_effect(*(uint16_t *)m->attribute.data.value); break;
                case 0x0001: zigled_on_mfg_speed(*(uint8_t *)m->attribute.data.value); break;
                case 0x0002: zigled_on_mfg_intensity(*(uint8_t *)m->attribute.data.value); break;
                case 0x0003: zigled_on_mfg_palette(*(uint8_t *)m->attribute.data.value); break;
                case 0x000A: zigled_on_mfg_active_count(*(uint16_t *)m->attribute.data.value); break;
            }
            break;
        case ESP_ZB_ZCL_CLUSTER_ID_OCCUPANCY_SENSING:
            if (m->attribute.id == ESP_ZB_ZCL_ATTR_OCCUPANCY_SENSING_PIR_OCC_TO_UNOCC_DELAY_ID) {
                uint16_t delay_s = *(uint16_t *)m->attribute.data.value;
                zigled_sensor_set_unoccupied_delay_s(delay_s);
                zigled_set_pir_unoccupied_delay_s(delay_s);
            }
            break;
        default:
            ESP_LOGW(TAG, "unhandled cluster 0x%04x", m->info.cluster);
            break;
    }
    return ESP_OK;
}

static void register_mfg_cluster(esp_zb_cluster_list_t *cluster_list) {
    esp_zb_attribute_list_t *mfg_attr_list = esp_zb_zcl_attr_list_create(MFG_CLUSTER_ID);

    static uint16_t effect_id_default = 0;
    static uint8_t  effect_speed_default = 128;
    static uint8_t  effect_intensity_default = 128;
    static uint8_t  palette_id_default = 0;
    static uint16_t effect_count_default = 8;   // strip build filters plasma_2d out
    static uint16_t pixel_count_default = 120;
    static uint8_t  layout_kind_default = 0;    // strip
    static uint16_t layout_width_default = 0;
    static uint16_t layout_height_default = 0;
    static uint16_t active_count_default = 120;   /* physical cap; sync pushes real value at join */

    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0000,
        ESP_ZB_ZCL_ATTR_TYPE_U16,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_WRITE | ESP_ZB_ZCL_ATTR_ACCESS_REPORTING,
        &effect_id_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0001,
        ESP_ZB_ZCL_ATTR_TYPE_U8,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_WRITE | ESP_ZB_ZCL_ATTR_ACCESS_REPORTING,
        &effect_speed_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0002,
        ESP_ZB_ZCL_ATTR_TYPE_U8,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_WRITE | ESP_ZB_ZCL_ATTR_ACCESS_REPORTING,
        &effect_intensity_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0003,
        ESP_ZB_ZCL_ATTR_TYPE_U8,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_WRITE | ESP_ZB_ZCL_ATTR_ACCESS_REPORTING,
        &palette_id_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0004,
        ESP_ZB_ZCL_ATTR_TYPE_U16, ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        &effect_count_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0006,
        ESP_ZB_ZCL_ATTR_TYPE_U16, ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        &pixel_count_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0007,
        ESP_ZB_ZCL_ATTR_TYPE_8BIT_ENUM, ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        &layout_kind_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0008,
        ESP_ZB_ZCL_ATTR_TYPE_U16, ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        &layout_width_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x0009,
        ESP_ZB_ZCL_ATTR_TYPE_U16, ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        &layout_height_default);
    esp_zb_custom_cluster_add_custom_attr(mfg_attr_list, 0x000A,
        ESP_ZB_ZCL_ATTR_TYPE_U16,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_WRITE | ESP_ZB_ZCL_ATTR_ACCESS_REPORTING,
        &active_count_default);

    esp_zb_cluster_list_add_custom_cluster(cluster_list, mfg_attr_list,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE);
}

static void override_basic_identity(esp_zb_cluster_list_t *cluster_list) {
    esp_zb_attribute_list_t *basic_cluster = esp_zb_cluster_list_get_cluster(
        cluster_list, ESP_ZB_ZCL_CLUSTER_ID_BASIC, ESP_ZB_ZCL_CLUSTER_SERVER_ROLE);
    esp_zb_cluster_add_attr(basic_cluster,
        ESP_ZB_ZCL_CLUSTER_ID_BASIC,
        ESP_ZB_ZCL_ATTR_BASIC_MANUFACTURER_NAME_ID,
        ESP_ZB_ZCL_ATTR_TYPE_CHAR_STRING,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        (void *)"\x09Gekkotron");
    esp_zb_cluster_add_attr(basic_cluster,
        ESP_ZB_ZCL_CLUSTER_ID_BASIC,
        ESP_ZB_ZCL_ATTR_BASIC_MODEL_IDENTIFIER_ID,
        ESP_ZB_ZCL_ATTR_TYPE_CHAR_STRING,
        ESP_ZB_ZCL_ATTR_ACCESS_READ_ONLY,
        (void *)"\x08ZigLED-1");
}

static void report_light_state_to_coordinator(void) {
    /* Explicit Report Attributes for every endpoint-1 attribute Z2M cares
       about — light state (on/off, level, color) and the ZigLED mfg
       cluster (effect, speed, intensity, palette) — so the coordinator
       learns the current values at (re)join without waiting for a change
       or Read. Same pattern as the on-change report in sensor.c. */
    static const uint16_t ep1_attrs[][2] = {
        {ESP_ZB_ZCL_CLUSTER_ID_ON_OFF,        ESP_ZB_ZCL_ATTR_ON_OFF_ON_OFF_ID},
        {ESP_ZB_ZCL_CLUSTER_ID_LEVEL_CONTROL, ESP_ZB_ZCL_ATTR_LEVEL_CONTROL_CURRENT_LEVEL_ID},
        {ESP_ZB_ZCL_CLUSTER_ID_COLOR_CONTROL, ESP_ZB_ZCL_ATTR_COLOR_CONTROL_CURRENT_X_ID},
        {ESP_ZB_ZCL_CLUSTER_ID_COLOR_CONTROL, ESP_ZB_ZCL_ATTR_COLOR_CONTROL_CURRENT_Y_ID},
        {MFG_CLUSTER_ID, 0x0000},   /* effect */
        {MFG_CLUSTER_ID, 0x0001},   /* effect_speed */
        {MFG_CLUSTER_ID, 0x0002},   /* effect_intensity */
        {MFG_CLUSTER_ID, 0x0003},   /* palette */
        /* 0x000A active_count is NOT pushed on-join: the SDK's
           esp_zb_zcl_report_attr_cmd_req asserts when the reporting_info
           table lacks an entry for a manufacturer-cluster attribute,
           which happens for any attribute that was added AFTER the
           coordinator's last ConfigureReporting round for this device.
           The value is still written to the ZCL attribute cache in
           sync_attrs_from_nvs above, so Z2M reads it on-demand and the
           entity populates on next interview. Re-pairing the device
           lets Z2M configure reporting for it and this line can be
           re-enabled at that point. */
    };
    for (size_t i = 0; i < sizeof(ep1_attrs) / sizeof(ep1_attrs[0]); i++) {
        esp_zb_zcl_report_attr_cmd_t r = {
            .zcl_basic_cmd = {
                .dst_addr_u.addr_short = 0x0000,
                .dst_endpoint = 1,
                .src_endpoint = EP_ID,
            },
            .address_mode = ESP_ZB_APS_ADDR_MODE_16_ENDP_PRESENT,
            .clusterID = ep1_attrs[i][0],
            .direction = ESP_ZB_ZCL_CMD_DIRECTION_TO_CLI,
            .attributeID = ep1_attrs[i][1],
        };
        esp_err_t rc = esp_zb_zcl_report_attr_cmd_req(&r);
        if (rc != ESP_OK) {
            ESP_LOGW(TAG, "on-join report cluster=0x%04x attr=0x%04x FAILED rc=%s",
                     ep1_attrs[i][0], ep1_attrs[i][1], esp_err_to_name(rc));
        }
    }
    ESP_LOGI(TAG, "on-join Report Attributes sent for endpoint-1 state (light + mfg cluster)");
}

static const char *nlme_status_name(uint8_t s) {
    switch (s) {
        case ESP_ZB_NWK_COMMAND_STATUS_NO_ROUTE_AVAILABLE:          return "NO_ROUTE_AVAILABLE";
        case ESP_ZB_NWK_COMMAND_STATUS_TREE_LINK_FAILURE:           return "TREE_LINK_FAILURE";
        case ESP_ZB_NWK_COMMAND_STATUS_NONE_TREE_LINK_FAILURE:      return "NONE_TREE_LINK_FAILURE";
        case ESP_ZB_NWK_COMMAND_STATUS_LOW_BATTERY_LEVEL:           return "LOW_BATTERY_LEVEL";
        case ESP_ZB_NWK_COMMAND_STATUS_NO_ROUTING_CAPACITY:         return "NO_ROUTING_CAPACITY";
        case ESP_ZB_NWK_COMMAND_STATUS_NO_INDIRECT_CAPACITY:        return "NO_INDIRECT_CAPACITY";
        case ESP_ZB_NWK_COMMAND_STATUS_INDIRECT_TRANSACTION_EXPIRY: return "INDIRECT_TRANSACTION_EXPIRY";
        case ESP_ZB_NWK_COMMAND_STATUS_TARGET_DEVICE_UNAVAILABLE:   return "TARGET_DEVICE_UNAVAILABLE";
        case ESP_ZB_NWK_COMMAND_STATUS_TARGET_ADDRESS_UNALLOCATED:  return "TARGET_ADDRESS_UNALLOCATED";
        case ESP_ZB_NWK_COMMAND_STATUS_PARENT_LINK_FAILURE:         return "PARENT_LINK_FAILURE";
        case ESP_ZB_NWK_COMMAND_STATUS_VALIDATE_ROUTE:              return "VALIDATE_ROUTE";
        case ESP_ZB_NWK_COMMAND_STATUS_SOURCE_ROUTE_FAILURE:        return "SOURCE_ROUTE_FAILURE";
        case ESP_ZB_NWK_COMMAND_STATUS_MANY_TO_ONE_ROUTE_FAILURE:   return "MANY_TO_ONE_ROUTE_FAILURE";
        case ESP_ZB_NWK_COMMAND_STATUS_ADDRESS_CONFLICT:            return "ADDRESS_CONFLICT";
        case ESP_ZB_NWK_COMMAND_STATUS_VERIFY_ADDRESS:              return "VERIFY_ADDRESS";
        case ESP_ZB_NWK_COMMAND_STATUS_PAN_IDENTIFIER_UPDATE:       return "PAN_IDENTIFIER_UPDATE";
        case ESP_ZB_NWK_COMMAND_STATUS_NETWORK_ADDRESS_UPDATE:      return "NETWORK_ADDRESS_UPDATE";
        case ESP_ZB_NWK_COMMAND_STATUS_BAD_FRAME_COUNTER:           return "BAD_FRAME_COUNTER";
        case ESP_ZB_NWK_COMMAND_STATUS_BAD_KEY_SEQUENCE_NUMBER:     return "BAD_KEY_SEQUENCE_NUMBER";
        case ESP_ZB_NWK_COMMAND_STATUS_UNKNOWN_COMMAND:             return "UNKNOWN_COMMAND";
        default: return "?";
    }
}

static void sync_attrs_from_nvs(void) {
    bool on = zigled_get_on();
    uint8_t level = zigled_get_level();
    uint16_t x = zigled_get_color_x();
    uint16_t y = zigled_get_color_y();
    uint16_t eff = zigled_get_effect_id();
    uint8_t spd = zigled_get_effect_speed();
    uint8_t ins = zigled_get_effect_intensity();
    uint8_t pal = zigled_get_palette_id();
    uint16_t acnt = zigled_get_active_count();

    esp_zb_lock_acquire(portMAX_DELAY);
    esp_zb_zcl_set_attribute_val(EP_ID, ESP_ZB_ZCL_CLUSTER_ID_ON_OFF,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE,
        ESP_ZB_ZCL_ATTR_ON_OFF_ON_OFF_ID, &on, false);
    esp_zb_zcl_set_attribute_val(EP_ID, ESP_ZB_ZCL_CLUSTER_ID_LEVEL_CONTROL,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE,
        ESP_ZB_ZCL_ATTR_LEVEL_CONTROL_CURRENT_LEVEL_ID, &level, false);
    esp_zb_zcl_set_attribute_val(EP_ID, ESP_ZB_ZCL_CLUSTER_ID_COLOR_CONTROL,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE,
        ESP_ZB_ZCL_ATTR_COLOR_CONTROL_CURRENT_X_ID, &x, false);
    esp_zb_zcl_set_attribute_val(EP_ID, ESP_ZB_ZCL_CLUSTER_ID_COLOR_CONTROL,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE,
        ESP_ZB_ZCL_ATTR_COLOR_CONTROL_CURRENT_Y_ID, &y, false);
    esp_zb_zcl_set_attribute_val(EP_ID, MFG_CLUSTER_ID,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE, 0x0000, &eff, false);
    esp_zb_zcl_set_attribute_val(EP_ID, MFG_CLUSTER_ID,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE, 0x0001, &spd, false);
    esp_zb_zcl_set_attribute_val(EP_ID, MFG_CLUSTER_ID,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE, 0x0002, &ins, false);
    esp_zb_zcl_set_attribute_val(EP_ID, MFG_CLUSTER_ID,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE, 0x0003, &pal, false);
    esp_zb_zcl_set_attribute_val(EP_ID, MFG_CLUSTER_ID,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE, 0x000A, &acnt, false);
    report_light_state_to_coordinator();
    esp_zb_lock_release();

    if (zigled_get_pir_enabled()) {
        zigled_sensor_republish_current();
    }
}

/* Called by esp_zb_scheduler_alarm; the SDK's callback prototype takes a
   uint8_t so we can't use sync_attrs_from_nvs directly. */
static void deferred_sync_cb(uint8_t param) {
    (void)param;
    sync_attrs_from_nvs();
}

/* Same reason as deferred_sync_cb: the commissioning entry point returns
   esp_err_t, so it can't be cast to esp_zb_callback_t (void return)
   without a -Wcast-function-type warning. The wrapper discards the
   return value. */
static void deferred_start_steering_cb(uint8_t param) {
    (void)esp_zb_bdb_start_top_level_commissioning(param);
}

/* Delay chosen so a fresh interview (up to ~10 s of ZDO round-trips
   including Simple_Desc_req per endpoint) can finish before we start
   flooding the coordinator with Report Attributes commands. On rejoin
   the interview is already cached so the wait is pure UI latency. */
#define ZIGLED_JOIN_SYNC_DELAY_MS 12000

static void esp_zb_task(void *pv) {
    ESP_LOGI(TAG, "esp_zb_task started");
    esp_zb_cfg_t zb_cfg = {
        .esp_zb_role = ESP_ZB_DEVICE_TYPE_ROUTER,
        .install_code_policy = false,
        .nwk_cfg.zczr_cfg = {.max_children = 10},
    };
    esp_zb_init(&zb_cfg);

    esp_zb_ep_list_t *ep_list = esp_zb_ep_list_create();
    esp_zb_color_dimmable_light_cfg_t light_cfg = ESP_ZB_DEFAULT_COLOR_DIMMABLE_LIGHT_CONFIG();
    esp_zb_cluster_list_t *cluster_list = esp_zb_color_dimmable_light_clusters_create(&light_cfg);

    register_mfg_cluster(cluster_list);
    override_basic_identity(cluster_list);

    esp_zb_endpoint_config_t ep_cfg = {
        .endpoint = EP_ID,
        .app_profile_id = ESP_ZB_AF_HA_PROFILE_ID,
        .app_device_id = ESP_ZB_HA_COLOR_DIMMABLE_LIGHT_DEVICE_ID,
        .app_device_version = 0,
    };
    esp_zb_ep_list_add_ep(ep_list, cluster_list, ep_cfg);

    if (zigled_get_pir_enabled()) {
        esp_zb_cluster_list_t *sensor_list = esp_zb_zcl_cluster_list_create();

        esp_zb_attribute_list_t *basic_s = esp_zb_basic_cluster_create(NULL);
        esp_zb_cluster_list_add_basic_cluster(sensor_list, basic_s, ESP_ZB_ZCL_CLUSTER_SERVER_ROLE);
        esp_zb_attribute_list_t *ident_s = esp_zb_identify_cluster_create(NULL);
        esp_zb_cluster_list_add_identify_cluster(sensor_list, ident_s, ESP_ZB_ZCL_CLUSTER_SERVER_ROLE);

        esp_zb_occupancy_sensing_cluster_cfg_t occ_cfg = {
            .occupancy = 0,
            .sensor_type = 0,          /* 0 = PIR */
            .sensor_type_bitmap = 1,   /* bit 0 = PIR */
        };
        esp_zb_attribute_list_t *occ_attrs = esp_zb_occupancy_sensing_cluster_create(&occ_cfg);
        static uint16_t occ_delay_default = 60;
        esp_zb_cluster_add_attr(occ_attrs,
            ESP_ZB_ZCL_CLUSTER_ID_OCCUPANCY_SENSING,
            ESP_ZB_ZCL_ATTR_OCCUPANCY_SENSING_PIR_OCC_TO_UNOCC_DELAY_ID,
            ESP_ZB_ZCL_ATTR_TYPE_U16,
            ESP_ZB_ZCL_ATTR_ACCESS_READ_WRITE,
            &occ_delay_default);
        esp_zb_cluster_list_add_occupancy_sensing_cluster(sensor_list, occ_attrs, ESP_ZB_ZCL_CLUSTER_SERVER_ROLE);

        esp_zb_endpoint_config_t sensor_ep_cfg = {
            .endpoint = EP_ID_SENSOR,
            .app_profile_id = ESP_ZB_AF_HA_PROFILE_ID,
            .app_device_id = 0x0107,   /* HA Occupancy Sensor device ID */
            .app_device_version = 0,
        };
        esp_zb_ep_list_add_ep(ep_list, sensor_list, sensor_ep_cfg);
    }

    esp_zb_device_register(ep_list);

    esp_zb_set_primary_network_channel_set(1u << 15);
    int8_t tx = zigled_get_tx_power_dbm();
    esp_zb_set_tx_power(tx);
    esp_zb_core_action_handler_register(esp_zb_action_handler);
    ESP_LOGI(TAG, "esp_zb_start (autostart=false)");
    ESP_ERROR_CHECK(esp_zb_start(false));
    esp_zb_set_tx_power(tx);
    ESP_LOGI(TAG, "TX power set to %d dBm (post-start reaffirm)", tx);
    ESP_LOGI(TAG, "esp_zb_stack_main_loop entering");
    esp_zb_stack_main_loop();
}

void esp_zb_app_signal_handler(esp_zb_app_signal_t *signal_struct) {
    uint32_t *p_sg_p = signal_struct->p_app_signal;
    esp_err_t err_status = signal_struct->esp_err_status;
    esp_zb_app_signal_type_t sig_type = *p_sg_p;
    switch (sig_type) {
        case ESP_ZB_ZDO_SIGNAL_SKIP_STARTUP:
            ESP_LOGI(TAG, "SKIP_STARTUP -> BDB initialization");
            esp_zb_bdb_start_top_level_commissioning(ESP_ZB_BDB_MODE_INITIALIZATION);
            break;
        case ESP_ZB_BDB_SIGNAL_DEVICE_FIRST_START:
        case ESP_ZB_BDB_SIGNAL_DEVICE_REBOOT:
            if (err_status == ESP_OK) {
                if (esp_zb_bdb_is_factory_new()) {
                    ESP_LOGI(TAG, "factory new, starting network steering");
                    esp_zb_bdb_start_top_level_commissioning(ESP_ZB_BDB_MODE_NETWORK_STEERING);
                } else {
                    s_connected = true;
                    zigled_zb_set_connected(true);
                    esp_zb_scheduler_alarm(deferred_sync_cb, 0, ZIGLED_JOIN_SYNC_DELAY_MS);
                    ESP_LOGI(TAG, "rejoined network — sync scheduled in %d ms",
                        ZIGLED_JOIN_SYNC_DELAY_MS);
                }
            } else {
                ESP_LOGE(TAG, "BDB start failed: %s", esp_err_to_name(err_status));
            }
            break;
        case ESP_ZB_BDB_SIGNAL_STEERING:
            if (err_status == ESP_OK) {
                s_connected = true;
                zigled_zb_set_connected(true);
                esp_zb_scheduler_alarm(deferred_sync_cb, 0, ZIGLED_JOIN_SYNC_DELAY_MS);
                ESP_LOGI(TAG, "joined network (channel=%d, pan=0x%04x) — sync scheduled in %d ms",
                    esp_zb_get_current_channel(), esp_zb_get_pan_id(),
                    ZIGLED_JOIN_SYNC_DELAY_MS);
            } else {
                ESP_LOGW(TAG, "steering failed (%s), retry in 1s", esp_err_to_name(err_status));
                esp_zb_scheduler_alarm(deferred_start_steering_cb, ESP_ZB_BDB_MODE_NETWORK_STEERING, 1000);
            }
            break;
        case ESP_ZB_ZDO_SIGNAL_LEAVE:
            ESP_LOGI(TAG, "LEAVE signal");
            s_connected = false;
            zigled_zb_set_connected(false);
            break;
        case ESP_ZB_NLME_STATUS_INDICATION: {
            /* Almost always about routes to OTHER devices (this router
               being asked to forward). Decoded so it's clear it isn't our
               own reports failing. */
            esp_zb_zdo_signal_nwk_status_indication_params_t *p =
                (esp_zb_zdo_signal_nwk_status_indication_params_t *)esp_zb_app_signal_get_params(p_sg_p);
            if (p != NULL) {
                ESP_LOGW(TAG, "NLME_STATUS_INDICATION status=0x%02x (%s) net_addr=0x%04x cmd_id=0x%02x",
                    p->status, nlme_status_name(p->status), p->network_addr, p->unknown_command_id);
            } else {
                ESP_LOGW(TAG, "NLME_STATUS_INDICATION (no params)");
            }
            break;
        }
        default:
            ESP_LOGI(TAG, "signal 0x%x status=%s",
                sig_type, esp_err_to_name(err_status));
            break;
    }
}

void zigled_zb_init(void) {
    esp_zb_platform_config_t cfg = {
        .radio_config = {.radio_mode = ZB_RADIO_MODE_NATIVE},
        .host_config = {.host_connection_mode = ZB_HOST_CONNECTION_MODE_NONE},
    };
    ESP_ERROR_CHECK(esp_zb_platform_config(&cfg));
    xTaskCreate(esp_zb_task, "esp_zb", 4096, NULL, 5, NULL);
}
