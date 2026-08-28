/*
 * Zigbee WS2815 strip controller — ESP32-C6
 * -----------------------------------------
 * 120-LED WS2815 strip exposed over Zigbee as three endpoints:
 *   EP 10  Color Dimmable Light  -> on/off, brightness, RGB
 *   EP 11  Multistate Output     -> animation selector (1..8)
 *   EP 12  Analog Output         -> animation speed (1..100)
 *
 * Animations run locally on the C6 at 50 fps. Zigbee only carries the
 * selection, never per-frame data.
 *
 * Build settings (Arduino IDE):
 *   Board:            XIAO_ESP32C6  (or ESP32C6 Dev Module)
 *   Zigbee Mode:      Zigbee ZCZR (coordinator/router)
 *   Partition Scheme: Zigbee ZCZR 4MB with spiffs
 *   Core:             esp32 >= 3.3.0     Library: FastLED >= 3.7.0
 *
 * Wiring: GPIO2 -> level shifter -> strip DIN. 12 V to the strip.
 *         Common ground between board, shifter and PSU is mandatory.
 * Factory reset: hold BOOT for 3 s.
 */

#ifndef ZIGBEE_MODE_ZCZR
#error "Select Tools > Zigbee Mode > Zigbee ZCZR (coordinator/router)"
#endif

#include "Zigbee.h"
#include <FastLED.h>
#include <Preferences.h>

// ---------------------------------------------------------------- config ----
#define LED_PIN            2
#define NUM_LEDS           120
#define LED_TYPE           WS2812B   // WS2815 uses WS2812B timing
#define COLOR_ORDER        RGB

#define BOOT_BUTTON        9
#define RESET_HOLD_MS      3000

#define EP_LIGHT           10
#define EP_EFFECT          11
#define EP_SPEED           12

#define FRAME_INTERVAL_MS  20        // 50 fps
#define FADE_MS            400       // solid-colour transition time
#define NVS_DEBOUNCE_MS    3000

// Animation ids. Multistate present_value is 1-based per the ZCL convention.
enum Effect : uint8_t {
  FX_SOLID   = 1,
  FX_RAINBOW = 2,
  FX_COMET   = 3,
  FX_BREATHE = 4,
  FX_TWINKLE = 5,
  FX_CHASE   = 6,
  FX_FIRE    = 7,
  FX_WIPE    = 8,
  FX_CANDLE  = 9,
  FX_COUNT   = 9,
};

// ----------------------------------------------------------------- state ----
CRGB leds[NUM_LEDS];

struct LightState {
  bool    on     = false;
  uint8_t r      = 255;
  uint8_t g      = 255;
  uint8_t b      = 255;
  uint8_t level  = 255;
  uint8_t effect = FX_SOLID;
  uint8_t speed  = 50;      // 1..100
};

static LightState commanded;

// Solid-colour fade state.
static CRGB    renderTarget  = CRGB::Black;
static CRGB    renderCurrent = CRGB::Black;
static CRGB    fadeStart     = CRGB::Black;
static uint8_t fadeProgress  = 255;      // 255 = fade complete

// Animation state.
static uint16_t phase = 0;               // 8.8 fixed point position
static uint8_t  heat[NUM_LEDS];          // FX_FIRE only
static uint16_t fireAccum = 0;           // FX_FIRE simulation credit, 8.8 fixed point

static Preferences prefs;
static bool     nvsDirty     = false;
static uint32_t nvsDirtyAt   = 0;
static uint32_t lastFrameAt  = 0;
static uint32_t buttonDownAt = 0;

ZigbeeColorDimmableLight zbLight (EP_LIGHT);
ZigbeeMultistate         zbEffect(EP_EFFECT);
ZigbeeAnalog             zbSpeed (EP_SPEED);

// ------------------------------------------------------------- internals ----
static CRGB commandedColor() {
  return CRGB(commanded.r, commanded.g, commanded.b);
}

// Fold brightness into the colour so a single lerp handles both.
static void recomputeTarget() {
  CRGB next = CRGB::Black;
  if (commanded.on && commanded.level > 0) {
    next = commandedColor();
    next.nscale8_video(commanded.level);
  }
  if (next == renderTarget) return;

  renderTarget = next;
  fadeStart    = renderCurrent;
  fadeProgress = 0;
}

