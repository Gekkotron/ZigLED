const config = @import("config");
const state = @import("state");
const persistence = @import("persistence");
const commissioning = @import("commissioning.zig");
const effect_engine = @import("effect_engine");
const post_processing = @import("post_processing");
const frame_buffer = @import("frame_buffer");
const color = @import("color");
const button = @import("button.zig");
const led_output_c = @cImport({
    @cInclude("nvs.h");
    @cInclude("nvs_flash.h");
    @cInclude("esp_err.h");
    @cInclude("freertos/FreeRTOS.h");
    @cInclude("freertos/task.h");
    @cInclude("esp_timer.h");
});

extern fn zigled_led_output_init(gpio: u8, count: u16) void;
extern fn zigled_led_output_push(bytes: [*]const u8, len: u32) void;
extern fn zigled_next_command(tag: *u8, a: *u32, b: *u32) bool;

const cfg = config.cfg;

// 60 fps tick period expressed in FreeRTOS ticks. `CONFIG_FREERTOS_HZ` is a
// Kconfig value, not a preprocessor constant, so it does not survive
// translate-c; this assumes the default 1000 Hz tick rate (1000 / 60 = 16).
const period_ticks: u32 = 16;

var g_state: state.EngineState = state.defaults;
var g_fb: frame_buffer.FrameBuffer(cfg) = .{};
var g_pp: post_processing.PostProcessor(cfg) = .{};
var g_debouncer: persistence.Debouncer = .{};
var g_button_down_ms: u64 = 0;
var g_reset_triggered: bool = false;

fn loadStateFromNvs() void {
    var handle: led_output_c.nvs_handle_t = 0;
    if (led_output_c.nvs_open("zigled", led_output_c.NVS_READONLY, &handle) != led_output_c.ESP_OK) return;
    defer led_output_c.nvs_close(handle);
    var size: usize = persistence.SERIALIZED_SIZE;
    var buf: [persistence.SERIALIZED_SIZE]u8 = undefined;
    if (led_output_c.nvs_get_blob(handle, "state", &buf, &size) != led_output_c.ESP_OK) return;
    if (persistence.decode(&buf)) |st| g_state = st;
}

fn saveStateToNvs() void {
    var handle: led_output_c.nvs_handle_t = 0;
    if (led_output_c.nvs_open("zigled", led_output_c.NVS_READWRITE, &handle) != led_output_c.ESP_OK) return;
    defer led_output_c.nvs_close(handle);
    const bytes = persistence.encode(g_state);
    _ = led_output_c.nvs_set_blob(handle, "state", &bytes, bytes.len);
    _ = led_output_c.nvs_commit(handle);
}

fn drainCommands() void {
    var tag: u8 = 0;
    var a: u32 = 0;
    var b: u32 = 0;
    var pumped: u32 = 0;
    while (pumped < 16 and zigled_next_command(&tag, &a, &b)) : (pumped += 1) {
        const cmd: state.Command = switch (tag) {
            1 => .{ .set_on = a != 0 },
            2 => .{ .set_level = @intCast(a & 0xFF) },
            3 => .{ .set_color_xy = .{ .x = @intCast(a & 0xFFFF), .y = @intCast(b & 0xFFFF) } },
            4 => .{ .set_effect = @intCast(a & 0xFFFF) },
            5 => .{ .set_speed = @intCast(a & 0xFF) },
            6 => .{ .set_intensity = @intCast(a & 0xFF) },
            7 => .{ .set_palette = @intCast(a & 0xFF) },
            8 => .{ .identify = @intCast(a & 0xFFFF) },
            else => continue,
        };
        const dirty = state.apply(&g_state, cmd);
        if (dirty) g_debouncer.markDirty(nowMs());
        if (cmd == .identify) g_pp.identify_ms = @as(u32, cmd.identify) * 1000;
    }
}

fn nowMs() u64 {
    return @intCast(@divTrunc(led_output_c.esp_timer_get_time(), 1000));
}

fn checkButton() void {
    const now = nowMs();
    if (button.buttonPressed()) {
        if (g_button_down_ms == 0) g_button_down_ms = now;
        if (now - g_button_down_ms >= 3000 and !g_reset_triggered) {
            g_reset_triggered = true;
            g_fb.clear(.{ .r = 200 });
            var buf: [cfg.count * cfg.pixelStride()]u8 = undefined;
            g_pp.encode(&g_fb, &buf);
            zigled_led_output_push(&buf, buf.len);
            led_output_c.vTaskDelay(300);
            button.factoryReset();
        }
    } else {
        g_button_down_ms = 0;
    }
}

fn renderTask(_: ?*anyopaque) callconv(.c) void {
    var last_wake = led_output_c.xTaskGetTickCount();
    var last_frame_ms: u64 = nowMs();
    var buf: [cfg.count * cfg.pixelStride()]u8 = undefined;

    while (true) {
        _ = led_output_c.xTaskDelayUntil(&last_wake, period_ticks);
        const now = nowMs();
        const dt: u32 = @intCast(@min(1000, now - last_frame_ms));
        last_frame_ms = now;

        drainCommands();
        g_pp.commissioned = commissioning.connected();

        if (g_state.effect_id == 0 and g_state.on) {
            const target = color.xyToRgb(g_state.color_x, g_state.color_y, 255);
            g_pp.beginFadeTo(target);
            g_pp.advanceFade(dt);
            g_fb.clear(g_pp.fade_current);
        } else if (!g_state.on) {
            g_pp.beginFadeTo(.{});
            g_pp.advanceFade(dt);
            g_fb.clear(g_pp.fade_current);
        } else {
            effect_engine.render(cfg, &g_state, now, &g_fb);
        }
        g_pp.applyBrightness(&g_fb, g_state.level);
        g_pp.identifyOverlay(&g_fb, now);
        g_pp.commissioningHint(&g_fb, now);
        g_pp.encode(&g_fb, &buf);
        zigled_led_output_push(&buf, buf.len);

        if (g_pp.identify_ms > dt) g_pp.identify_ms -= dt else g_pp.identify_ms = 0;

        if (g_debouncer.readyToWrite(now)) {
            saveStateToNvs();
            g_debouncer.clear();
        }
        checkButton();
    }
}

export fn zigled_get_on() bool { return g_state.on; }
export fn zigled_get_level() u8 { return g_state.level; }
export fn zigled_get_color_x() u16 { return g_state.color_x; }
export fn zigled_get_color_y() u16 { return g_state.color_y; }
export fn zigled_get_effect_id() u16 { return g_state.effect_id; }
export fn zigled_get_effect_speed() u8 { return g_state.effect_speed; }
export fn zigled_get_effect_intensity() u8 { return g_state.effect_intensity; }
export fn zigled_get_palette_id() u8 { return g_state.palette_id; }

export fn zigled_start() void {
    loadStateFromNvs();
    zigled_led_output_init(cfg.led_data_gpio, cfg.count);
    _ = led_output_c.xTaskCreate(renderTask, "render", 8192, null, 6, null);
}
