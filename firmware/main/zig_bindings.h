#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *zigled_greet(void);

void zigled_led_output_init(uint8_t gpio, uint16_t count);
void zigled_led_output_push(const uint8_t *bytes, uint32_t len);

#ifdef __cplusplus
}
#endif
