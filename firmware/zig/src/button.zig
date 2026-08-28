const c = @cImport({
    @cInclude("driver/gpio.h");
    @cInclude("nvs_flash.h");
    @cInclude("esp_zigbee_core.h");
});

const config = @import("config");

var initialized: bool = false;

fn ensureInit() void {
    if (initialized) return;
    var gpio_conf: c.gpio_config_t = .{
        .pin_bit_mask = @as(u64, 1) << config.cfg.boot_button_gpio,
        .mode = c.GPIO_MODE_INPUT,
        .pull_up_en = c.GPIO_PULLUP_ENABLE,
        .pull_down_en = c.GPIO_PULLDOWN_DISABLE,
        .intr_type = c.GPIO_INTR_DISABLE,
    };
    _ = c.gpio_config(&gpio_conf);
    initialized = true;
}

pub fn buttonPressed() bool {
    ensureInit();
    return c.gpio_get_level(config.cfg.boot_button_gpio) == 0;
}

pub fn factoryReset() void {
    _ = c.nvs_flash_erase_partition("nvs");
    c.esp_zb_factory_reset();
}
