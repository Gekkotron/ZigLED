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
            // Slower floor (800ms) at max speed keeps the top of the breath
            // from feeling clipped; the +24ms/step slope widens the useful
            // dynamic range of `effect_speed`.
            const cycle_ms: u64 = 800 + @as(u64, 255 - state.effect_speed) * 24;
            const phase: f32 = @as(f32, @floatFromInt(t_ms % cycle_ms)) / @as(f32, @floatFromInt(cycle_ms));
            // Bell in [0, 1], zero at the wrap points so the cycle joins
            // continuously and both derivatives vanish at the seam.
            const bell: f32 = (1.0 - std.math.cos(phase * std.math.tau)) * 0.5;
            // Shape the perceived brightness as the sine bell, then square
            // to convert to linear light. The eye responds roughly like
            // sqrt of linear, so a linear ramp looks fast at the bottom
            // and slow at the top; squaring cancels that and yields a
            // smooth-looking breath. Floor 0.30 (perceived) → 0.09 (linear)
            // keeps the trough visible at low brightness levels.
            const perceived: f32 = 0.30 + 0.70 * bell;
            const s: f32 = perceived * perceived;
            const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
            const base = palette.sample(state.palette_id, @intCast((t_ms / 40) % 65536), commanded);
            const scaled: c.Rgb = .{
                .r = @intFromFloat(@round(@as(f32, @floatFromInt(base.r)) * s)),
                .g = @intFromFloat(@round(@as(f32, @floatFromInt(base.g)) * s)),
                .b = @intFromFloat(@round(@as(f32, @floatFromInt(base.b)) * s)),
            };
            fb.clear(scaled);
        }
    };
    return .{ .name = "breathe", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
