const std = @import("std");
const ee = @import("effect_engine");
const fbm = @import("frame_buffer");
const config = @import("config");
const st_mod = @import("state");

const strip_cfg: config.LedConfig = .{ .count = 5, .pixel_format = .rgb, .timing_profile = .ws2815, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };

test "effect count on strip is at least 1 (solid)" {
    try std.testing.expect(ee.effectCount(strip_cfg) >= 1);
}

test "render effect 0 with commanded color fills strip" {
    var fb = fbm.FrameBuffer(strip_cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626;
    s.level = 255;
    ee.render(strip_cfg, &s, 0, &fb);
    var non_zero: u32 = 0;
    for (fb.linear) |p| if (p.r > 0 or p.g > 0 or p.b > 0) { non_zero += 1; };
    try std.testing.expectEqual(@as(u32, 5), non_zero);
}

test "render out-of-range effect falls back to solid" {
    var fb = fbm.FrameBuffer(strip_cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626;
    s.effect_id = 9999;
    s.level = 255;
    ee.render(strip_cfg, &s, 0, &fb);
    var non_zero: u32 = 0;
    for (fb.linear) |p| if (p.r > 0 or p.g > 0 or p.b > 0) { non_zero += 1; };
    try std.testing.expect(non_zero > 0);
}

test "render zeros pixels beyond active_count" {
    var fb = fbm.FrameBuffer(strip_cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626; s.level = 255;
    s.active_count = 3; // strip_cfg.count = 5
    ee.render(strip_cfg, &s, 0, &fb);
    for (fb.linear[0..3]) |p| try std.testing.expect(p.r > 0 or p.g > 0 or p.b > 0);
    for (fb.linear[3..]) |p| {
        try std.testing.expectEqual(@as(u8, 0), p.r);
        try std.testing.expectEqual(@as(u8, 0), p.g);
        try std.testing.expectEqual(@as(u8, 0), p.b);
    }
}

test "render tolerates active_count > cfg.count" {
    var fb = fbm.FrameBuffer(strip_cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626; s.level = 255;
    s.active_count = 999;
    ee.render(strip_cfg, &s, 0, &fb);
    var non_zero: u32 = 0;
    for (fb.linear) |p| if (p.r > 0 or p.g > 0 or p.b > 0) { non_zero += 1; };
    try std.testing.expectEqual(@as(u32, strip_cfg.count), non_zero);
}
