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
            fb.clear(.{});
            const speed = @as(u64, state.effect_speed) + 1;
            const period_ms: u64 = @as(u64, cfg.count) * 600 / @as(u64, speed) + 1;
            const pos: u32 = @intCast((t_ms * cfg.count) % (period_ms + 1));
            const head: u32 = pos % cfg.count;
            const commanded = c.xyToRgb(state.color_x, state.color_y, state.level);
            const col = palette.sample(state.palette_id, @intCast((t_ms / 4) % 65536), commanded);
            const tail_len: u32 = 8;
            var i: u32 = 0;
            while (i < tail_len) : (i += 1) {
                const idx = if (head >= i) head - i else 0;
                const scale: u16 = @intCast(255 - i * (255 / tail_len));
                fb.setLinear(idx, .{
                    .r = @intCast((@as(u16, col.r) * scale) / 255),
                    .g = @intCast((@as(u16, col.g) * scale) / 255),
                    .b = @intCast((@as(u16, col.b) * scale) / 255),
                });
            }
        }
    };
    return .{ .name = "comet", .layouts = .{ .strip = true, .serpentine = true, .panels = true }, .render = R.render };
}
