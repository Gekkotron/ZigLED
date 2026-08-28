const std = @import("std");
const c = @import("color");
const config = @import("config");
const fbm = @import("frame_buffer");
const st = @import("state");
const ee = @import("effect_engine");

pub fn make(comptime cfg: config.LedConfig) ee.Effect(cfg) {
    const R = struct {
        fn render(state: *const st.EngineState, t_ms: u64, fb: *fbm.FrameBuffer(cfg)) void {
            if (!state.on) { fb.clear(.{}); return; }
            var prng = std.Random.DefaultPrng.init(0x1eaf00ffee ^ (t_ms / 30));
            const rng = prng.random();
            for (&fb.linear, 0..) |*p, i| {
                var pi = std.Random.DefaultPrng.init(0xdeadbeef ^ (@as(u64, i) << 16) ^ (t_ms / 30));
                const r0 = pi.random();
                const noise = r0.int(u8);
                const bright: u16 = 110 + (@as(u16, noise) * 145) / 255;
                const hue_shift: u8 = @intCast(rng.uintLessThan(u16, 24));
                p.* = .{
                    .r = @intCast((@as(u32, 255) * bright) / 255),
                    .g = @intCast((@as(u32, 40 + hue_shift) * bright) / 255),
                    .b = 0,
                };
            }
        }
    };
    return .{ .name = "candle", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
