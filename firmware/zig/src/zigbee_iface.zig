const std = @import("std");
const builtin = @import("builtin");
const s = @import("state");

const CAP: usize = 32;

// tryPost/tryDrain run from two different FreeRTOS tasks (Zigbee task
// producer, render task consumer) on-device, so their shared-state mutation
// needs mutual exclusion. The lock itself is a small C shim (see
// firmware/main/lock_shim.c) rather than a `@cImport` of FreeRTOS headers
// here, since this file is also compiled as a standalone host-test module
// with no ESP-IDF include paths; the calls below are pruned entirely on
// that (non-freestanding) target.
extern fn zigled_queue_lock() void;
extern fn zigled_queue_unlock() void;

fn lock() void {
    if (builtin.os.tag == .freestanding) zigled_queue_lock();
}

fn unlock() void {
    if (builtin.os.tag == .freestanding) zigled_queue_unlock();
}

pub const CommandQueue = struct {
    buf: [CAP]s.Command = undefined,
    head: usize = 0,
    tail: usize = 0,
    len: usize = 0,

    pub fn init() CommandQueue {
        return .{};
    }

    pub fn tryPost(self: *CommandQueue, cmd: s.Command) bool {
        lock();
        defer unlock();
        if (self.len == CAP) {
            self.head = (self.head + 1) % CAP;
            self.len -= 1;
        }
        self.buf[self.tail] = cmd;
        self.tail = (self.tail + 1) % CAP;
        self.len += 1;
        return true;
    }

    pub fn tryDrain(self: *CommandQueue, out: *s.Command) bool {
        lock();
        defer unlock();
        if (self.len == 0) return false;
        out.* = self.buf[self.head];
        self.head = (self.head + 1) % CAP;
        self.len -= 1;
        return true;
    }
};

var g_queue: CommandQueue = .{};

pub fn queue() *CommandQueue {
    return &g_queue;
}

export fn zigled_on_onoff(on: bool) void {
    _ = g_queue.tryPost(.{ .set_on = on });
}

export fn zigled_on_level(level: u8) void {
    _ = g_queue.tryPost(.{ .set_level = level });
}

export fn zigled_on_color_xy(x: u16, y: u16) void {
    _ = g_queue.tryPost(.{ .set_color_xy = .{ .x = x, .y = y } });
}

export fn zigled_on_mfg_effect(id: u16) void {
    _ = g_queue.tryPost(.{ .set_effect = id });
}

export fn zigled_on_mfg_speed(v: u8) void {
    _ = g_queue.tryPost(.{ .set_speed = v });
}

export fn zigled_on_mfg_intensity(v: u8) void {
    _ = g_queue.tryPost(.{ .set_intensity = v });
}

export fn zigled_on_mfg_palette(v: u8) void {
    _ = g_queue.tryPost(.{ .set_palette = v });
}

export fn zigled_on_identify(seconds: u16) void {
    _ = g_queue.tryPost(.{ .identify = seconds });
}

export fn zigled_next_command(out_tag: *u8, out_a: *u32, out_b: *u32) bool {
    var cmd: s.Command = undefined;
    if (!g_queue.tryDrain(&cmd)) return false;
    switch (cmd) {
        .set_on => |v| {
            out_tag.* = 1;
            out_a.* = @intFromBool(v);
            out_b.* = 0;
        },
        .set_level => |v| {
            out_tag.* = 2;
            out_a.* = v;
            out_b.* = 0;
        },
        .set_color_xy => |v| {
            out_tag.* = 3;
            out_a.* = v.x;
            out_b.* = v.y;
        },
        .set_effect => |v| {
            out_tag.* = 4;
            out_a.* = v;
            out_b.* = 0;
        },
        .set_speed => |v| {
            out_tag.* = 5;
            out_a.* = v;
            out_b.* = 0;
        },
        .set_intensity => |v| {
            out_tag.* = 6;
            out_a.* = v;
            out_b.* = 0;
        },
        .set_palette => |v| {
            out_tag.* = 7;
            out_a.* = v;
            out_b.* = 0;
        },
        .identify => |v| {
            out_tag.* = 8;
            out_a.* = v;
            out_b.* = 0;
        },
        .set_active_count => |v| {
            out_tag.* = 9;
            out_a.* = v;
            out_b.* = 0;
        },
    }
    return true;
}

export fn zigled_on_mfg_active_count(v: u16) void {
    _ = g_queue.tryPost(.{ .set_active_count = v });
}
