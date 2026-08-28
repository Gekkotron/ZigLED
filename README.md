# ZigLED

Zigbee-controlled WS2815 LED strip driven by an ESP32-C6, with a matching Zigbee2MQTT external converter for Home Assistant integration.

The controller exposes the strip as three Zigbee endpoints:

| Endpoint | Cluster              | Purpose                                |
| -------- | -------------------- | -------------------------------------- |
| `10`     | Color Dimmable Light | on/off, brightness, RGB (xy / hs)      |
| `11`     | Multistate Output    | animation selector (1..9)              |
| `12`     | Analog Output        | animation speed (1..100)               |

Animations run locally on the C6 at 50 fps — Zigbee only carries the selection, never per-frame pixel data.

## Contents

- `zb_ws2815_c6/zb_ws2815_c6.ino` — Arduino firmware for the ESP32-C6.
- `zb_ws2815.mjs` — Zigbee2MQTT external converter (endpoints, light, animation, speed).

## Hardware

- ESP32-C6 board (tested on Seeed XIAO ESP32-C6).
- 120-LED WS2815 strip (12 V).
- 3.3 V → 5 V level shifter between `GPIO2` and the strip's DIN.
- 12 V PSU sized for the strip; common ground with the board and the level shifter is mandatory.
- Factory reset: hold `BOOT` for 3 s.

## Firmware build (Arduino IDE)

- Board: `XIAO_ESP32C6` (or `ESP32C6 Dev Module`).
- Zigbee Mode: `Zigbee ZCZR` (coordinator/router).
- Partition Scheme: `Zigbee ZCZR 4MB with spiffs`.
- Core: `esp32 >= 3.3.0`.
- Library: `FastLED >= 3.7.0`.

## Zigbee2MQTT integration

1. Copy `zb_ws2815.mjs` to `<z2m-data>/external_converters/zb_ws2815.mjs`.
2. Restart Zigbee2MQTT.
3. Re-pair the device (endpoint layout changed, so a re-pair is required).

## Animations

`solid`, `rainbow`, `comet`, `breathe`, `twinkle`, `chase`, `fire`, `wipe`, `candle`.

## License

See `LICENSE` if present; otherwise all rights reserved by [Gekkotron](https://github.com/Gekkotron).
