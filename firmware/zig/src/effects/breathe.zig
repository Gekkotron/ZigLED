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
            const speed = @as(u64, state.effect_speed) + 1;
            const phase: f32 = @as(f32, @floatFromInt((t_ms * speed) % 3600)) / 3600.0;
            const s = (std.math.sin(phase * std.math.tau) + 1.0) * 0.5;
            const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
            const base = palette.sample(state.palette_id, @intCast((t_ms / 20) % 65536), commanded);
            const scaled: c.Rgb = .{
                .r = @intFromFloat(@as(f32, @floatFromInt(base.r)) * s),
                .g = @intFromFloat(@as(f32, @floatFromInt(base.g)) * s),
                .b = @intFromFloat(@as(f32, @floatFromInt(base.b)) * s),
            };
            fb.clear(scaled);
        }
    };
    return .{ .name = "breathe", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
