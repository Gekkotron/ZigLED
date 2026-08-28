# ZigLED

Zig + ESP-IDF firmware for the ESP32-C6 that drives WS28xx addressable LEDs and exposes them over Zigbee 3.0. Compatible with Zigbee2MQTT via a shipped external converter. Nine local effects, seven palettes, standalone offline mode, factory reset via BOOT.

By Gekkotron.

## Hardware

- XIAO ESP32-C6 (or any ESP32-C6 board — GPIO pins are configurable in `firmware/zig/src/config.zig`).
- WS2815 (default), WS2812B, or WS2814 strip. Data line on GPIO2 through a level shifter. 12 V PSU with common ground.
- BOOT on GPIO9 (default XIAO_ESP32C6).

## Prerequisites

- Zig ≥ 0.14.0 (tested with 0.16.0 via Homebrew)
- ESP-IDF v5.3.2 (installed via `install.sh` in the repo root, or manually — see `install.sh` for the exact commands)
- ESP-Zigbee-SDK ≥ v1.6 (pulled by `firmware/main/idf_component.yml`)
- Zigbee2MQTT ≥ 1.35 for the external converter

## Build and flash

```bash
cd firmware
idf.py set-target esp32c6
idf.py build
idf.py -p /dev/tty.usbmodem* flash monitor
```

## Run host unit tests

```bash
cd firmware/zig
zig build test
```

## Install the Z2M converter

Copy `z2m/gekkotron_zigled.js` into your Zigbee2MQTT data directory's `external_converters/` folder, add it to `configuration.yaml`:

```yaml
external_converters:
  - gekkotron_zigled.js
```

Restart Zigbee2MQTT. Pair the device and it will appear as `Gekkotron ZigLED-1` in Home Assistant with a full light card plus dropdowns for effect, palette, speed, intensity.

## Reference prototype

The `zb_ws2815_c6/` directory and `zb_ws2815.mjs` are the Arduino/FastLED prototype and its converter. They are kept in-tree as reference for effect tuning (fire zones, phase-step scaling) and are not built by this project.
