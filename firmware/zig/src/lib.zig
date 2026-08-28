const std = @import("std");
const builtin = @import("builtin");

comptime {
    _ = @import("config.zig");
    _ = @import("zigbee_iface.zig");
    _ = @import("commissioning.zig");
    if (builtin.os.tag == .freestanding) _ = @import("led_output.zig");
}

export fn zigled_greet() [*:0]const u8 {
    return "hello from zig";
}

test "greet exists" {
    const g = zigled_greet();
    try std.testing.expect(g[0] == 'h');
}
