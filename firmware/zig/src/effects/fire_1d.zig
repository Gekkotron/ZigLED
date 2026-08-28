const std = @import("std");
const c = @import("color");
const config = @import("config");
const fbm = @import("frame_buffer");
const st = @import("state");
const ee = @import("effect_engine");
const palette = @import("palette");

const FIRE_ZONES: usize = 5;

pub fn make(comptime cfg: config.LedConfig) ee.Effect(cfg) {
    const R = struct {
        var heat: [cfg.count]u8 = [_]u8{0} ** cfg.count;
        var accum: u32 = 0;
        var last_t: u64 = 0;

        fn render(state: *const st.EngineState, t_ms: u64, fb: *fbm.FrameBuffer(cfg)) void {
            if (!state.on) { fb.clear(.{}); return; }
            const dt = t_ms -| last_t;
            last_t = t_ms;
            const rate: u32 = @intCast(1 + @as(u32, state.effect_speed) * 128 / 100);
            accum += @intCast(@min(65535, rate * dt / 16));

            var prng = std.Random.DefaultPrng.init(t_ms ^ 0xf1e01_23);
            const rng = prng.random();

            const zone_len: usize = cfg.count / FIRE_ZONES;
            while (accum >= 256) {
                accum -= 256;
                var z: usize = 0;
                while (z < FIRE_ZONES) : (z += 1) {
                    const base = z * zone_len;
                    const len = if (z == FIRE_ZONES - 1) cfg.count - base else zone_len;
                    var i: usize = 0;
                    while (i < len) : (i += 1) {
                        const cool = rng.uintLessThan(u8, @intCast(((55 * 10) / cfg.count) + 2));
                        heat[base + i] = if (heat[base + i] > cool) heat[base + i] - cool else 0;
                    }
                    var k: usize = len - 1;
                    while (k >= 2) : (k -= 1) {
                        heat[base + k] = @intCast((@as(u16, heat[base + k - 1]) + heat[base + k - 2] + heat[base + k - 2]) / 3);
                    }
                    if (rng.uintLessThan(u8, 255) < 120) {
                        const y = rng.uintLessThan(u8, @intCast(@min(7, len)));
                        heat[base + y] = @intCast(@min(255, @as(u16, heat[base + y]) + 160 + rng.uintLessThan(u8, 95)));
                    }
                }
            }

            _ = c;
            _ = state.palette_id;
            const fire_pal = palette.palettes[4];
            for (&fb.linear, 0..) |*p, i| {
                const h = heat[i];
                p.* = fire_pal.sample(@as(u16, h) * 257);
            }
        }
    };
    return .{ .name = "fire_1d", .layouts = .{ .strip = true }, .render = R.render };
}
