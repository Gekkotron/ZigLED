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
            const commanded = c.xyToRgb(state.color_x, state.color_y, 255);
            var y: u16 = 0;
            while (y < grid.h) : (y += 1) {
                var x: u16 = 0;
                while (x < grid.w) : (x += 1) {
                    const px: f32 = @floatFromInt(x);
                    const py: f32 = @floatFromInt(y);
                    const ph: f32 = @floatFromInt(phase);
                    // Three sine waves at different frequencies produce a
                    // richer plasma than two — extrema line up less often,
                    // so the sample space of `t` covers the full palette
                    // instead of clustering near the middle.
                    const n1 = std.math.sin(px * 0.35 + ph / 3800.0);
                    const n2 = std.math.sin(py * 0.35 - ph / 2900.0);
                    const n3 = std.math.sin((px + py) * 0.22 + ph / 4700.0);
                    const norm: f32 = (n1 + n2 + n3 + 3.0) / 6.0;
                    const t: u16 = @intFromFloat(@round(norm * 65535.0));
                    const px_color: c.Rgb = if (state.palette_id == 0) blk: {
                        // Commanded-color plasma: spatial brightness swell.
                        // Range [0.15, 1.0] keeps troughs visible at low
                        // levels while preserving contrast.
                        const bright: f32 = 0.15 + 0.85 * norm;
                        break :blk .{
                            .r = @intFromFloat(@round(@as(f32, @floatFromInt(commanded.r)) * bright)),
                            .g = @intFromFloat(@round(@as(f32, @floatFromInt(commanded.g)) * bright)),
                            .b = @intFromFloat(@round(@as(f32, @floatFromInt(commanded.b)) * bright)),
                        };
                    } else palette.sample(state.palette_id, t, commanded);
                    fb.setXY(x, y, px_color);
                }
            }
        }
    };
    return .{ .name = "plasma_2d", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
