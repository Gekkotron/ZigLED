#include "freertos/FreeRTOS.h"

// Mutual exclusion for zigbee_iface.zig's CommandQueue, which is written
// from the Zigbee task (producer) and read from the render task (consumer).
// A cImport of FreeRTOS headers directly inside zigbee_iface.zig would break
// that file's host-test compilation (the host test module has no ESP-IDF
// include paths), so the lock lives here in a small C shim instead; Zig
// calls these two exports only on the freestanding (on-device) target.

static portMUX_TYPE s_queue_lock = portMUX_INITIALIZER_UNLOCKED;

void zigled_queue_lock(void);
void zigled_queue_unlock(void);

void zigled_queue_lock(void) {
    taskENTER_CRITICAL(&s_queue_lock);
}

void zigled_queue_unlock(void) {
    taskEXIT_CRITICAL(&s_queue_lock);
}
