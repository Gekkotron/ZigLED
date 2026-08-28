const std = @import("std");
const c = @import("color");

pub const Palette = struct {
    name: []const u8,
    anchors: [16]c.Rgb,

    pub fn sample(self: Palette, t: u16) c.Rgb {
        const scaled: u32 = @as(u32, t) * 15;
        const idx: usize = @intCast(scaled / 65535);
        const next: usize = if (idx == 15) 0 else idx + 1;
        const remainder: u16 = @intCast(scaled - @as(u32, @intCast(idx)) * 65535);
        const progress: u8 = @intCast(@min(255, remainder / 257));
        return blendRgb(self.anchors[idx], self.anchors[next], progress);
    }
};

fn blendRgb(a: c.Rgb, b: c.Rgb, p: u8) c.Rgb {
    const inv: u16 = @as(u16, 255) - p;
    return .{
        .r = @intCast((@as(u16, a.r) * inv + @as(u16, b.r) * p + 127) / 255),
        .g = @intCast((@as(u16, a.g) * inv + @as(u16, b.g) * p + 127) / 255),
        .b = @intCast((@as(u16, a.b) * inv + @as(u16, b.b) * p + 127) / 255),
    };
}

fn hsvAnchor(hue_deg: f32) c.Rgb {
    const h = hue_deg / 60.0;
    const x = 1.0 - @abs(@mod(h, 2.0) - 1.0);
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;
    if (h < 1) {
        r = 1;
        g = x;
    } else if (h < 2) {
        r = x;
        g = 1;
    } else if (h < 3) {
        g = 1;
        b = x;
    } else if (h < 4) {
        g = x;
        b = 1;
    } else if (h < 5) {
        r = x;
        b = 1;
    } else {
        r = 1;
        b = x;
    }
    return .{
        .r = @intFromFloat(@round(r * 255.0)),
        .g = @intFromFloat(@round(g * 255.0)),
        .b = @intFromFloat(@round(b * 255.0)),
    };
}

const rainbow: Palette = blk: {
    var a: [16]c.Rgb = undefined;
    for (0..16) |i| {
        const hue = @as(f32, @floatFromInt(i)) * (360.0 / 16.0);
        a[i] = hsvAnchor(hue);
    }
    break :blk .{ .name = "rainbow", .anchors = a };
};

const ocean: Palette = .{
    .name = "ocean",
    .anchors = [_]c.Rgb{
        .{ .r = 0, .g = 0, .b = 20 },    .{ .r = 0, .g = 10, .b = 60 },
        .{ .r = 0, .g = 30, .b = 110 },  .{ .r = 0, .g = 60, .b = 180 },
        .{ .r = 10, .g = 100, .b = 220 }, .{ .r = 30, .g = 140, .b = 240 },
        .{ .r = 60, .g = 180, .b = 255 }, .{ .r = 110, .g = 210, .b = 255 },
        .{ .r = 60, .g = 180, .b = 255 }, .{ .r = 30, .g = 140, .b = 240 },
        .{ .r = 10, .g = 100, .b = 220 }, .{ .r = 0, .g = 60, .b = 180 },
        .{ .r = 0, .g = 30, .b = 110 },  .{ .r = 0, .g = 10, .b = 60 },
        .{ .r = 0, .g = 5, .b = 30 },    .{ .r = 0, .g = 0, .b = 20 },
    },
};

const sunset: Palette = .{
    .name = "sunset",
    .anchors = [_]c.Rgb{
        .{ .r = 20, .g = 0, .b = 40 },   .{ .r = 80, .g = 10, .b = 60 },
        .{ .r = 160, .g = 20, .b = 60 }, .{ .r = 220, .g = 40, .b = 40 },
        .{ .r = 255, .g = 100, .b = 40 }, .{ .r = 255, .g = 160, .b = 60 },
        .{ .r = 255, .g = 200, .b = 90 }, .{ .r = 255, .g = 220, .b = 140 },
        .{ .r = 255, .g = 200, .b = 90 }, .{ .r = 255, .g = 160, .b = 60 },
        .{ .r = 255, .g = 100, .b = 40 }, .{ .r = 220, .g = 40, .b = 40 },
        .{ .r = 160, .g = 20, .b = 60 }, .{ .r = 80, .g = 10, .b = 60 },
        .{ .r = 40, .g = 5, .b = 50 },   .{ .r = 20, .g = 0, .b = 40 },
    },
};

const forest: Palette = .{
    .name = "forest",
    .anchors = [_]c.Rgb{
        .{ .r = 0, .g = 20, .b = 0 },    .{ .r = 10, .g = 50, .b = 10 },
        .{ .r = 20, .g = 90, .b = 15 },  .{ .r = 30, .g = 140, .b = 20 },
        .{ .r = 50, .g = 180, .b = 30 }, .{ .r = 100, .g = 200, .b = 50 },
        .{ .r = 140, .g = 220, .b = 80 }, .{ .r = 200, .g = 230, .b = 140 },
        .{ .r = 140, .g = 220, .b = 80 }, .{ .r = 100, .g = 200, .b = 50 },
        .{ .r = 50, .g = 180, .b = 30 }, .{ .r = 30, .g = 140, .b = 20 },
        .{ .r = 20, .g = 90, .b = 15 },  .{ .r = 10, .g = 50, .b = 10 },
        .{ .r = 5, .g = 30, .b = 5 },    .{ .r = 0, .g = 20, .b = 0 },
    },
};

const fire: Palette = .{
    .name = "fire",
    .anchors = [_]c.Rgb{
        .{ .r = 0, .g = 0, .b = 0 },     .{ .r = 20, .g = 0, .b = 0 },
        .{ .r = 60, .g = 0, .b = 0 },    .{ .r = 130, .g = 0, .b = 0 },
        .{ .r = 200, .g = 20, .b = 0 },  .{ .r = 255, .g = 60, .b = 0 },
        .{ .r = 255, .g = 120, .b = 0 }, .{ .r = 255, .g = 170, .b = 10 },
        .{ .r = 255, .g = 200, .b = 30 }, .{ .r = 255, .g = 170, .b = 10 },
        .{ .r = 255, .g = 120, .b = 0 }, .{ .r = 255, .g = 60, .b = 0 },
        .{ .r = 200, .g = 20, .b = 0 },  .{ .r = 130, .g = 0, .b = 0 },
        .{ .r = 60, .g = 0, .b = 0 },    .{ .r = 0, .g = 0, .b = 0 },
    },
};

const mono_warm_white: Palette = .{
    .name = "mono_warm_white",
    .anchors = [_]c.Rgb{.{ .r = 255, .g = 180, .b = 100 }} ** 16,
};

const mono_cool_white: Palette = .{
    .name = "mono_cool_white",
    .anchors = [_]c.Rgb{.{ .r = 200, .g = 220, .b = 255 }} ** 16,
};

pub const palettes: []const Palette = &.{
    rainbow, ocean, sunset, forest, fire, mono_warm_white, mono_cool_white,
};

pub fn palette_count() u16 {
    return @intCast(palettes.len);
}

pub fn sample(palette_id: u8, t: u16, commanded: c.Rgb) c.Rgb {
    if (palette_id == 0) return commanded;
    const idx: usize = palette_id - 1;
    if (idx >= palettes.len) return commanded;
    return palettes[idx].sample(t);
}
