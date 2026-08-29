#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "zig_bindings.h"
#include "esp_zb_endpoint.h"
#include "sensor.h"

static const char *TAG = "ZIGLED_BOOT";

#define PIR_GPIO         3
#define OCCUPANCY_EP_ID  2

void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    ESP_LOGI(TAG, "%s", zigled_greet());
    zigled_start();
    zigled_zb_init();
    zigled_sensor_init(PIR_GPIO, OCCUPANCY_EP_ID, zigled_get_pir_unoccupied_delay_s());
    vTaskDelay(portMAX_DELAY);
}
