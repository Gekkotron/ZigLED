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
            const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
            const col = palette.sample(state.palette_id, 0, commanded);
            const period_ms: u64 = @as(u64, 2 * cfg.count) * (256 - @as(u64, state.effect_speed)) / 2 + 200;
            const cycle: u64 = t_ms % period_ms;
            const half = period_ms / 2;
            const forward = cycle < half;
            const local = if (forward) cycle else cycle - half;
            const boundary: u32 = @intCast((local * cfg.count) / half);
            const reverse: bool = state.effect_intensity > 128;
            for (&fb.linear, 0..) |*p, i| {
                const idx: u32 = if (reverse) @intCast(cfg.count - 1 - i) else @intCast(i);
                const lit = if (forward) idx <= boundary else idx > boundary;
                p.* = if (lit) col else .{};
            }
        }
    };
    return .{ .name = "wipe", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
