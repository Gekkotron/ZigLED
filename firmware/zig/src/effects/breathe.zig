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
            const cycle_ms: u64 = 500 + @as(u64, 255 - state.effect_speed) * 20;
            const phase: f32 = @as(f32, @floatFromInt(t_ms % cycle_ms)) / @as(f32, @floatFromInt(cycle_ms));
            const s = 0.1 + 0.9 * (std.math.sin(phase * std.math.tau - std.math.pi * 0.5) + 1.0) * 0.5;
            const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
            const base = palette.sample(state.palette_id, @intCast((t_ms / 40) % 65536), commanded);
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
