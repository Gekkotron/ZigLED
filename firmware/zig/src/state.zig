const std = @import("std");

pub const EngineState = struct {
    on: bool = true,
    level: u8 = 128,
    color_x: u16 = 20971,
    color_y: u16 = 21626,
    effect_id: u16 = 0,
    effect_speed: u8 = 128,
    effect_intensity: u8 = 128,
    palette_id: u8 = 0,
    pir_unoccupied_delay_s: u16 = 60,
};

pub const defaults: EngineState = .{};

pub const Command = union(enum) {
    set_on: bool,
    set_level: u8,
    set_color_xy: struct { x: u16, y: u16 },
    set_effect: u16,
    set_speed: u8,
    set_intensity: u8,
    set_palette: u8,
    identify: u16,
};

pub fn apply(state: *EngineState, cmd: Command) bool {
    switch (cmd) {
        .set_on => |v| {
            state.on = v;
            return true;
        },
        .set_level => |v| {
            state.level = std.math.clamp(v, 1, 254);
            return true;
        },
        .set_color_xy => |v| {
            state.color_x = v.x;
            state.color_y = v.y;
            return true;
        },
        .set_effect => |v| {
            state.effect_id = v;
            return true;
        },
        .set_speed => |v| {
            state.effect_speed = v;
            return true;
        },
        .set_intensity => |v| {
            state.effect_intensity = v;
            return true;
        },
        .set_palette => |v| {
            state.palette_id = v;
            return true;
        },
        .identify => {
            return false;
        },
    }
}
