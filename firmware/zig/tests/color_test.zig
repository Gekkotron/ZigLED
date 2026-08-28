const std = @import("std");
const color = @import("color");

test "blend endpoints" {
    const a: color.Rgb = .{ .r = 0, .g = 0, .b = 0 };
    const b: color.Rgb = .{ .r = 200, .g = 100, .b = 50 };
    try std.testing.expectEqual(a, color.blend(a, b, 0));
    try std.testing.expectEqual(b, color.blend(a, b, 255));
}

test "blend midpoint approx" {
    const a: color.Rgb = .{ .r = 0, .g = 0, .b = 0 };
    const b: color.Rgb = .{ .r = 200, .g = 100, .b = 50 };
    const mid = color.blend(a, b, 128);
    try std.testing.expect(@abs(@as(i32, mid.r) - 100) <= 2);
    try std.testing.expect(@abs(@as(i32, mid.g) - 50) <= 2);
    try std.testing.expect(@abs(@as(i32, mid.b) - 25) <= 2);
}

test "gamma lut endpoints" {
    try std.testing.expectEqual(@as(u8, 0), color.gamma_lut[0]);
    try std.testing.expectEqual(@as(u8, 255), color.gamma_lut[255]);
}

test "gamma monotonic" {
    var prev: u8 = 0;
    var i: usize = 1;
    while (i < 256) : (i += 1) {
        try std.testing.expect(color.gamma_lut[i] >= prev);
        prev = color.gamma_lut[i];
    }
}

test "xyToRgb white point ~ D65 xy" {
    const rgb = color.xyToRgb(20971, 21626, 255);
    try std.testing.expect(rgb.r > 200 and rgb.g > 200 and rgb.b > 200);
}

test "xyToRgb level=0 is black" {
    const rgb = color.xyToRgb(20971, 21626, 0);
    try std.testing.expectEqual(color.Rgb{ .r = 0, .g = 0, .b = 0 }, rgb);
}
