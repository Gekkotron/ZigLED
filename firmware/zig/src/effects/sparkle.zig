const std = @import("std");
const c = @import("color");
const config = @import("config");
const fbm = @import("frame_buffer");
const st = @import("state");
const ee = @import("effect_engine");
const palette = @import("palette");

pub fn make(comptime cfg: config.LedConfig) ee.Effect(cfg) {
    const R = struct {
        fn render(state: *const st.EngineState, t_ms: u64, fb: *fbm.FrameBuffer(cfg)) void {
            if (!state.on) { fb.clear(.{}); return; }
            const decay: u8 = @intCast(@min(255, 8 + @as(u16, state.effect_speed) / 8));
            for (&fb.linear) |*p| {
                p.r = if (p.r > decay) p.r - decay else 0;
                p.g = if (p.g > decay) p.g - decay else 0;
                p.b = if (p.b > decay) p.b - decay else 0;
            }
            const commanded = c.xyToRgb(state.color_x, state.color_y, state.level);
            const col = palette.sample(state.palette_id, @intCast((t_ms / 4) % 65536), commanded);
            var prng = std.Random.DefaultPrng.init(t_ms);
            const rng = prng.random();
            const density: u32 = 1 + @as(u32, state.effect_intensity) / 32;
            var k: u32 = 0;
            while (k < density) : (k += 1) {
                const idx: u32 = @intCast(rng.uintLessThan(u32, cfg.count));
                fb.setLinear(idx, col);
            }
        }
    };
    return .{ .name = "sparkle", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