static void saveState() {
  prefs.putBool ("on",  commanded.on);
  prefs.putUChar("r",   commanded.r);
  prefs.putUChar("g",   commanded.g);
  prefs.putUChar("b",   commanded.b);
  prefs.putUChar("lvl", commanded.level);
  prefs.putUChar("fx",  commanded.effect);
  prefs.putUChar("spd", commanded.speed);
  nvsDirty = false;
}

static void markDirty() {
  nvsDirty   = true;
  nvsDirtyAt = millis();
}

static void loadState() {
  commanded.on     = prefs.getBool ("on",  false);
  commanded.r      = prefs.getUChar("r",   255);
  commanded.g      = prefs.getUChar("g",   255);
  commanded.b      = prefs.getUChar("b",   255);
  commanded.level  = prefs.getUChar("lvl", 255);
  commanded.effect = prefs.getUChar("fx",  FX_SOLID);
  commanded.speed  = prefs.getUChar("spd", 50);
  if (commanded.effect < 1 || commanded.effect > FX_COUNT) commanded.effect = FX_SOLID;
  if (commanded.speed  < 1 || commanded.speed  > 100)      commanded.speed  = 50;

  recomputeTarget();
  // Light up immediately, before the radio has even joined.
  renderCurrent = renderTarget;
  fadeStart     = renderTarget;
  fadeProgress  = 255;
  fill_solid(leds, NUM_LEDS, renderCurrent);
  FastLED.show();
}

// ------------------------------------------------------- zigbee callbacks ----
void onLightChange(bool state, uint8_t red, uint8_t green, uint8_t blue, uint8_t level) {
  commanded.on    = state;
  commanded.r     = red;
  commanded.g     = green;
  commanded.b     = blue;
  commanded.level = level;
  recomputeTarget();
  markDirty();
  Serial.printf("[zb] on=%d rgb=%3u,%3u,%3u level=%3u\n", state, red, green, blue, level);
}

// Zigbee lights have a colour *mode*. When Z2M switches to hue/saturation, the
// library routes on/off, level and colour through this callback instead of the
// RGB one — so it must be registered or the strip goes deaf in HS mode.
void onLightChangeHsv(bool state, uint8_t hue, uint8_t saturation, uint8_t value) {
  CRGB rgb;
  hsv2rgb_rainbow(CHSV(hue, saturation, 255), rgb);

  commanded.on    = state;
  commanded.r     = rgb.r;
  commanded.g     = rgb.g;
  commanded.b     = rgb.b;
  commanded.level = value;   // in HS mode, value carries the brightness
  recomputeTarget();
  markDirty();
  Serial.printf("[zb] on=%d hsv=%3u,%3u,%3u -> rgb=%3u,%3u,%3u\n",
                state, hue, saturation, value, rgb.r, rgb.g, rgb.b);
}

void onEffectChange(uint16_t state) {
  if (state < 1 || state > FX_COUNT) {
    Serial.printf("[zb] effect %u out of range, ignored\n", state);
    return;
  }
  commanded.effect = (uint8_t)state;

  // Fade in from whatever is currently on the strip when returning to solid.
  fadeStart    = leds[0];
  fadeProgress = 0;
  phase        = 0;
  fireAccum    = 0;
  memset(heat, 0, sizeof(heat));

  markDirty();
  Serial.printf("[zb] effect=%u\n", state);
}

void onSpeedChange(float value) {
  int v = (int)lroundf(value);
  commanded.speed = (uint8_t)constrain(v, 1, 100);
  markDirty();
  Serial.printf("[zb] speed=%u\n", commanded.speed);
}

// ------------------------------------------------------------ animations ----

// Phase advance per frame, scaled by the speed setting.
static uint16_t phaseStep() {
  return (uint16_t)(8 + (uint32_t)commanded.speed * 40 / 100 * 8);
}

static void fxRainbow() {
  const uint8_t deltaHue = max<uint8_t>(1, 255 / NUM_LEDS);
  fill_rainbow(leds, NUM_LEDS, (uint8_t)(phase >> 6), deltaHue);
}

static void fxComet() {
  fadeToBlackBy(leds, NUM_LEDS, 40);
  const uint16_t pos = (phase >> 8) % NUM_LEDS;
  leds[pos] = commandedColor();
}

static void fxBreathe() {
  const uint8_t b = sin8((uint8_t)(phase >> 6));
  CRGB c = commandedColor();
  c.nscale8_video(b);
  fill_solid(leds, NUM_LEDS, c);
}

