#pragma once
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void zigled_sensor_init(uint8_t gpio, uint8_t endpoint_id, uint16_t default_delay_s);
void zigled_sensor_set_unoccupied_delay_s(uint16_t delay_s);
bool zigled_sensor_get_occupied(void);
void zigled_sensor_republish_current(void);

#ifdef __cplusplus
}
#endif
