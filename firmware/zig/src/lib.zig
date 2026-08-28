const std = @import("std");

export fn zigled_greet() [*:0]const u8 {
    return "hello from zig";
}

test "greet exists" {
    const g = zigled_greet();
    try std.testing.expect(g[0] == 'h');
}
