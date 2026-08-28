const std = @import("std");

const c = @cImport({
    @cInclude("driver/rmt_tx.h");
    @cInclude("led_strip.h");
    @cInclude("led_strip_rmt.h");
    @cInclude("esp_err.h");
});

// Zig 0.16's translate-c (`aro`) unconditionally demotes any C struct
// containing a bitfield to an opaque type, so `led_strip_config_t` and
// `led_strip_rmt_config_t` (both of which have a bitfield `flags` member)
// come out of `c` as `opaque {}` with no usable fields. These extern/packed
// mirrors reproduce their exact ABI layout instead (every field is a
// 4-byte scalar, so there is no padding either way); a pointer to one is
// handed to `led_strip_new_rmt_device` via `@ptrCast`.
const ColorComponentFormat = packed struct(u32) {
    r_pos: u2,
    g_pos: u2,
    b_pos: u2,
    w_pos: u2,
    reserved: u19 = 0,
    bytes_per_color: u2,
    num_components: u3,
};

const color_component_format_rgb: ColorComponentFormat = .{
    .r_pos = 0,
    .g_pos = 1,
    .b_pos = 2,
    .w_pos = 3,
    .bytes_per_color = 1,
    .num_components = 3,
};

const LedStripFlags = packed struct(u32) {
    invert_out: u1,
    _reserved: u31 = 0,
};

const LedStripRmtFlags = packed struct(u32) {
    with_dma: u1,
    _reserved: u31 = 0,
};

const LedStripConfig = extern struct {
    strip_gpio_num: c_int,
    max_leds: u32,
    led_model: c.led_model_t,
    color_component_format: ColorComponentFormat,
    flags: LedStripFlags,
};

const LedStripRmtConfig = extern struct {
    clk_src: c.rmt_clock_source_t,
    resolution_hz: u32,
    mem_block_symbols: u32,
    flags: LedStripRmtFlags,
};

var handle: c.led_strip_handle_t = null;

export fn zigled_led_output_init(gpio: u8, count: u16) void {
    const strip_config: LedStripConfig = .{
        .strip_gpio_num = gpio,
        .max_leds = count,
        .led_model = @intCast(c.LED_MODEL_WS2812),
        .color_component_format = color_component_format_rgb,
        .flags = .{ .invert_out = 0 },
    };
    const rmt_config: LedStripRmtConfig = .{
        .clk_src = @intCast(c.RMT_CLK_SRC_DEFAULT),
        .resolution_hz = 10_000_000,
        .mem_block_symbols = 64,
        .flags = .{ .with_dma = 0 },
    };
    const err = c.led_strip_new_rmt_device(@ptrCast(&strip_config), @ptrCast(&rmt_config), &handle);
    if (err != c.ESP_OK) unreachable;
}

export fn zigled_led_output_push(bytes: [*]const u8, len: u32) void {
    if (handle == null) return;
    const stride: u32 = 3;
    const n: u32 = len / stride;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        _ = c.led_strip_set_pixel(handle, i, bytes[i * 3 + 0], bytes[i * 3 + 1], bytes[i * 3 + 2]);
    }
    _ = c.led_strip_refresh(handle);
}
