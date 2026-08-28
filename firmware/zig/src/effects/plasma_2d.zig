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
            const grid = switch (cfg.layout) {
                .serpentine => |g| .{ .w = g.w, .h = g.h },
                .panels => .{ .w = @as(u16, 1), .h = @as(u16, cfg.count) },
                .strip => .{ .w = @as(u16, cfg.count), .h = @as(u16, 1) },
            };
            const speed = @as(u64, state.effect_speed) + 1;
            const phase: u32 = @intCast((t_ms * speed) % 65536);
            var y: u16 = 0;
            while (y < grid.h) : (y += 1) {
                var x: u16 = 0;
                while (x < grid.w) : (x += 1) {
                    const px: i32 = @intCast(x);
                    const py: i32 = @intCast(y);
                    const noise: i32 = @intFromFloat(std.math.sin(@as(f32, @floatFromInt(px)) * 0.4 + @as(f32, @floatFromInt(phase)) / 4000.0) * 128.0);
                    const noise2: i32 = @intFromFloat(std.math.sin(@as(f32, @floatFromInt(py)) * 0.4 - @as(f32, @floatFromInt(phase)) / 3000.0) * 128.0);
                    const t: u16 = @intCast(@as(u32, @intCast(@abs(noise + noise2))) * 128);
                    const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
                    fb.setXY(x, y, palette.sample(state.palette_id, t, commanded));
                }
            }
        }
    };
    return .{ .name = "plasma_2d", .layouts = .{ .serpentine = true, .panels = true }, .render = R.render };
}
