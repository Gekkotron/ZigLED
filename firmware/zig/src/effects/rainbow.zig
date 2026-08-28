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
            const speed = @as(u64, state.effect_speed) + 1;
            const scroll: u32 = @intCast((t_ms * speed) % 65536);
            for (&fb.linear, 0..) |*p, i| {
                const t: u32 = (@as(u32, @intCast(i)) * (65535 / cfg.count) + scroll) & 0xFFFF;
                p.* = palette.palettes[0].sample(@intCast(t));
            }
        }
    };
    return .{ .name = "rainbow", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