static void fxTwinkle() {
  fadeToBlackBy(leds, NUM_LEDS, 24);
  // Higher speed = denser sparkles.
  if (random8() < 40 + commanded.speed) {
    leds[random16(NUM_LEDS)] = commandedColor();
  }
}

static void fxChase() {
  const uint8_t offset = (phase >> 9) % 3;
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  for (uint16_t i = offset; i < NUM_LEDS; i += 3) {
    leds[i] = commandedColor();
  }
}

// Fire2012 is tuned for short strips. Run several independent flames side by
// side instead, so 120 LEDs look like fire rather than one long gradient.
#define FIRE_ZONES  5
#define FIRE_COOL   55
#define FIRE_SPARK  120

// FastLED's HeatColor() ramps to white at the top of its range by adding green
// and blue. This palette stops at yellow — the blue channel is 0 throughout,
// so no white can ever appear.
DEFINE_GRADIENT_PALETTE(fire_gp){
    0,   0,   0, 0,   // off
   60, 130,   0, 0,   // deep red
  120, 255,  30, 0,   // red-orange
  190, 255, 110, 0,   // orange
  255, 255, 185, 0,   // yellow
};
static CRGBPalette16 firePalette = fire_gp;

static void fxFire() {
  #define FIRE_RATE_MAX 128   // 256 = one sim step per frame; lower = slower

  const uint16_t rate = max<uint16_t>(1, (uint16_t)commanded.speed * FIRE_RATE_MAX / 100);
  fireAccum += rate;

  const uint16_t zoneLen = NUM_LEDS / FIRE_ZONES;

  while (fireAccum >= 256) {
    fireAccum -= 256;

    for (uint8_t z = 0; z < FIRE_ZONES; z++) {
      const uint16_t base = z * zoneLen;
      // The last zone absorbs any remainder.
      const uint16_t len  = (z == FIRE_ZONES - 1) ? (NUM_LEDS - base) : zoneLen;
      uint8_t *h = &heat[base];

      // Cool this flame down. Shorter zone = stronger cooling = crisper flame.
      for (uint16_t i = 0; i < len; i++) {
        h[i] = qsub8(h[i], random8(0, ((FIRE_COOL * 10) / len) + 2));
      }
      // Drift heat towards the tip.
      for (uint16_t k = len - 1; k >= 2; k--) {
        h[k] = (h[k - 1] + h[k - 2] + h[k - 2]) / 3;
      }
      // New sparks at this flame's base.
      if (random8() < FIRE_SPARK) {
        const uint8_t y = random8(min<uint16_t>(7, len));
        h[y] = qadd8(h[y], random8(160, 255));
      }
    }
  }

  for (uint16_t j = 0; j < NUM_LEDS; j++) {
    leds[j] = ColorFromPalette(firePalette, heat[j], 255, LINEARBLEND);
  }
}

// Warm, slow, irregular flicker. Uses Perlin noise so neighbouring LEDs move
// together rather than each strobing on its own. Saturation stays at maximum
// so the colour never washes out towards white.
static void fxCandle() {
  for (uint16_t i = 0; i < NUM_LEDS; i++) {
    const uint8_t n = inoise8(i * 30, phase >> 2);
    const uint8_t bright = 110 + scale8(n, 145);   // never fully dark
    const uint8_t hue    = 8 + (n >> 4);           // deep red through amber
    leds[i] = CHSV(hue, 255, bright);
  }
}

static void fxWipe() {
  // Fills forwards, then clears forwards.
  const uint16_t span = NUM_LEDS * 2;
  const uint16_t pos  = (phase >> 8) % span;
  if (pos < NUM_LEDS) {
    for (uint16_t i = 0; i < NUM_LEDS; i++) {
      leds[i] = (i <= pos) ? commandedColor() : CRGB::Black;
    }
  } else {
    const uint16_t cleared = pos - NUM_LEDS;
    for (uint16_t i = 0; i < NUM_LEDS; i++) {
      leds[i] = (i <= cleared) ? CRGB::Black : commandedColor();
    }
  }
}

// ---------------------------------------------------------------- render ----
static void renderSolid() {
  if (fadeProgress >= 255) return;   // nothing to do

  const uint16_t step = max<uint16_t>(1, (255UL * FRAME_INTERVAL_MS) / FADE_MS);
  fadeProgress = (uint8_t)min<uint16_t>(255, fadeProgress + step);

  // Land exactly on the target: lerp8by8 never quite gets there.
  renderCurrent = (fadeProgress >= 255) ? renderTarget
                                        : blend(fadeStart, renderTarget, fadeProgress);
  fill_solid(leds, NUM_LEDS, renderCurrent);
  FastLED.show();
}

