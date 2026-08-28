const std = @import("std");
const c = @import("color");
const config = @import("config");

pub fn FrameBuffer(comptime cfg: config.LedConfig) type {
    return struct {
        linear: [cfg.count]c.Rgb = [_]c.Rgb{.{}} ** cfg.count,

        pub fn clear(self: *@This(), color_: c.Rgb) void {
            for (&self.linear) |*p| p.* = color_;
        }

        pub fn fill(self: *@This(), color_: c.Rgb) void {
            self.clear(color_);
        }

        pub fn setLinear(self: *@This(), i: u32, color_: c.Rgb) void {
            if (i >= cfg.count) return;
            self.linear[i] = color_;
        }

        pub fn get(self: *const @This(), i: u32) c.Rgb {
            if (i >= cfg.count) return .{};
            return self.linear[i];
        }

        pub fn setXY(self: *@This(), x: u16, y: u16, color_: c.Rgb) void {
            const idx = mapXY(cfg, x, y) orelse return;
            self.setLinear(idx, color_);
        }
    };
}

fn mapXY(comptime cfg: config.LedConfig, x: u16, y: u16) ?u32 {
    return switch (cfg.layout) {
        .strip => if (y == 0 and x < cfg.count) @as(u32, x) else null,
        .serpentine => |g| blk: {
            if (x >= g.w or y >= g.h) break :blk null;
            const row_base: u32 = @as(u32, y) * g.w;
            const in_row: u32 = if (y % 2 == 0) x else (g.w - 1 - x);
            break :blk row_base + in_row;
        },
        .panels => |panels| blk: {
            var total: u32 = 0;
            for (panels) |p| {
                if (x >= p.x_offset and x < p.x_offset + p.w and y >= p.y_offset and y < p.y_offset + p.h) {
                    const lx: u32 = x - p.x_offset;
                    const ly: u32 = y - p.y_offset;
                    break :blk total + ly * @as(u32, p.w) + lx;
                }
                total += @as(u32, p.w) * @as(u32, p.h);
            }
            break :blk null;
        },
    };
}
