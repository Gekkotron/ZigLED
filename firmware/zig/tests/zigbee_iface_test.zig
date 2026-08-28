const std = @import("std");
const zi = @import("zigbee_iface");
const s = @import("state");

test "post and drain round trip" {
    var q = zi.CommandQueue.init();
    try std.testing.expectEqual(true, q.tryPost(.{ .set_on = true }));
    try std.testing.expectEqual(true, q.tryPost(.{ .set_level = 42 }));
    var out: s.Command = undefined;
    try std.testing.expectEqual(true, q.tryDrain(&out));
    try std.testing.expectEqual(@as(u8, 1), @intFromBool(out.set_on));
    try std.testing.expectEqual(true, q.tryDrain(&out));
    try std.testing.expectEqual(@as(u8, 42), out.set_level);
    try std.testing.expectEqual(false, q.tryDrain(&out));
}

test "queue drops oldest when full" {
    var q = zi.CommandQueue.init();
    var i: u32 = 0;
    while (i < 40) : (i += 1) {
        _ = q.tryPost(.{ .set_level = @intCast(i & 0xFF) });
    }
    var out: s.Command = undefined;
    var drained: u32 = 0;
    var last_val: u8 = 0;
    while (q.tryDrain(&out)) : (drained += 1) {
        last_val = out.set_level;
    }
    try std.testing.expect(drained == 32);
    try std.testing.expectEqual(@as(u8, 39), last_val);
}
