const std = @import("std");

pub const Rgb = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
};

pub const gamma_lut: [256]u8 = blk: {
    @setEvalBranchQuota(100000);
    var t: [256]u8 = undefined;
    for (0..256) |i| {
        const x: f64 = @as(f64, @floatFromInt(i)) / 255.0;
        const y = std.math.pow(f64, x, 2.2);
        t[i] = @intFromFloat(@round(y * 255.0));
    }
    break :blk t;
};

pub fn blend(from: Rgb, to: Rgb, progress: u8) Rgb {
    if (progress == 0) return from;
    if (progress == 255) return to;
    return .{
        .r = mix(from.r, to.r, progress),
        .g = mix(from.g, to.g, progress),
        .b = mix(from.b, to.b, progress),
    };
}

fn mix(a: u8, b: u8, p: u8) u8 {
    const ai: u32 = a;
    const bi: u32 = b;
    const pi: u32 = p;
    const inv: u32 = 255 - pi;
    return @intCast((ai * inv + bi * pi + 127) / 255);
}

pub fn xyToRgb(x_u16: u16, y_u16: u16, level_255: u8) Rgb {
    if (level_255 == 0) return .{};
    const x: f32 = @as(f32, @floatFromInt(x_u16)) / 65535.0;
    const y: f32 = @as(f32, @floatFromInt(y_u16)) / 65535.0;
    const z: f32 = 1.0 - x - y;
    if (y <= 0.0001) return .{};

    const Y: f32 = 1.0;
    const X: f32 = (Y / y) * x;
    const Z: f32 = (Y / y) * z;

    var r: f32 = 3.2406 * X - 1.5372 * Y - 0.4986 * Z;
    var g: f32 = -0.9689 * X + 1.8758 * Y + 0.0415 * Z;
    var b: f32 = 0.0557 * X - 0.2040 * Y + 1.0570 * Z;

    const max = @max(r, @max(g, b));
    if (max > 1.0) {
        r /= max;
        g /= max;
        b /= max;
    }
    r = @max(0.0, r);
    g = @max(0.0, g);
    b = @max(0.0, b);

    const scale: f32 = @as(f32, @floatFromInt(level_255)) / 255.0;
    return .{
        .r = @intFromFloat(@round(@min(255.0, r * 255.0 * scale))),
        .g = @intFromFloat(@round(@min(255.0, g * 255.0 * scale))),
        .b = @intFromFloat(@round(@min(255.0, b * 255.0 * scale))),
    };
}
