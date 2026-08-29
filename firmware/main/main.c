#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "zig_bindings.h"
#include "esp_zb_endpoint.h"
#include "sensor.h"

static const char *TAG = "ZIGLED_BOOT";

#define OCCUPANCY_EP_ID  2

static void select_external_antenna(void) {
    uint8_t rf_pwr = zigled_get_antenna_rf_power_gpio();
    uint8_t sel    = zigled_get_antenna_select_gpio();
    gpio_config_t io = {
        .pin_bit_mask = (1ULL << rf_pwr) | (1ULL << sel),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&io));
    gpio_set_level(rf_pwr, 0);  /* RF switch power on (active low) */
    gpio_set_level(sel, 1);     /* select external antenna */
    ESP_LOGI(TAG, "external antenna selected (rf_pwr=GPIO%d LOW, sel=GPIO%d HIGH)", rf_pwr, sel);
}

void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    ESP_LOGI(TAG, "%s", zigled_greet());
    if (zigled_get_external_antenna()) {
        select_external_antenna();
    }
    zigled_start();
    zigled_zb_init();
    if (zigled_get_pir_enabled()) {
        zigled_sensor_init(zigled_get_pir_gpio(), OCCUPANCY_EP_ID, zigled_get_pir_unoccupied_delay_s());
    }
    vTaskDelay(portMAX_DELAY);
}
