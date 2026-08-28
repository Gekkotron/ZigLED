#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "ZIGLED_BOOT";

void app_main(void) {
    ESP_LOGI(TAG, "hello");
    vTaskDelay(portMAX_DELAY);
}
