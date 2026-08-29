const std = @import("std");
const s = @import("state");

pub const SCHEMA_VERSION: u16 = 2;
pub const SERIALIZED_SIZE: usize = 18;
pub const DEBOUNCE_MS: u32 = 2000;

pub fn encode(st: s.EngineState) [SERIALIZED_SIZE]u8 {
    var out: [SERIALIZED_SIZE]u8 = undefined;
    std.mem.writeInt(u16, out[0..2], SCHEMA_VERSION, .little);
    out[2] = if (st.on) 1 else 0;
    out[3] = st.level;
    std.mem.writeInt(u16, out[4..6], st.color_x, .little);
    std.mem.writeInt(u16, out[6..8], st.color_y, .little);
    std.mem.writeInt(u16, out[8..10], st.effect_id, .little);
    out[10] = st.effect_speed;
    out[11] = st.effect_intensity;
    out[12] = st.palette_id;
    out[13] = 0;
    std.mem.writeInt(u16, out[14..16], st.pir_unoccupied_delay_s, .little);
    out[16] = 0;
    out[17] = 0;
    return out;
}

pub fn decode(bytes: []const u8) ?s.EngineState {
    if (bytes.len != SERIALIZED_SIZE) return null;
    const schema = std.mem.readInt(u16, bytes[0..2], .little);
    if (schema != SCHEMA_VERSION) return null;
    return .{
        .on = bytes[2] != 0,
        .level = bytes[3],
        .color_x = std.mem.readInt(u16, bytes[4..6], .little),
        .color_y = std.mem.readInt(u16, bytes[6..8], .little),
        .effect_id = std.mem.readInt(u16, bytes[8..10], .little),
        .effect_speed = bytes[10],
        .effect_intensity = bytes[11],
        .palette_id = bytes[12],
        .pir_unoccupied_delay_s = std.mem.readInt(u16, bytes[14..16], .little),
    };
}

pub const Debouncer = struct {
    dirty: bool = false,
    deadline_ms: u64 = 0,

    pub fn markDirty(self: *@This(), now_ms: u64) void {
        self.dirty = true;
        self.deadline_ms = now_ms + DEBOUNCE_MS;
    }

    pub fn readyToWrite(self: *const @This(), now_ms: u64) bool {
        return self.dirty and now_ms >= self.deadline_ms;
    }

    pub fn clear(self: *@This()) void {
        self.dirty = false;
        self.deadline_ms = 0;
    }
};
