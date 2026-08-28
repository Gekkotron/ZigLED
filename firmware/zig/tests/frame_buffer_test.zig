const std = @import("std");
const fb_mod = @import("frame_buffer");
const config = @import("config");
const color = @import("color");

const strip_cfg: config.LedConfig = .{ .count = 10, .pixel_format = .rgb, .timing_profile = .ws2812b, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };
const serp_cfg: config.LedConfig = .{ .count = 16, .pixel_format = .rgb, .timing_profile = .ws2812b, .layout = .{ .serpentine = .{ .w = 4, .h = 4 } }, .led_data_gpio = 0, .boot_button_gpio = 0 };
const panels_cfg: config.LedConfig = .{
    .count = 32,
    .pixel_format = .rgb,
    .timing_profile = .ws2812b,
    .layout = .{ .panels = &.{
        .{ .x_offset = 0, .y_offset = 0, .w = 4, .h = 4 },
        .{ .x_offset = 4, .y_offset = 0, .w = 4, .h = 4 },
    } },
    .led_data_gpio = 0,
    .boot_button_gpio = 0,
};

test "strip setXY x=3 targets linear index 3" {
    var fb = fb_mod.FrameBuffer(strip_cfg){};
    fb.setXY(3, 0, .{ .r = 200, .g = 0, .b = 0 });
    try std.testing.expectEqual(@as(u8, 200), fb.linear[3].r);
}

test "serpentine row 1 x=0 targets linear index 7 (row 1 right-to-left)" {
    var fb = fb_mod.FrameBuffer(serp_cfg){};
    fb.setXY(0, 1, .{ .r = 10, .g = 0, .b = 0 });
    try std.testing.expectEqual(@as(u8, 10), fb.linear[7].r);
}

test "serpentine row 0 x=2 targets linear index 2" {
    var fb = fb_mod.FrameBuffer(serp_cfg){};
    fb.setXY(2, 0, .{ .r = 30, .g = 0, .b = 0 });
    try std.testing.expectEqual(@as(u8, 30), fb.linear[2].r);
}

test "out of range setLinear is silently ignored" {
    var fb = fb_mod.FrameBuffer(strip_cfg){};
    fb.setLinear(9999, .{ .r = 200 });
}

test "clear fills all pixels" {
    var fb = fb_mod.FrameBuffer(strip_cfg){};
    fb.clear(.{ .r = 5, .g = 6, .b = 7 });
    for (fb.linear) |px| {
        try std.testing.expectEqual(@as(u8, 5), px.r);
        try std.testing.expectEqual(@as(u8, 6), px.g);
        try std.testing.expectEqual(@as(u8, 7), px.b);
    }
}

test "panels layout: point in first panel targets local index" {
    var fb = fb_mod.FrameBuffer(panels_cfg){};
    fb.setXY(2, 1, .{ .r = 10 });
    try std.testing.expectEqual(@as(u8, 10), fb.linear[6].r);
}

test "panels layout: point in second panel adds first panel's area as offset" {
    var fb = fb_mod.FrameBuffer(panels_cfg){};
    fb.setXY(5, 2, .{ .r = 20 });
    try std.testing.expectEqual(@as(u8, 20), fb.linear[25].r);
}

test "panels layout: point outside any panel is silently ignored" {
    var fb = fb_mod.FrameBuffer(panels_cfg){};
    fb.setXY(100, 100, .{ .r = 200 });
    for (fb.linear) |p| {
        try std.testing.expectEqual(@as(u8, 0), p.r);
    }
}
