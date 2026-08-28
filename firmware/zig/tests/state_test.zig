const std = @import("std");
const s = @import("state");

test "apply set_level clamps to 254 max, 1 min" {
    var st = s.defaults;
    _ = s.apply(&st, .{ .set_level = 255 });
    try std.testing.expectEqual(@as(u8, 254), st.level);
    _ = s.apply(&st, .{ .set_level = 0 });
    try std.testing.expectEqual(@as(u8, 1), st.level);
}

test "apply set_effect passes through" {
    var st = s.defaults;
    _ = s.apply(&st, .{ .set_effect = 7 });
    try std.testing.expectEqual(@as(u16, 7), st.effect_id);
}

test "apply identify does not mark dirty" {
    var st = s.defaults;
    const dirty = s.apply(&st, .{ .identify = 30 });
    try std.testing.expectEqual(false, dirty);
}

test "apply set_on marks dirty" {
    var st = s.defaults;
    const dirty = s.apply(&st, .{ .set_on = false });
    try std.testing.expectEqual(true, dirty);
    try std.testing.expectEqual(false, st.on);
}

test "apply set_color_xy updates both" {
    var st = s.defaults;
    _ = s.apply(&st, .{ .set_color_xy = .{ .x = 40000, .y = 20000 } });
    try std.testing.expectEqual(@as(u16, 40000), st.color_x);
    try std.testing.expectEqual(@as(u16, 20000), st.color_y);
}
