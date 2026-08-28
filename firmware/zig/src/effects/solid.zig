const c = @import("color");
const config = @import("config");
const fbm = @import("frame_buffer");
const st = @import("state");
const ee = @import("effect_engine");

pub fn make(comptime cfg: config.LedConfig) ee.Effect(cfg) {
    const R = struct {
        fn render(state: *const st.EngineState, t_ms: u64, fb: *fbm.FrameBuffer(cfg)) void {
            _ = t_ms;
            const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
            fb.clear(if (state.on) commanded else .{});
        }
    };
    return .{
        .name = "solid",
        .layouts = .{ .strip = true, .serpentine = true, .panels = true },
        .render = R.render,
    };
}
