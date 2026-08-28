/*
 * Zigbee2MQTT external converter — ESP32-C6 WS2815 strip
 *
 * Install:
 *   1. Copy to  <z2m-data>/external_converters/zb_ws2815.mjs
 *   2. Restart Zigbee2MQTT
 *   3. Re-pair the device (endpoint layout changed, so a re-pair is needed)
 *
 * Endpoints must match the firmware:
 *   10 = light, 11 = animation (multistate output), 12 = speed (analog output)
 */

import {light, identify, deviceEndpoints, enumLookup, numeric}
    from 'zigbee-herdsman-converters/lib/modernExtend';

export default {
    // Must match setManufacturerAndModel() in the firmware.
    zigbeeModel: ['ZB_WS2815'],
    model: 'ZB_WS2815',
    vendor: 'DIY',
    description: 'ESP32-C6 Zigbee controller for a 120-LED WS2815 strip',
    extend: [
        deviceEndpoints({
            endpoints: {light: 10, animation: 11, speed: 12},
            // Keep the light's own properties unsuffixed so it still looks like
            // a normal light in Home Assistant.
            multiEndpointSkip: ['state', 'brightness', 'color', 'color_mode'],
        }),
        identify(),
        light({
            color: {modes: ['xy', 'hs'], enhancedHue: false},
            configureReporting: true,
            effect: false,          // no genOnOff blink/breathe; we do our own
            powerOnBehavior: false, // firmware restores from NVS instead
            endpointNames: ['light'],
        }),
        enumLookup({
            name: 'animation',
            lookup: {
                solid:   1,
                rainbow: 2,
                comet:   3,
                breathe: 4,
                twinkle: 5,
                chase:   6,
                fire:    7,
                wipe:    8,
                candle:  9,
            },
            cluster: 'genMultistateOutput',
            attribute: 'presentValue',
            description: 'Animation running on the strip',
            endpointName: 'animation',
        }),
        numeric({
            name: 'animation_speed',
            cluster: 'genAnalogOutput',
            attribute: 'presentValue',
            description: 'Animation speed',
            valueMin: 1,
            valueMax: 100,
            valueStep: 1,
            endpointNames: ['speed'],
        }),
    ],
};
