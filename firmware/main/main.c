#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "zig_bindings.h"

static const char *TAG = "ZIGLED_BOOT";

void app_main(void) {
    ESP_LOGI(TAG, "%s", zigled_greet());
    vTaskDelay(portMAX_DELAY);
}
