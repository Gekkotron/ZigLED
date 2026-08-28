const std = @import("std");
const pp_mod = @import("post_processing");
const fb_mod = @import("frame_buffer");
const config = @import("config");
const color = @import("color");

const grb_cfg: config.LedConfig = .{ .count = 4, .pixel_format = .grb, .timing_profile = .ws2812b, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };
const rgbw_cfg: config.LedConfig = .{ .count = 1, .pixel_format = .rgbw, .timing_profile = .ws2814, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };
const rgb_cfg: config.LedConfig = .{ .count = 2, .pixel_format = .rgb, .timing_profile = .ws2815, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };

test "brightness zero -> all zero" {
    var fb = fb_mod.FrameBuffer(grb_cfg){};
    fb.clear(.{ .r = 200, .g = 100, .b = 50 });
    var pp = pp_mod.PostProcessor(grb_cfg){};
    pp.applyBrightness(&fb, 0);
    for (fb.linear) |p| {
        try std.testing.expectEqual(@as(u8, 0), p.r);
        try std.testing.expectEqual(@as(u8, 0), p.g);
        try std.testing.expectEqual(@as(u8, 0), p.b);
    }
}

test "encode GRB byte order" {
    var fb = fb_mod.FrameBuffer(grb_cfg){};
    fb.linear[0] = .{ .r = 10, .g = 20, .b = 30 };
    var out: [12]u8 = undefined;
    var pp = pp_mod.PostProcessor(grb_cfg){};
    pp.encode(&fb, &out);
    try std.testing.expectEqual(@as(u8, 20), out[0]);
    try std.testing.expectEqual(@as(u8, 10), out[1]);
    try std.testing.expectEqual(@as(u8, 30), out[2]);
}

test "encode RGB byte order" {
    var fb = fb_mod.FrameBuffer(rgb_cfg){};
    fb.linear[0] = .{ .r = 10, .g = 20, .b = 30 };
    var out: [6]u8 = undefined;
    var pp = pp_mod.PostProcessor(rgb_cfg){};
    pp.encode(&fb, &out);
    try std.testing.expectEqual(@as(u8, 10), out[0]);
    try std.testing.expectEqual(@as(u8, 20), out[1]);
    try std.testing.expectEqual(@as(u8, 30), out[2]);
}

test "encode RGBW extracts white" {
    var fb = fb_mod.FrameBuffer(rgbw_cfg){};
    fb.linear[0] = .{ .r = 200, .g = 100, .b = 50 };
    var out: [4]u8 = undefined;
    var pp = pp_mod.PostProcessor(rgbw_cfg){};
    pp.encode(&fb, &out);
    try std.testing.expectEqual(@as(u8, 150), out[0]);
    try std.testing.expectEqual(@as(u8, 50), out[1]);
    try std.testing.expectEqual(@as(u8, 0), out[2]);
    try std.testing.expectEqual(@as(u8, 50), out[3]);
}

test "advanceFade completes in 400 ms of accumulated dt" {
    var pp = pp_mod.PostProcessor(rgb_cfg){};
    pp.fade_start = .{};
    pp.fade_target = .{ .r = 200 };
    pp.fade_progress = 0;
    pp.advanceFade(200);
    try std.testing.expect(pp.fade_progress >= 120 and pp.fade_progress <= 140);
    pp.advanceFade(300);
    try std.testing.expectEqual(@as(u8, 255), pp.fade_progress);
}
