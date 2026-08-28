const std = @import("std");

var g_connected: std.atomic.Value(bool) = .init(false);

pub fn setConnected(v: bool) void {
    g_connected.store(v, .seq_cst);
}

pub fn connected() bool {
    return g_connected.load(.seq_cst);
}

export fn zigled_zb_set_connected(v: bool) void {
    setConnected(v);
}
