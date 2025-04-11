#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>
#include <ESP8266HTTPClient.h>

const char* ssid = "VIRUS";
const char* password = "00000000";

ESP8266WebServer server(80);

IPAddress gatewayIP;
String statusEndpoint;

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

void postStatusUpdate() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient client;
    HTTPClient http;

    http.begin(client, statusEndpoint);
    http.addHeader("Content-Type", "application/json");

    String payload = "{";
    payload += "\"pumpState\":\"" + String(pumpState ? "ON" : "OFF") + "\",";
    payload += "\"moisture\":" + String(moisture_percentage, 2) + ",";
    payload += "\"mode\":\"" + String(controlMode == 0 ? "auto" : "manual") + "\",";
    payload += "\"dryThreshold\":" + String(autoDryThreshold) + ",";
    payload += "\"wetThreshold\":" + String(autoWetThreshold);
    payload += "}";

    int httpResponseCode = http.POST(payload);
    Serial.print("Status POST response: ");
    Serial.println(httpResponseCode);
    http.end();
  }
}

void handleMoisture() {
  int moistureValue = analogRead(soilMoisturePin);
  moisture_percentage = 100 - ((moistureValue / 1023.0) * 100);
  String json = "{\"moisture\": " + String(moisture_percentage, 2) + "}";
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

void handlePumpStatus() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", pumpState ? "ON" : "OFF");
  postStatusUpdate();
}

void handleModeStatus() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", String(controlMode));
  postStatusUpdate();
}

void handleThresholdGet() {
  String json = "{\"dry\":" + String(autoDryThreshold) + ",\"wet\":" + String(autoWetThreshold) + "}";
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
  postStatusUpdate();
}

void handleModeAuto() {
  controlMode = 0;
  EEPROM.write(controlModeAddress, 0);
  EEPROM.commit();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Automatic");
  postStatusUpdate();
}

void handleModeManual() {
  controlMode = 1;
  EEPROM.write(controlModeAddress, 1);
  EEPROM.commit();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Manual");
  postStatusUpdate();
}

void handlePumpStart() {
  controlPump(true);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Pump started");
  postStatusUpdate();
}

void handlePumpStop() {
  controlPump(false);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Pump stopped");
  postStatusUpdate();
}

void handleSaveThresholds() {
  if (server.hasArg("dry") && server.hasArg("wet")) {
    autoDryThreshold = server.arg("dry").toInt();
    autoWetThreshold = server.arg("wet").toInt();
    EEPROM.put(dryThresholdAddress, autoDryThreshold);
    EEPROM.put(wetThresholdAddress, autoWetThreshold);
    EEPROM.commit();
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "text/plain", "Thresholds saved");
    postStatusUpdate();
  } else {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(400, "text/plain", "Missing parameters");
  }
}

void setup() {
  Serial.begin(9600);
  pinMode(soilMoisturePin, INPUT);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, HIGH); // off

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

  gatewayIP = WiFi.gatewayIP();
  statusEndpoint = "http://" + gatewayIP.toString() + "/status-update";
  Serial.print("Status update endpoint: ");
  Serial.println(statusEndpoint);

  server.on("/moisture", handleMoisture);
  server.on("/pump/status", handlePumpStatus);
  server.on("/mode/status", handleModeStatus);
  server.on("/thresholds/get", handleThresholdGet);
  server.on("/mode/auto", handleModeAuto);
  server.on("/mode/manual", handleModeManual);
  server.on("/pump/start", handlePumpStart);
  server.on("/pump/stop", handlePumpStop);
  server.on("/thresholds/save", handleSaveThresholds);

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
      if (moisture_percentage < autoDryThreshold && !pumpState) {
        controlPump(true);
        postStatusUpdate();
      } else if (moisture_percentage > autoWetThreshold && pumpState) {
        controlPump(false);
        postStatusUpdate();
      }
    }

    lastReadTime = millis();
  }
}
