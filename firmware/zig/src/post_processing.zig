const std = @import("std");
const c = @import("color");
const config = @import("config");
const fbm = @import("frame_buffer");

pub const FADE_DURATION_MS: u32 = 400;

pub fn PostProcessor(comptime cfg: config.LedConfig) type {
    return struct {
        fade_start: c.Rgb = .{},
        fade_current: c.Rgb = .{},
        fade_target: c.Rgb = .{},
        fade_progress: u8 = 255,

        identify_ms: u32 = 0,
        commissioned: bool = false,

        pub fn beginFadeTo(self: *@This(), target: c.Rgb) void {
            if (target.r == self.fade_target.r and target.g == self.fade_target.g and target.b == self.fade_target.b) return;
            self.fade_start = self.fade_current;
            self.fade_target = target;
            self.fade_progress = 0;
        }

        pub fn advanceFade(self: *@This(), dt_ms: u32) void {
            if (self.fade_progress == 255) {
                self.fade_current = self.fade_target;
                return;
            }
            const step: u32 = (dt_ms * 255 + FADE_DURATION_MS / 2) / FADE_DURATION_MS;
            const next: u32 = @as(u32, self.fade_progress) + step;
            self.fade_progress = @intCast(@min(255, next));
            self.fade_current = c.blend(self.fade_start, self.fade_target, self.fade_progress);
        }

        pub fn applyBrightness(self: *@This(), fb: *fbm.FrameBuffer(cfg), level_255: u8) void {
            _ = self;
            if (level_255 == 255) return;
            for (&fb.linear) |*p| {
                p.r = scale(p.r, level_255);
                p.g = scale(p.g, level_255);
                p.b = scale(p.b, level_255);
            }
        }

        pub fn applyGamma(self: *@This(), fb: *fbm.FrameBuffer(cfg)) void {
            _ = self;
            for (&fb.linear) |*p| {
                p.r = c.gamma_lut[p.r];
                p.g = c.gamma_lut[p.g];
                p.b = c.gamma_lut[p.b];
            }
        }

        pub fn identifyOverlay(self: *@This(), fb: *fbm.FrameBuffer(cfg), t_ms: u64) void {
            if (self.identify_ms == 0) return;
            const phase: u64 = (t_ms / 250) % 2;
            if (phase == 0) return;
            for (&fb.linear) |*p| {
                p.r = @intCast((@as(u16, p.r) + 255) / 2);
                p.g = @intCast((@as(u16, p.g) + 255) / 2);
                p.b = @intCast((@as(u16, p.b) + 255) / 2);
            }
        }

        pub fn commissioningHint(self: *@This(), fb: *fbm.FrameBuffer(cfg), t_ms: u64) void {
            if (self.commissioned) return;
            const on: bool = (t_ms / 500) % 2 == 0;
            if (on) fb.setLinear(0, .{ .r = 20, .g = 20, .b = 20 });
        }

        pub fn encode(self: *@This(), fb: *const fbm.FrameBuffer(cfg), out: []u8) void {
            _ = self;
            const stride = comptime cfg.pixelStride();
            if (out.len != cfg.count * stride) unreachable;
            switch (cfg.pixel_format) {
                .rgb => for (fb.linear, 0..) |p, i| {
                    out[i * 3 + 0] = p.r;
                    out[i * 3 + 1] = p.g;
                    out[i * 3 + 2] = p.b;
                },
                .grb => for (fb.linear, 0..) |p, i| {
                    out[i * 3 + 0] = p.g;
                    out[i * 3 + 1] = p.r;
                    out[i * 3 + 2] = p.b;
                },
                .rgbw => for (fb.linear, 0..) |p, i| {
                    const w = @min(p.r, @min(p.g, p.b));
                    out[i * 4 + 0] = p.r - w;
                    out[i * 4 + 1] = p.g - w;
                    out[i * 4 + 2] = p.b - w;
                    out[i * 4 + 3] = w;
                },
            }
        }
    };
}

fn scale(x: u8, level: u8) u8 {
    return @intCast((@as(u16, x) * @as(u16, level) + 127) / 255);
}
