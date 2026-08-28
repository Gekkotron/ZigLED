#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "zig_bindings.h"
#include "esp_zb_endpoint.h"

static const char *TAG = "ZIGLED_BOOT";

void app_main(void) {
    ESP_ERROR_CHECK(nvs_flash_init());
    ESP_LOGI(TAG, "%s", zigled_greet());
    zigled_led_output_init(2, 120);
    zigled_zb_init();
    vTaskDelay(portMAX_DELAY);
}