static void renderEffect() {
  phase += phaseStep();

  switch (commanded.effect) {
    case FX_RAINBOW: fxRainbow(); break;
    case FX_COMET:   fxComet();   break;
    case FX_BREATHE: fxBreathe(); break;
    case FX_TWINKLE: fxTwinkle(); break;
    case FX_CHASE:   fxChase();   break;
    case FX_FIRE:    fxFire();    break;
    case FX_WIPE:    fxWipe();    break;
    case FX_CANDLE:  fxCandle();  break;
    default:         return;
  }

  // Apply master brightness on top of whatever the animation produced.
  nscale8(leds, NUM_LEDS, commanded.level);
  renderCurrent = leds[0];   // so a later return to solid fades from here
  FastLED.show();
}

static void renderFrame() {
  const bool off = !commanded.on || commanded.level == 0;

  if (off || commanded.effect == FX_SOLID) {
    renderSolid();
  } else {
    renderEffect();
  }
}

// ---------------------------------------------------------------- button ----
static void handleButton() {
  if (digitalRead(BOOT_BUTTON) == LOW) {
    if (buttonDownAt == 0) {
      buttonDownAt = millis();
    } else if (millis() - buttonDownAt > RESET_HOLD_MS) {
      Serial.println("[zb] factory reset");
      fill_solid(leds, NUM_LEDS, CRGB::Red);
      FastLED.show();
      delay(300);
      prefs.clear();
      Zigbee.factoryReset();   // erases the Zigbee network and reboots
    }
  } else {
    buttonDownAt = 0;
  }
}

// ------------------------------------------------------------------ main ----
void setup() {
  Serial.begin(115200);
  pinMode(BOOT_BUTTON, INPUT_PULLUP);

  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS)
         .setCorrection(TypicalLEDStrip);
  FastLED.clear(true);

  prefs.begin("ws2815", false);
  loadState();

  // --- light endpoint ---
  zbLight.onLightChangeRgb(onLightChange);
  zbLight.onLightChangeHsv(onLightChangeHsv);
  zbLight.setManufacturerAndModel("DIY", "ZB_WS2815");
  zbLight.setLightColorCapabilities(ZIGBEE_COLOR_CAPABILITY_X_Y |
                                    ZIGBEE_COLOR_CAPABILITY_HUE_SATURATION);

  // --- effect selector endpoint ---
  zbEffect.addMultistateOutput();
  zbEffect.setMultistateOutputDescription("Animation");
  zbEffect.setMultistateOutputStates(FX_COUNT);
  zbEffect.onMultistateOutputChange(onEffectChange);

  // --- speed endpoint ---
  zbSpeed.addAnalogOutput();
  zbSpeed.setAnalogOutputDescription("Animation speed");
  zbSpeed.setAnalogOutputMinMax(1, 100);
  zbSpeed.setAnalogOutputResolution(1);
  zbSpeed.onAnalogOutputChange(onSpeedChange);

  Zigbee.addEndpoint(&zbLight);
  Zigbee.addEndpoint(&zbEffect);
  Zigbee.addEndpoint(&zbSpeed);

  // Pin this to your coordinator's channel to speed up joining, e.g.
  // Zigbee.setPrimaryChannelMask(1UL << 15);

  if (!Zigbee.begin(ZIGBEE_ROUTER)) {
    Serial.println("[zb] stack failed to start, rebooting");
    delay(2000);
    ESP.restart();
  }

  Serial.println("[zb] waiting to join...");
  while (!Zigbee.connected()) {
    delay(100);
    handleButton();   // stay resettable even if joining never succeeds
  }
  Serial.println("[zb] joined");

  // Report the NVS-restored state so Z2M isn't showing something stale.
  zbLight.setLight(commanded.on, commanded.level, commanded.r, commanded.g, commanded.b);
  zbEffect.setMultistateOutput(commanded.effect);
  zbSpeed.setAnalogOutput(commanded.speed);
}

void loop() {
  const uint32_t now = millis();

  if (now - lastFrameAt >= FRAME_INTERVAL_MS) {
    lastFrameAt = now;
    renderFrame();
  }

  if (nvsDirty && now - nvsDirtyAt >= NVS_DEBOUNCE_MS) saveState();

  handleButton();
  delay(1);
}
