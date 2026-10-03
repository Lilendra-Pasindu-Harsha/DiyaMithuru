/*
 * ============================================================
 *  DiyaMithuru - Smart auto-refilling cup  (ESP32, single file)
 * ============================================================
 *  Hardware (your wiring):
 *    Ultrasonic ECHO  -> level shifter HV1/LV1 -> GPIO 18
 *    Ultrasonic TRIG  <- level shifter LV2/HV2 <- GPIO 19
 *    Relay IN         -> GPIO 23   (active-LOW relay module)
 *    Limit switch NO  -> GPIO 27, COM -> GND
 *    MLX90614 SDA     -> GPIO 21   (I2C Data, 3.3V)
 *    MLX90614 SCL     -> GPIO 22   (I2C Clock, 3.3V)
 *
 *  How it works:
 *    - Cup placed  -> pump ON, fills until the cup is FULL
 *    - Cup removed -> pump OFF instantly
 *    - Level drops to LOW while the cup stays -> refills to FULL
 *    - Cup FULL    -> pump OFF, 2 seconds later detects drink temperature (MLX90614)
 *    - Web app (HiveMQ Cloud MQTT):  ON / STOP / FILL buttons,
 *      live level, drink temperature, and spoken announcements on the phone
 *
 *  Arduino libraries:  PubSubClient (by Nick O'Leary)
 *                       WiFiManager  (by tzapu / tablatronix)
 *                       Adafruit MLX90614 (by Adafruit)
 *  Board:              ESP32 Dev Module
 *
 *  MQTT topics:
 *    diyamithuru/cup01/cmd     <- "ON" | "STOP" | "FILL" | "PING" | "TEMP"
 *    diyamithuru/cup01/status  -> JSON (retained)
 *    diyamithuru/cup01/online  -> "1" / "0" (retained, last will)
 * ============================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <WiFiManager.h>        // https://github.com/tzapu/WiFiManager
#include <Wire.h>
#include <Adafruit_MLX90614.h>

// ======================= SETTINGS ===========================
// WiFi is configured via the captive portal (WiFiManager).
// On first boot the ESP32 creates a hotspot called "DiyaMithuru-Setup".
// Connect to it from your phone → pick your network → enter password.
// Credentials are saved to flash and reused on every reboot.

// ---- HiveMQ Cloud ----
const char* MQTT_HOST = "b5ad82f71b0d40d6bcf02b00ce1cd933.s1.eu.hivemq.cloud";
const int   MQTT_PORT = 8883;
const char* MQTT_USER = "Diyamithuru";
const char* MQTT_PASS = "diyamithuru";
const char* DEVICE_ID = "cup01";          // must match the web app

// ---- Pins (from your circuit) ----
const int ECHO_PIN         = 18;
const int TRIG_PIN         = 19;
const int RELAY_PIN        = 23;
const int LIMIT_SWITCH_PIN = 27;

// ---- I2C Pins for MLX90614 Temperature Sensor ----
#define I2C_SDA 21
#define I2C_SCL 22

// Relay module logic (Active-LOW: LOW = ON, HIGH = OFF)
const int RELAY_ON  = LOW;
const int RELAY_OFF = HIGH;

// ---- Level calibration (cm from the sensor face) ----
const float DIST_EMPTY_CM = 12.0;   // sensor -> bottom of EMPTY cup  (0 %)
const float DIST_FULL_CM  = 4.0;    // sensor -> FULL water line      (100 %)

// ---- Fill behaviour ----
const int  LOW_THRESHOLD_PCT  = 30;     // refill when level drops to this
const int  FULL_THRESHOLD_PCT = 90;     // stop pump at this level
const bool FILL_ON_PLACE      = true;   // fill to FULL as soon as a cup is placed
const unsigned long CUP_SETTLE_MS        = 800;    // debounce before pumping
const unsigned long MAX_PUMP_RUN_MS      = 20000;  // safety stop (empty tank / leak)
const unsigned long DISTANCE_INTERVAL_MS = 250;    // level reading rate
const unsigned long TEMP_MEASURE_DELAY_MS = 2000;  // detect temperature 2s after cup is full
const unsigned long STATUS_MIN_GAP_MS    = 400;
const unsigned long STATUS_HEARTBEAT_MS  = 5000;
const unsigned long WIFI_PORTAL_TIMEOUT  = 180;    // portal auto-closes after 3 min
const unsigned long RESET_HOLD_MS        = 5000;   // hold limit switch 5 s at boot to reset WiFi
// ============================================================

String TOPIC_CMD, TOPIC_STATUS, TOPIC_ONLINE;

WiFiManager wm;                  // WiFiManager instance
WiFiClientSecure netClient;
PubSubClient mqtt(netClient);
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

enum Mode { MODE_AUTO, MODE_PAUSED };
Mode mode = MODE_AUTO;

bool  cupPresent    = false;
bool  rawSwitchLast = false;
unsigned long switchChangedAt = 0;
unsigned long cupPlacedAt     = 0;

float distanceCm  = -1;
int   levelPct    = 0;
bool  levelValid  = false;
int   badReadings = 0;

bool  pumpOn     = false;
bool  fillToFull = false;   // set by cup placement or the FILL command
unsigned long pumpStartedAt = 0;
String fault = "";          // "", "TIMEOUT", "SENSOR"

// ---- Temperature state ----
bool  mlxAvailable       = false;
float cupTemp            = 0.0;
float ambientTemp        = 0.0;
bool  cupIsFull          = false;
bool  cupTempRead        = false;
unsigned long cupFullSince = 0;

unsigned long lastDistanceReadTime = 0;
unsigned long lastStatusAt  = 0;
unsigned long lastMqttTryAt = 0;
String lastStatusKey = "";

// ------------------------------------------------------------
//  Pump
// ------------------------------------------------------------
void setPump(bool on, const __FlashStringHelper* reason) {
  if (on == pumpOn) return;
  pumpOn = on;
  if (on) pumpStartedAt = millis();
  digitalWrite(RELAY_PIN, on ? RELAY_ON : RELAY_OFF);
  Serial.print(on ? F(">>> Pump ON  - ") : F("<<< Pump OFF - "));
  Serial.println(reason);
}

// ------------------------------------------------------------
//  Sensors
// ------------------------------------------------------------
float readDistanceCM() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 25000);   // ~4.2 m max
  if (duration == 0) return -1.0;
  return (duration * 0.0343) / 2.0;
}

// Median of 3 quick readings removes splash spikes
float readDistanceMedian() {
  float a = readDistanceCM(); delay(8);
  float b = readDistanceCM(); delay(8);
  float c = readDistanceCM();
  if (a < 0 || b < 0 || c < 0) {                   // use what we have
    float best = max(a, max(b, c));
    return best;
  }
  return max(min(a, b), min(max(a, b), c));
}

void updateCupSwitch() {
  bool raw = (digitalRead(LIMIT_SWITCH_PIN) == LOW);  // pressed = cup on it
  unsigned long now = millis();
  if (raw != rawSwitchLast) { rawSwitchLast = raw; switchChangedAt = now; }
  if (now - switchChangedAt > 50 && raw != cupPresent) {
    cupPresent = raw;
    if (cupPresent) {
      cupPlacedAt = now;
      if (FILL_ON_PLACE) fillToFull = true;
      Serial.println(F(">>> Cup detected"));
    } else {
      fillToFull = false;
      setPump(false, F("cup removed"));
      cupIsFull = false;
      cupFullSince = 0;
      cupTempRead = false;
      cupTemp = 0.0;
      Serial.println(F("<<< Cup removed"));
    }
  }
}

void updateLevel() {
  unsigned long now = millis();
  if (now - lastDistanceReadTime < DISTANCE_INTERVAL_MS) return;
  lastDistanceReadTime = now;

  float d = readDistanceMedian();
  if (d < 0 || d > DIST_EMPTY_CM + 10) {
    if (++badReadings >= 4) levelValid = false;
    return;
  }
  badReadings = 0;
  levelValid = true;
  distanceCm = d;
  float pct = (DIST_EMPTY_CM - d) / (DIST_EMPTY_CM - DIST_FULL_CM) * 100.0;
  levelPct = constrain((int)(pct + 0.5), 0, 100);
}

// ------------------------------------------------------------
//  Fill logic
// ------------------------------------------------------------
void controlPump() {
  unsigned long now = millis();

  if (mode == MODE_PAUSED) { fillToFull = false; setPump(false, F("stopped by app")); return; }
  if (!cupPresent)         { setPump(false, F("no cup")); return; }
  if (now - cupPlacedAt < CUP_SETTLE_MS) return;       // wait for the cup to settle

  if (!levelValid) {
    if (fault != "SENSOR") Serial.println(F("[WARN] Level sensor not reading"));
    fault = "SENSOR";
    setPump(false, F("sensor not reading"));
    return;
  }
  if (fault == "SENSOR") fault = "";

  if (levelPct >= FULL_THRESHOLD_PCT) {
    fillToFull = false;
    setPump(false, F("cup full"));
  } else if (fillToFull || levelPct <= LOW_THRESHOLD_PCT) {
    fillToFull = true;                                  // once started, fill to FULL
    setPump(true, F("filling"));
  }

  // Safety: pump running too long means no water is arriving
  if (pumpOn && now - pumpStartedAt > MAX_PUMP_RUN_MS) {
    fillToFull = false;
    mode = MODE_PAUSED;
    fault = "TIMEOUT";
    setPump(false, F("SAFETY TIMEOUT - check tank/tube, send ON to resume"));
  }
}

// ------------------------------------------------------------
//  Temperature (MLX90614)
// ------------------------------------------------------------
void readCupTemperature() {
  if (!mlxAvailable) {
    Wire.begin(I2C_SDA, I2C_SCL);
    if (mlx.begin()) {
      mlxAvailable = true;
      Serial.println(F("[MLX] MLX90614 initialized successfully."));
    } else {
      Serial.println(F("[MLX] Error: MLX90614 not responding. Check wiring (SDA=21, SCL=22)."));
      return;
    }
  }

  float obj = mlx.readObjectTempC();
  float amb = mlx.readAmbientTempC();

  // Validate reading (-40 to 125 C is normal operational range)
  if (isnan(obj) || obj < -40.0 || obj > 150.0) {
    Serial.printf("[MLX] Invalid reading (obj=%.1f, amb=%.1f)\n", obj, amb);
    return;
  }

  cupTemp = obj;
  ambientTemp = amb;
  cupTempRead = true;
  Serial.printf("[TEMP] Detected 2s after full -> Object: %.2f °C | Ambient: %.2f °C\n", cupTemp, ambientTemp);
  publishStatus(true);
}

void updateTemperature() {
  unsigned long now = millis();

  // Reset temperature reading if cup is removed or pump is running
  if (!cupPresent || pumpOn) {
    if (cupIsFull || cupTempRead || cupTemp > 0.0) {
      cupIsFull = false;
      cupFullSince = 0;
      cupTempRead = false;
      cupTemp = 0.0;
    }
    return;
  }

  // Detect when cup is full (level >= 90% and pump is off)
  if (levelValid && levelPct >= FULL_THRESHOLD_PCT && !cupIsFull) {
    cupIsFull = true;
    cupFullSince = now;
    cupTempRead = false;
    Serial.println(F("[TEMP] Cup is full. Temperature will be detected in 2 seconds..."));
  }

  // If level drops back down while cup stays (e.g. user drinks), reset full state
  if (levelValid && levelPct <= LOW_THRESHOLD_PCT) {
    cupIsFull = false;
    cupFullSince = 0;
    cupTempRead = false;
    cupTemp = 0.0;
  }

  // 2 seconds after cup is full: detect temperature
  if (cupIsFull && !cupTempRead && cupFullSince > 0 && (now - cupFullSince >= TEMP_MEASURE_DELAY_MS)) {
    readCupTemperature();
  }
}

// ------------------------------------------------------------
//  MQTT
// ------------------------------------------------------------
void publishStatus(bool force) {
  // Build JSON with WiFi info so the web app can display it
  String ssid = WiFi.SSID();
  String ip   = WiFi.localIP().toString();
  int ch      = WiFi.channel();

  char buf[380];
  snprintf(buf, sizeof(buf),
    "{\"cup\":%s,\"level\":%d,\"distance\":%.1f,\"levelValid\":%s,"
    "\"pump\":%s,\"mode\":\"%s\",\"fill\":%s,\"fault\":\"%s\",\"rssi\":%d,"
    "\"temp\":%.1f,"
    "\"wifi_ssid\":\"%s\",\"wifi_ip\":\"%s\",\"wifi_ch\":%d}",
    cupPresent ? "true" : "false", levelPct, distanceCm,
    levelValid ? "true" : "false", pumpOn ? "true" : "false",
    mode == MODE_AUTO ? "AUTO" : "PAUSED", fillToFull ? "true" : "false",
    fault.c_str(), (int)WiFi.RSSI(),
    cupTemp,
    ssid.c_str(), ip.c_str(), ch);

  // Only the important fields decide "changed" (distance jitter is ignored)
  char key[80];
  snprintf(key, sizeof(key), "%d,%d,%d,%d,%d,%d,%s,%.1f",
           cupPresent, levelPct, levelValid, pumpOn, (int)mode, fillToFull, fault.c_str(), cupTemp);

  unsigned long now = millis();
  bool changed   = lastStatusKey != key;
  bool heartbeat = now - lastStatusAt >= STATUS_HEARTBEAT_MS;
  bool rateOk    = now - lastStatusAt >= STATUS_MIN_GAP_MS;
  if (force || heartbeat || (changed && rateOk)) {
    if (mqtt.connected()) mqtt.publish(TOPIC_STATUS.c_str(), buf, true);
    lastStatusKey = key;
    lastStatusAt  = now;
  }
}

void handleCommand(String cmd) {
  cmd.trim();
  cmd.toUpperCase();
  Serial.print(F("[APP] ")); Serial.println(cmd);

  if (cmd == "STOP" || cmd == "OFF") {
    mode = MODE_PAUSED;
    fillToFull = false;
    setPump(false, F("stopped by app"));
  } else if (cmd == "ON" || cmd == "START" || cmd == "AUTO") {
    mode = MODE_AUTO;
    fault = "";
  } else if (cmd == "FILL") {
    mode = MODE_AUTO;
    fault = "";
    fillToFull = true;
  } else if (cmd == "TEMP" || cmd == "READ_TEMP") {
    Serial.println(F("[APP] Manual temperature read requested"));
    readCupTemperature();
    publishStatus(true);
  } else if (cmd == "WIFI_RESET") {
    Serial.println(F("[WIFI] Resetting saved credentials..."));
    wm.resetSettings();
    delay(500);
    ESP.restart();
  }
  controlPump();
  publishStatus(true);
}

void onMqttMessage(char* topic, byte* payload, unsigned int len) {
  String msg;
  for (unsigned int i = 0; i < len; i++) msg += (char)payload[i];
  if (TOPIC_CMD == topic) handleCommand(msg);
}

void connectMqtt() {
  if (mqtt.connected() || WiFi.status() != WL_CONNECTED) return;
  unsigned long now = millis();
  if (lastMqttTryAt != 0 && now - lastMqttTryAt < 5000) return;
  lastMqttTryAt = now;

  String clientId = String("diyamithuru-") + DEVICE_ID + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  Serial.print(F("[MQTT] Connecting to HiveMQ... "));
  if (mqtt.connect(clientId.c_str(), MQTT_USER, MQTT_PASS, TOPIC_ONLINE.c_str(), 1, true, "0")) {
    Serial.println(F("connected"));
    mqtt.publish(TOPIC_ONLINE.c_str(), "1", true);
    mqtt.subscribe(TOPIC_CMD.c_str(), 1);
    publishStatus(true);
  } else {
    Serial.printf("failed, rc=%d (retry in 5 s)\n", mqtt.state());
  }
}

// ------------------------------------------------------------
//  WiFiManager setup (replaces hardcoded credentials)
// ------------------------------------------------------------
void connectWifi() {
  WiFi.mode(WIFI_STA);

  // WiFiManager configuration
  wm.setConfigPortalTimeout(WIFI_PORTAL_TIMEOUT);  // auto-close portal
  wm.setConnectTimeout(15);                         // per-network timeout
  wm.setAPCallback([](WiFiManager* mgr) {
    Serial.println(F("[WIFI] Portal active. Connect to 'DiyaMithuru-Setup' hotspot."));
    Serial.print(F("[WIFI] Portal IP: ")); Serial.println(WiFi.softAPIP());
  });
  wm.setSaveConfigCallback([]() {
    Serial.println(F("[WIFI] Credentials saved!"));
  });

  // Try to connect with saved credentials.
  // If none saved (or they fail), starts AP 'DiyaMithuru-Setup'.
  Serial.println(F("[WIFI] Attempting auto-connect..."));
  if (!wm.autoConnect("DiyaMithuru-Setup")) {
    Serial.println(F("[WIFI] Portal timed out. Restarting..."));
    delay(1000);
    ESP.restart();
  }

  Serial.print(F("[WIFI] Connected! IP: "));
  Serial.println(WiFi.localIP());
  Serial.print(F("[WIFI] SSID: ")); Serial.println(WiFi.SSID());
  Serial.print(F("[WIFI] Channel: ")); Serial.println(WiFi.channel());
}

// Check if limit switch is held at boot → reset saved WiFi
void checkWifiReset() {
  if (digitalRead(LIMIT_SWITCH_PIN) == LOW) {
    Serial.println(F("[WIFI] Limit switch held at boot. Hold 5s to reset WiFi..."));
    unsigned long start = millis();
    while (digitalRead(LIMIT_SWITCH_PIN) == LOW && millis() - start < RESET_HOLD_MS) {
      delay(100);
    }
    if (millis() - start >= RESET_HOLD_MS) {
      Serial.println(F("[WIFI] WiFi credentials erased! Starting portal..."));
      wm.resetSettings();
      delay(500);
      ESP.restart();
    } else {
      Serial.println(F("[WIFI] Released early. Normal boot."));
    }
  }
}

// ------------------------------------------------------------
//  Setup / loop
// ------------------------------------------------------------
void setup() {
  Serial.begin(115200);

  // Safe relay setup: pump OFF at power-on
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF);

  pinMode(LIMIT_SWITCH_PIN, INPUT_PULLUP);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  String base  = String("diyamithuru/") + DEVICE_ID;
  TOPIC_CMD    = base + "/cmd";
  TOPIC_STATUS = base + "/status";
  TOPIC_ONLINE = base + "/online";

  Serial.println(F("\n=== DiyaMithuru ==="));

  // Check for WiFi reset (hold limit switch at boot for 5s)
  checkWifiReset();

  // Connect via WiFiManager (portal if needed)
  connectWifi();

  // HiveMQ Cloud needs TLS. setInsecure() encrypts but skips the
  // certificate check - fine for a prototype.
  netClient.setInsecure();
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(512);
  mqtt.setKeepAlive(30);

  // Initialize I2C with ESP32 default pins for MLX90614
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setTimeOut(50);

  Serial.println(F("[MLX] Initializing MLX90614 on ESP32..."));
  if (mlx.begin()) {
    mlxAvailable = true;
    Serial.println(F("[MLX] Sensor connected successfully."));
  } else {
    mlxAvailable = false;
    Serial.println(F("[WARN] MLX90614 not found at boot. Check wiring (SDA=21, SCL=22)."));
  }

  Serial.println(F("[SYSTEM] Ready. Waiting for cup placement..."));
}

void loop() {
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    handleCommand(line);
  }

  connectMqtt();
  mqtt.loop();

  updateCupSwitch();
  updateLevel();
  controlPump();
  updateTemperature();
  publishStatus(false);
}
