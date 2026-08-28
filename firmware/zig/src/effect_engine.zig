const std = @import("std");
const c = @import("color");
const config = @import("config");
const fbm = @import("frame_buffer");
const st = @import("state");

pub const LayoutMask = packed struct {
    strip: bool = false,
    serpentine: bool = false,
    panels: bool = false,

    pub fn supports(self: LayoutMask, kind: config.LayoutKind) bool {
        return switch (kind) {
            .strip => self.strip,
            .serpentine => self.serpentine,
            .panels => self.panels,
            .custom => true,
        };
    }
};

pub fn Effect(comptime cfg: config.LedConfig) type {
    return struct {
        name: []const u8,
        layouts: LayoutMask,
        render: *const fn (*const st.EngineState, u64, *fbm.FrameBuffer(cfg)) void,
    };
}

const solid_mod = @import("effects/solid.zig");
const breathe_mod = @import("effects/breathe.zig");
const comet_mod = @import("effects/comet.zig");
const wipe_mod = @import("effects/wipe.zig");
const sparkle_mod = @import("effects/sparkle.zig");
const rainbow_mod = @import("effects/rainbow.zig");
const candle_mod = @import("effects/candle.zig");

pub fn effects(comptime cfg: config.LedConfig) []const Effect(cfg) {
    const all = comptime [_]Effect(cfg){
        solid_mod.make(cfg),
        breathe_mod.make(cfg),
        comet_mod.make(cfg),
        wipe_mod.make(cfg),
        sparkle_mod.make(cfg),
        rainbow_mod.make(cfg),
        candle_mod.make(cfg),
    };
    const kind = comptime cfg.layoutKind();
    comptime var filtered: []const Effect(cfg) = &.{};
    inline for (all) |e| {
        if (comptime e.layouts.supports(kind)) {
            filtered = filtered ++ &[_]Effect(cfg){e};
        }
    }
    return filtered;
}

pub fn effectCount(comptime cfg: config.LedConfig) u16 {
    return @intCast(effects(cfg).len);
}

pub fn render(comptime cfg: config.LedConfig, state: *const st.EngineState, t_ms: u64, fb: *fbm.FrameBuffer(cfg)) void {
    const list = effects(cfg);
    const id: usize = if (state.effect_id < list.len) state.effect_id else 0;
    list[id].render(state, t_ms, fb);
}
