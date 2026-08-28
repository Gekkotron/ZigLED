#include "esp_zb_endpoint.h"
#include "esp_zigbee_core.h"
#include "ha/esp_zigbee_ha_standard.h"
#include "esp_log.h"
#include "esp_check.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "zig_bindings.h"

static const char *TAG = "ZIGLED_ZB";

#define EP_ID           1
#define MFG_CLUSTER_ID  0xFC01
#define MFG_CODE        0x1337

static volatile bool s_connected = false;

bool zigled_zb_connected(void) { return s_connected; }

static esp_err_t esp_zb_action_handler(esp_zb_core_action_callback_id_t id, const void *msg) {
    if (id != ESP_ZB_CORE_SET_ATTR_VALUE_CB_ID) return ESP_OK;
    const esp_zb_zcl_set_attr_value_message_t *m = msg;
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
            switch (m->attribute.id) {
                case 0x0000: zigled_on_mfg_effect(*(uint16_t *)m->attribute.data.value); break;
                case 0x0001: zigled_on_mfg_speed(*(uint8_t *)m->attribute.data.value); break;
                case 0x0002: zigled_on_mfg_intensity(*(uint8_t *)m->attribute.data.value); break;
                case 0x0003: zigled_on_mfg_palette(*(uint8_t *)m->attribute.data.value); break;
            }
            break;
    }
    return ESP_OK;
}

static void esp_zb_task(void *pv) {
    esp_zb_cfg_t zb_cfg = {
        .esp_zb_role = ESP_ZB_DEVICE_TYPE_ROUTER,
        .install_code_policy = false,
        .nwk_cfg.zczr_cfg = {.max_children = 10},
    };
    esp_zb_init(&zb_cfg);

    esp_zb_ep_list_t *ep_list = esp_zb_ep_list_create();
    esp_zb_color_dimmable_light_cfg_t light_cfg = ESP_ZB_DEFAULT_COLOR_DIMMABLE_LIGHT_CONFIG();
    esp_zb_cluster_list_t *cluster_list = esp_zb_color_dimmable_light_clusters_create(&light_cfg);

    esp_zb_endpoint_config_t ep_cfg = {
        .endpoint = EP_ID,
        .app_profile_id = ESP_ZB_AF_HA_PROFILE_ID,
        .app_device_id = ESP_ZB_HA_COLOR_DIMMABLE_LIGHT_DEVICE_ID,
        .app_device_version = 0,
    };
    esp_zb_ep_list_add_ep(ep_list, cluster_list, ep_cfg);
    esp_zb_device_register(ep_list);

    esp_zb_set_primary_network_channel_set(ESP_ZB_TRANSCEIVER_ALL_CHANNELS_MASK);
    esp_zb_core_action_handler_register(esp_zb_action_handler);
    ESP_ERROR_CHECK(esp_zb_start(false));
    esp_zb_stack_main_loop();
}

void esp_zb_app_signal_handler(esp_zb_app_signal_t *signal_struct) {
    uint32_t *p_sg_p = signal_struct->p_app_signal;
    esp_err_t err_status = signal_struct->esp_err_status;
    esp_zb_app_signal_type_t sig_type = *p_sg_p;
    switch (sig_type) {
        case ESP_ZB_ZDO_SIGNAL_SKIP_STARTUP:
            esp_zb_bdb_start_top_level_commissioning(ESP_ZB_BDB_MODE_INITIALIZATION);
            break;
        case ESP_ZB_BDB_SIGNAL_DEVICE_FIRST_START:
        case ESP_ZB_BDB_SIGNAL_DEVICE_REBOOT:
            if (err_status == ESP_OK) {
                if (esp_zb_bdb_is_factory_new()) {
                    esp_zb_bdb_start_top_level_commissioning(ESP_ZB_BDB_MODE_NETWORK_STEERING);
                } else {
                    s_connected = true;
                    ESP_LOGI(TAG, "rejoined network");
                }
            }
            break;
        case ESP_ZB_BDB_SIGNAL_STEERING:
            if (err_status == ESP_OK) {
                s_connected = true;
                ESP_LOGI(TAG, "joined network");
            } else {
                esp_zb_scheduler_alarm((esp_zb_callback_t)esp_zb_bdb_start_top_level_commissioning, ESP_ZB_BDB_MODE_NETWORK_STEERING, 1000);
            }
            break;
        default:
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
