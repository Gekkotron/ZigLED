const std = @import("std");

pub const PixelFormat = enum { rgb, grb, rgbw };
pub const TimingProfile = enum { ws2812b, ws2814, ws2815 };
pub const LayoutKind = enum(u8) { strip = 0, serpentine = 1, panels = 2, custom = 3 };

pub const Panel = struct { x_offset: u16, y_offset: u16, w: u16, h: u16 };

pub const Layout = union(enum) {
    strip,
    serpentine: struct { w: u16, h: u16 },
    panels: []const Panel,
};

pub const LedConfig = struct {
    count: u16,
    pixel_format: PixelFormat,
    timing_profile: TimingProfile,
    layout: Layout,
    led_data_gpio: u8,
    boot_button_gpio: u8,
    // ESP32-C6 GPIO number, not the XIAO board label. On the XIAO
    // ESP32-C6, pad "D4" == GPIO 22; "D3" == GPIO 21; "D5" == GPIO 23.
    pir_gpio: u8 = 22,
    pir_enabled: bool = true,
    external_antenna: bool = true,
    antenna_rf_power_gpio: u8 = 3,
    antenna_select_gpio: u8 = 14,
    tx_power_dbm: i8 = 20,

    pub fn pixelStride(comptime self: LedConfig) u8 {
        return switch (self.pixel_format) {
            .rgb, .grb => 3,
            .rgbw => 4,
        };
    }

    pub fn layoutKind(comptime self: LedConfig) LayoutKind {
        return switch (self.layout) {
            .strip => .strip,
            .serpentine => .serpentine,
            .panels => .panels,
        };
    }
};

pub const cfg: LedConfig = .{
    .count = 120,
    .pixel_format = .rgb,
    .timing_profile = .ws2815,
    .layout = .strip,
    .led_data_gpio = 2,
    .boot_button_gpio = 9,
    // The optional toggles (pir_enabled, external_antenna, pir_gpio,
    // antenna_*_gpio, tx_power_dbm) are omitted here so their struct
    // field defaults from LedConfig above take effect. Edit the
    // struct defaults to change them.
};

test "pixelStride rgb=3, rgbw=4" {
    const rgb: LedConfig = .{ .count = 1, .pixel_format = .rgb, .timing_profile = .ws2815, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };
    const rgbw: LedConfig = .{ .count = 1, .pixel_format = .rgbw, .timing_profile = .ws2814, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };
    try std.testing.expectEqual(@as(u8, 3), rgb.pixelStride());
    try std.testing.expectEqual(@as(u8, 4), rgbw.pixelStride());
}

test "layoutKind strip=0" {
    try std.testing.expectEqual(LayoutKind.strip, cfg.layoutKind());
}
