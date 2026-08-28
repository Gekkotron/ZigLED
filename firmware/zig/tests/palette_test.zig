const std = @import("std");
const palette = @import("palette");
const color = @import("color");

test "palette id 0 returns commanded" {
    const c: color.Rgb = .{ .r = 10, .g = 20, .b = 30 };
    try std.testing.expectEqual(c, palette.sample(0, 0, c));
    try std.testing.expectEqual(c, palette.sample(0, 12345, c));
}

test "palette id 1 (rainbow) t=0 differs from t=32768" {
    const a = palette.sample(1, 0, .{});
    const b = palette.sample(1, 32768, .{});
    try std.testing.expect(a.r != b.r or a.g != b.g or a.b != b.b);
}

test "palette count is 7" {
    try std.testing.expectEqual(@as(u16, 7), palette.palette_count());
}

test "out of range palette id returns commanded" {
    const c: color.Rgb = .{ .r = 5, .g = 5, .b = 5 };
    try std.testing.expectEqual(c, palette.sample(200, 0, c));
}
