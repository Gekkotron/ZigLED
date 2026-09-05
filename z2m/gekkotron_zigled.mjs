import {light, identify, numeric, enumLookup, occupancy} from 'zigbee-herdsman-converters/lib/modernExtend';

const MFG_CLUSTER = 0xFC01;
const MFG_CODE = 0x1337;

const effectList = {
    solid: 0, breathe: 1, comet: 2, wipe: 3, sparkle: 4,
    rainbow: 5, candle: 6, fire_1d: 7, plasma_2d: 8,
};

export default {
    zigbeeModel: ['ZigLED-1'],
    model: 'ZigLED-1',
    vendor: 'Gekkotron',
    description: 'Zigbee WS28xx LED controller on ESP32-C6',
    endpoint: (device) => ({default: 1, occupancy: 2}),
    extend: [
        identify(),
        light({
            color: {modes: ['xy']},
            configureReporting: true,
            effect: false,
            powerOnBehavior: false,
        }),
        // Deliberately no endpointNames here: modernExtend's occupancy()
        // uses postfixWithEndpointName in fromZigbee (emits bare "occupancy"
        // when it does not consider the definition multi-endpoint) but
        // .withEndpoint(ep) on the exposes, so mixing endpointNames with
        // this single-endpoint occupancy cluster produces a mismatch
        // between the state key ("occupancy") and the exposes property
        // ("occupancy_occupancy") — Z2M's UI then shows N/A even though
        // the value arrives correctly over MQTT. The device only reports
        // occupancy on endpoint 2, so the bare fromZigbee still routes
        // to the right property.
        occupancy(),
        numeric({
            name: 'occupancy_timeout',
            cluster: 'msOccupancySensing',
            attribute: 'pirOToUDelay',
            valueMin: 0,
            valueMax: 3600,
            unit: 's',
            description: 'Seconds before reporting unoccupied after motion ends',
            endpointNames: ['occupancy'],
        }),
        enumLookup({
            name: 'effect',
            cluster: MFG_CLUSTER,
            attribute: {ID: 0x0000, type: 0x21},
            lookup: effectList,
            description: 'Local effect to render',
        }),
        numeric({
            name: 'effect_speed',
            cluster: MFG_CLUSTER,
            attribute: {ID: 0x0001, type: 0x20},
            valueMin: 0, valueMax: 255, valueStep: 1,
            description: 'Effect speed',
        }),
        numeric({
            name: 'effect_intensity',
            cluster: MFG_CLUSTER,
            attribute: {ID: 0x0002, type: 0x20},
            valueMin: 0, valueMax: 255, valueStep: 1,
            description: 'Effect intensity',
        }),
        numeric({
            name: 'palette',
            cluster: MFG_CLUSTER,
            attribute: {ID: 0x0003, type: 0x20},
            valueMin: 0, valueMax: 7, valueStep: 1,
            description: '0 = commanded color; 1..7 = built-in palettes',
        }),
        numeric({
            name: 'active_count',
            cluster: MFG_CLUSTER,
            attribute: {ID: 0x000A, type: 0x21},
            valueMin: 0, valueMax: 65535, valueStep: 1,
            unit: 'LEDs',
            description: 'Runtime cap on lit LEDs. Pixels past this stay dark; the physical count baked at build time is the ceiling.',
        }),
    ],
};
