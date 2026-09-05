const std = @import("std");
const p = @import("persistence");
const s = @import("state");

test "encode-decode round trip" {
    const st: s.EngineState = .{
        .on = false, .level = 42, .color_x = 12345, .color_y = 54321,
        .effect_id = 7, .effect_speed = 200, .effect_intensity = 30, .palette_id = 3,
    };
    const bytes = p.encode(st);
    const decoded = p.decode(&bytes) orelse unreachable;
    try std.testing.expectEqual(st, decoded);
}

test "encode-decode round trip preserves active_count" {
    var st = s.defaults;
    st.active_count = 88;
    const bytes = p.encode(st);
    const decoded = p.decode(&bytes) orelse unreachable;
    try std.testing.expectEqual(@as(u16, 88), decoded.active_count);
}

test "decode wrong length returns null" {
    const bytes = [_]u8{0} ** 8;
    try std.testing.expectEqual(@as(?s.EngineState, null), p.decode(&bytes));
}

test "decode wrong schema returns null" {
    var bytes = p.encode(s.defaults);
    bytes[0] = 99;
    try std.testing.expectEqual(@as(?s.EngineState, null), p.decode(&bytes));
}

test "debouncer requires DEBOUNCE_MS after markDirty" {
    var d = p.Debouncer{};
    try std.testing.expectEqual(false, d.readyToWrite(0));
    d.markDirty(1000);
    try std.testing.expectEqual(false, d.readyToWrite(2999));
    try std.testing.expectEqual(true, d.readyToWrite(3000));
    d.clear();
    try std.testing.expectEqual(false, d.readyToWrite(999999));
}
