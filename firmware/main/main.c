#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "zig_bindings.h"

static const char *TAG = "ZIGLED_BOOT";

void app_main(void) {
    ESP_LOGI(TAG, "%s", zigled_greet());
    zigled_led_output_init(2, 120);

    uint8_t frame[360] = {0};
    for (int i = 0; i < 120; i++) {
        frame[i * 3 + 0] = 10;
        frame[i * 3 + 1] = 0;
        frame[i * 3 + 2] = 0;
    }
    zigled_led_output_push(frame, sizeof(frame));
    vTaskDelay(portMAX_DELAY);
}
