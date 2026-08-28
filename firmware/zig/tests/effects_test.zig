const std = @import("std");
const ee = @import("effect_engine");
const fbm = @import("frame_buffer");
const config = @import("config");
const st_mod = @import("state");

const cfg: config.LedConfig = .{ .count = 20, .pixel_format = .rgb, .timing_profile = .ws2815, .layout = .strip, .led_data_gpio = 0, .boot_button_gpio = 0 };

fn brightness(fb: *const fbm.FrameBuffer(cfg)) u32 {
    var s: u32 = 0;
    for (fb.linear) |p| s += @as(u32, p.r) + p.g + p.b;
    return s;
}

test "breathe brightness changes across time" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626; s.level = 255;
    s.effect_id = 1;
    ee.render(cfg, &s, 0, &fb);
    const b0 = brightness(&fb);
    ee.render(cfg, &s, 500, &fb);
    const b1 = brightness(&fb);
    try std.testing.expect(b0 != b1);
}

test "comet places head somewhere" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626; s.level = 255;
    s.effect_id = 2;
    ee.render(cfg, &s, 100, &fb);
    var max_r: u8 = 0;
    for (fb.linear) |p| if (p.r > max_r) { max_r = p.r; };
    try std.testing.expect(max_r > 100);
}

test "wipe eventually lights every pixel across a full period" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626; s.level = 255;
    s.effect_id = 3;
    var lit = [_]bool{false} ** cfg.count;
    var t: u64 = 0;
    while (t < 20_000) : (t += 16) {
        ee.render(cfg, &s, t, &fb);
        for (fb.linear, 0..) |p, i| if (p.r > 0 or p.g > 0 or p.b > 0) { lit[i] = true; };
    }
    for (lit) |b| try std.testing.expect(b);
}

test "sparkle lights some pixels at high intensity" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.color_x = 65535; s.color_y = 21626; s.level = 255;
    s.effect_id = 4; s.effect_intensity = 240;
    ee.render(cfg, &s, 12345, &fb);
    var lit: u32 = 0;
    for (fb.linear) |p| if (p.r > 0 or p.g > 0 or p.b > 0) { lit += 1; };
    try std.testing.expect(lit > 0);
}

test "rainbow different colors across strip" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.level = 255; s.effect_id = 5;
    ee.render(cfg, &s, 0, &fb);
    try std.testing.expect(fb.linear[0].r != fb.linear[cfg.count / 2].r or fb.linear[0].g != fb.linear[cfg.count / 2].g);
}

test "candle never fully dark" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.level = 255; s.effect_id = 6;
    ee.render(cfg, &s, 0, &fb);
    var lit: u32 = 0;
    for (fb.linear) |p| if (p.r > 20 or p.g > 5) { lit += 1; };
    try std.testing.expectEqual(cfg.count, lit);
}

test "fire_1d layout mask excludes it or includes it depending on cfg" {
    const cnt = ee.effectCount(cfg);
    try std.testing.expect(cnt >= 8);
}

test "fire_1d produces warm colors on strip" {
    var fb = fbm.FrameBuffer(cfg){};
    var s = st_mod.defaults;
    s.on = true; s.level = 255; s.effect_id = 7; s.effect_speed = 200;
    var t: u64 = 0;
    while (t < 400) : (t += 16) ee.render(cfg, &s, t, &fb);
    var warmish: u32 = 0;
    for (fb.linear) |p| if (p.r > p.b) { warmish += 1; };
    try std.testing.expect(warmish >= cfg.count / 2);
}
