#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *zigled_greet(void);
void zigled_start(void);

void zigled_led_output_init(uint8_t gpio, uint16_t count);
void zigled_led_output_push(const uint8_t *bytes, uint32_t len);

void zigled_on_onoff(bool on);
void zigled_on_level(uint8_t level);
void zigled_on_color_xy(uint16_t x, uint16_t y);
void zigled_on_mfg_effect(uint16_t id);
void zigled_on_mfg_speed(uint8_t v);
void zigled_on_mfg_intensity(uint8_t v);
void zigled_on_mfg_palette(uint8_t v);
void zigled_on_identify(uint16_t seconds);
bool zigled_next_command(uint8_t *out_tag, uint32_t *out_a, uint32_t *out_b);
void zigled_zb_set_connected(bool v);

bool     zigled_get_on(void);
uint8_t  zigled_get_level(void);
uint16_t zigled_get_color_x(void);
uint16_t zigled_get_color_y(void);
uint16_t zigled_get_effect_id(void);
uint8_t  zigled_get_effect_speed(void);
uint8_t  zigled_get_effect_intensity(void);
uint8_t  zigled_get_palette_id(void);
uint16_t zigled_get_pir_unoccupied_delay_s(void);
void     zigled_set_pir_unoccupied_delay_s(uint16_t v);
bool     zigled_get_pir_enabled(void);
uint8_t  zigled_get_pir_gpio(void);

#ifdef __cplusplus
}
#endif
