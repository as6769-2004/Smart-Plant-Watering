#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>

const char* ssid = "VIRUS";
const char* password = "00000000";

ESP8266WebServer server(80);

const int soilMoisturePin = A0;
const int relayPin = D3;
float moisture_percentage;

const int controlModeAddress = 0;
const int dryThresholdAddress = 1;
const int wetThresholdAddress = 5;

int controlMode = 0;
int autoDryThreshold = 40;
int autoWetThreshold = 60;

const long readInterval = 2000;
unsigned long lastReadTime = 0;
bool pumpState = false;

void controlPump(bool turnOn) {
  digitalWrite(relayPin, turnOn ? LOW : HIGH);
  pumpState = turnOn;
  Serial.println(turnOn ? "Pump ON" : "Pump OFF");
}

void handleMoisture() {
  int moistureValue = analogRead(soilMoisturePin);
  moisture_percentage = 100 - ((moistureValue / 1023.0) * 100);

  String json = "{\"moisture\": " + String(moisture_percentage, 2) + "}";
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

void handlePump(bool start) {
  if (controlMode == 1) {
    controlPump(start);
    server.send(200, "text/plain", start ? "Pump started (Manual)" : "Pump stopped (Manual)");
  } else {
    server.send(200, "text/plain", "Cannot change pump state. Currently in Automatic Mode.");
  }
}

void handlePumpStatus() {
  server.send(200, "text/plain", pumpState ? "ON" : "OFF");
}

void handleControlMode(int mode) {
  controlMode = mode;
  EEPROM.write(controlModeAddress, mode);
  EEPROM.commit();
  Serial.println(mode == 0 ? "Control Mode set to Automatic" : "Control Mode set to Manual");
  server.send(200, "text/plain", String(mode));
}

void handleSaveThresholds() {
  if (server.hasArg("dry")) autoDryThreshold = server.arg("dry").toInt();
  if (server.hasArg("wet")) autoWetThreshold = server.arg("wet").toInt();
  EEPROM.put(dryThresholdAddress, autoDryThreshold);
  EEPROM.put(wetThresholdAddress, autoWetThreshold);
  EEPROM.commit();
  server.send(200, "text/plain", "Thresholds saved");
}

void handleGetThresholds() {
  String json = "{\"dry\": " + String(autoDryThreshold) + ", \"wet\": " + String(autoWetThreshold) + "}";
  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(9600);
  pinMode(soilMoisturePin, INPUT);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, HIGH);

  EEPROM.begin(512);
  EEPROM.get(controlModeAddress, controlMode);
  EEPROM.get(dryThresholdAddress, autoDryThreshold);
  EEPROM.get(wetThresholdAddress, autoWetThreshold);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  server.on("/moisture", HTTP_GET, handleMoisture);
  server.on("/pump/start", HTTP_GET, []() { handlePump(true); });
  server.on("/pump/stop", HTTP_GET, []() { handlePump(false); });
  server.on("/pump/status", HTTP_GET, handlePumpStatus);
  server.on("/mode/auto", HTTP_GET, []() { handleControlMode(0); });
  server.on("/mode/manual", HTTP_GET, []() { handleControlMode(1); });
  server.on("/mode/status", HTTP_GET, []() { server.send(200, "text/plain", String(controlMode)); });
  server.on("/thresholds/save", HTTP_GET, handleSaveThresholds);
  server.on("/thresholds/get", HTTP_GET, handleGetThresholds);

  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();

  if (millis() - lastReadTime >= readInterval) {
    int moistureValue = analogRead(soilMoisturePin);
    moisture_percentage = 100 - ((moistureValue / 1023.0) * 100);
    Serial.printf("Moisture: %.2f%%\n", moisture_percentage);

    if (controlMode == 0) {
      if (moisture_percentage < autoDryThreshold && !pumpState) controlPump(true);
      else if (moisture_percentage > autoWetThreshold && pumpState) controlPump(false);
    }
    lastReadTime = millis();
  }
}