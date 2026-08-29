#include "sensor.h"
#include "esp_zb_endpoint.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/timers.h"
#include "esp_zigbee_core.h"

static const char *TAG = "ZIGLED_PIR";

static uint8_t s_gpio = 0;
static uint8_t s_endpoint = 0;
static volatile uint32_t s_delay_s = 60;
static volatile bool s_occupied = false;

static TaskHandle_t s_task = NULL;
static TimerHandle_t s_timer = NULL;

static void IRAM_ATTR gpio_isr(void *arg) {
    (void)arg;
    BaseType_t woken = pdFALSE;
    uint32_t level = gpio_get_level(s_gpio);
    if (s_task != NULL) {
        xTaskNotifyFromISR(s_task, level, eSetValueWithOverwrite, &woken);
    }
    if (woken) portYIELD_FROM_ISR();
}

static void publish_occupancy(bool occupied) {
    s_occupied = occupied;
    ESP_LOGI(TAG, "occupancy=%d (pushing to Zigbee attribute cache + triggering report)", occupied);
    if (!zigled_zb_connected()) {
        ESP_LOGW(TAG, "not connected to Zigbee network — value cached locally only");
        return;
    }
    uint8_t val = occupied ? 1 : 0;
    esp_zb_lock_acquire(portMAX_DELAY);
    esp_zb_zcl_set_attribute_val(
        s_endpoint,
        ESP_ZB_ZCL_CLUSTER_ID_OCCUPANCY_SENSING,
        ESP_ZB_ZCL_CLUSTER_SERVER_ROLE,
        ESP_ZB_ZCL_ATTR_OCCUPANCY_SENSING_OCCUPANCY_ID,   /* 0x0000 */
        &val,
        true);   /* check_change=true so a report fires when it flips */
    esp_zb_lock_release();
}

static void unoccupied_timer_cb(TimerHandle_t xTimer) {
    (void)xTimer;
    publish_occupancy(false);
}

static void sensor_task(void *pv) {
    (void)pv;
    for (;;) {
        uint32_t level = 0;
        if (xTaskNotifyWait(0, 0xffffffff, &level, portMAX_DELAY) != pdTRUE) continue;
        if (level != 0) {
            ESP_LOGI(TAG, "PIR input HIGH (motion detected) — occupied=%d delay_s=%u", s_occupied, (unsigned)s_delay_s);
            if (xTimerIsTimerActive(s_timer) != pdFALSE) xTimerStop(s_timer, portMAX_DELAY);
            if (!s_occupied) publish_occupancy(true);
        } else {
            ESP_LOGI(TAG, "PIR input LOW (motion ended) — occupied=%d, will report unoccupied in %us", s_occupied, (unsigned)s_delay_s);
            if (s_delay_s == 0) {
                ESP_LOGW(TAG, "delay_s=0, publishing unoccupied immediately (set occupancy_timeout > 0 in Z2M)");
                if (s_occupied) publish_occupancy(false);
            } else {
                xTimerChangePeriod(s_timer, pdMS_TO_TICKS(s_delay_s * 1000), portMAX_DELAY);
            }
        }
    }
}

void zigled_sensor_init(uint8_t gpio, uint8_t endpoint_id, uint16_t default_delay_s) {
    s_gpio = gpio;
    s_endpoint = endpoint_id;
    /* 0 means "publish false the moment the PIR line drops" per the ZCL
       spec, which produces spike behavior most people don't want. Clamp
       to at least 5 s at boot; user can lower back down explicitly via
       the occupancy_timeout Z2M entity if they really want 0. */
    s_delay_s = (default_delay_s == 0) ? 5 : default_delay_s;

    gpio_config_t io = {
        .pin_bit_mask = 1ULL << gpio,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_ENABLE,
        .intr_type = GPIO_INTR_ANYEDGE,
    };
    ESP_ERROR_CHECK(gpio_config(&io));

    s_timer = xTimerCreate("pir_off", pdMS_TO_TICKS((TickType_t)default_delay_s * 1000),
                           pdFALSE, NULL, unoccupied_timer_cb);
    if (s_timer == NULL) {
        ESP_LOGE(TAG, "xTimerCreate failed");
        return;
    }

    xTaskCreate(sensor_task, "pir", 3072, NULL, 4, &s_task);

    static bool isr_service_installed = false;
    if (!isr_service_installed) {
        esp_err_t err = gpio_install_isr_service(0);
        if (err != ESP_OK && err != ESP_ERR_INVALID_STATE) {
            ESP_ERROR_CHECK(err);
        }
        isr_service_installed = true;
    }
    ESP_ERROR_CHECK(gpio_isr_handler_add(gpio, gpio_isr, NULL));

    ESP_LOGI(TAG, "PIR init gpio=%d ep=%d delay=%us", gpio, endpoint_id, default_delay_s);
}

void zigled_sensor_set_unoccupied_delay_s(uint16_t delay_s) {
    s_delay_s = delay_s;
    ESP_LOGI(TAG, "delay updated to %us", delay_s);
}

bool zigled_sensor_get_occupied(void) {
    return s_occupied;
}
