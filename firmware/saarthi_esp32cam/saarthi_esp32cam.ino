// ============================================
// INCLUDES (Must be at the top)
// ============================================
#include "esp_camera.h"
#include "WiFi.h"
#include "HTTPClient.h"
#include "WiFiClientSecure.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "driver/rtc_io.h"
#include "esp_http_server.h"
#include <ArduinoJson.h>
#include <EEPROM.h>

// ============================================
// CONFIGURATION
// ============================================
const char* WIFI_SSID = "CMF";
const char* WIFI_PASSWORD = "Nothing2";
const char* BACKEND_SERVER_HOST = "devloperwala.in";
const int BACKEND_SERVER_PORT = 443; // HTTPS
const char* DEVICE_ID = "ESP32_CAM_001"; // Change per device

// Device Token - Will be loaded from EEPROM or set via provisioning
// Initial token can be set here for first-time provisioning
const char* INITIAL_DEVICE_TOKEN = ""; // Leave empty to use EEPROM only

// Dynamic token storage (loaded from EEPROM)
String deviceToken = "";
String currentUserId = "";

// Dynamic user configuration (fetched from backend)
struct UserConfig {
  String userId;
  String userName;
  String userPhone;
  String userEmail;
  String languagePreference;
  String disabilityType;
  float ultrasonicThreshold;
  int micThreshold;
  bool nightModeEnabled;
  String nightModeStart;
  String nightModeEnd;
  bool continuousTracking;
  bool manualSOSEnabled;
  String emergencyContacts[5]; // Max 5 emergency contacts
  int emergencyContactCount;
} userConfig;

// Initialize user config
void initUserConfig() {
  userConfig.userId = "";
  userConfig.userName = "";
  userConfig.userPhone = "";
  userConfig.userEmail = "";
  userConfig.languagePreference = "en";
  userConfig.disabilityType = "NONE";
  userConfig.ultrasonicThreshold = 30.0;
  userConfig.micThreshold = 2000;
  userConfig.nightModeEnabled = false;
  userConfig.nightModeStart = "21:00:00";
  userConfig.nightModeEnd = "06:00:00";
  userConfig.continuousTracking = true;
  userConfig.manualSOSEnabled = true;
  userConfig.emergencyContactCount = 0;
  for (int i = 0; i < 5; i++) {
    userConfig.emergencyContacts[i] = "";
  }
}

// WhatsApp API (optional direct call from ESP32)
const char* WHATSAPP_API_ACCESS_TOKEN = "683bfe5fc5a1d";
const char* WHATSAPP_API_INSTANCE_ID = "690ED82947B5D";

// Debugging Flags
const bool DEBUG_SENSORS = true;
const bool DEBUG_HTTP = true;

// ============================================
// PIN DEFINITIONS
// ============================================
#define TRIG_PIN   13
#define ECHO_PIN   12
#define TOUCH_PIN  15
#define MIC_PIN    14
#define LED_PIN    4

// ============================================
// SENSOR CONSTANTS
// ============================================
const unsigned long MEASURE_TIMEOUT = 5000UL; // 5ms timeout (~85cm max)
const float SOUND_SPEED = 0.0343; // cm/µs
const int MIC_SAMPLES = 10; // Noise reduction

// Sensor thresholds (will be synced from backend)
float ULTRASONIC_THRESHOLD = 30.0; // cm
int MIC_THRESHOLD = 2000; // Raw ADC value

// ============================================
// TOUCH GESTURE DETECTION
// ============================================
unsigned long lastTouchTime = 0;
int touchTapCount = 0;
const unsigned long TAP_TIMEOUT = 500; // ms between taps
const unsigned long LONG_PRESS_TIME = 2000; // ms for long press
unsigned long touchStartTime = 0;
bool touchPressed = false;

// EEPROM Configuration
#define EEPROM_SIZE 512
#define EEPROM_TOKEN_ADDRESS 0
#define EEPROM_TOKEN_MAX_LEN 128

// ============================================
// CAMERA STREAMING SETUP
// ============================================
#define PART_BOUNDARY "123456789000000000000987654321"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

httpd_handle_t stream_httpd = NULL;

// ============================================
// GLOBAL VARIABLES
// ============================================
unsigned long lastSensorSend = 0;
const unsigned long SENSOR_SEND_INTERVAL = 2000; // Send every 2 seconds
unsigned long lastThresholdSync = 0;
const unsigned long THRESHOLD_SYNC_INTERVAL = 300000; // Sync every 5 minutes

// ============================================
// CAMERA STREAM HANDLER
// ============================================
static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len;
  uint8_t * _jpg_buf;
  char part_buf[64];

  static int64_t last_frame = 0;
  if(!last_frame) {
    last_frame = esp_timer_get_time();
  }

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if(res != ESP_OK) {
    return res;
  }

  while(true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      res = ESP_FAIL;
    } else {
      if(fb->format != PIXFORMAT_JPEG) {
        bool jpeg_converted = frame2jpg(fb, 80, &_jpg_buf, &_jpg_buf_len);
        if(!jpeg_converted) {
          Serial.println("JPEG compression failed");
          esp_camera_fb_return(fb);
          res = ESP_FAIL;
        }
      } else {
        _jpg_buf_len = fb->len;
        _jpg_buf = fb->buf;
      }
    }
    if(res == ESP_OK) {
      sprintf(part_buf, _STREAM_PART, _jpg_buf_len);
      httpd_resp_send_chunk(req, part_buf, strlen(part_buf));
      httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
      httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    if(fb->format != PIXFORMAT_JPEG) {
      free(_jpg_buf);
    }
    esp_camera_fb_return(fb);
    if(res != ESP_OK) {
      break;
    }
    int64_t current_frame = esp_timer_get_time();
    int64_t frame_time = current_frame - last_frame;
    last_frame = current_frame;
    frame_time /= 1000;
  }

  last_frame = 0;
  return res;
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 81;

  httpd_uri_t stream_uri = {
    .uri       = "/stream",
    .method    = HTTP_GET,
    .handler   = stream_handler,
    .user_ctx  = NULL
  };

  Serial.printf("Starting stream server on port: '%d'\n", config.server_port);
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
    Serial.println("Camera stream server started successfully.");
    Serial.printf("Stream URL: http://%s:81/stream\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("Error starting camera stream server!");
  }
}

// ============================================
// SENSOR READING FUNCTIONS
// ============================================

float readUltrasonic() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  long duration = pulseIn(ECHO_PIN, HIGH, MEASURE_TIMEOUT);
  if (duration == 0) {
    return -1.0; // No echo
  }
  float distance = duration * SOUND_SPEED / 2.0;
  return distance;
}

bool readTouch() {
  return (digitalRead(TOUCH_PIN) == HIGH);
}

int readMicrophone() {
  int sum = 0;
  int maxVal = 0;
  int minVal = 4095;
  
  // Read multiple samples to get accurate reading
  for (int i = 0; i < MIC_SAMPLES * 2; i++) {
    int reading = analogRead(MIC_PIN);
    sum += reading;
    if (reading > maxVal) maxVal = reading;
    if (reading < minVal) minVal = reading;
    delayMicroseconds(50);
  }
  
  // Calculate average and peak-to-peak
  int avg = sum / (MIC_SAMPLES * 2);
  int peakToPeak = maxVal - minVal;
  
  // Return peak-to-peak value (more accurate for sound detection)
  // If peak-to-peak is very small, return average
  if (peakToPeak < 10) {
    return avg;
  }
  return peakToPeak;
}

// ============================================
// TOUCH GESTURE DETECTION
// ============================================
void handleTouchGesture() {
  bool touched = readTouch();
  unsigned long currentTime = millis();

  if (touched && !touchPressed) {
    // Touch just started
    touchStartTime = currentTime;
    touchPressed = true;
    if (DEBUG_SENSORS) Serial.println("Touch started");
  } else if (!touched && touchPressed) {
    // Touch released
    touchPressed = false;
    unsigned long pressDuration = currentTime - touchStartTime;
    
    if (pressDuration >= LONG_PRESS_TIME) {
      // Long press = Emergency
      if (DEBUG_SENSORS) Serial.println("LONG PRESS DETECTED - EMERGENCY!");
      triggerSOS("LONG_PRESS");
    } else {
      // Short press - count taps
      if (currentTime - lastTouchTime < TAP_TIMEOUT) {
        touchTapCount++;
      } else {
        touchTapCount = 1;
      }
      lastTouchTime = currentTime;
      
      // Check for multiple taps
      if (touchTapCount >= 3) {
        if (DEBUG_SENSORS) Serial.println("TRIPLE TAP DETECTED - SOS!");
        triggerSOS("TRIPLE_TAP");
        touchTapCount = 0;
      } else if (touchTapCount == 2) {
        if (DEBUG_SENSORS) Serial.println("DOUBLE TAP DETECTED - Music");
        // Send double tap event
        sendEventToBackend("DOUBLE_TAP_MUSIC", "DOUBLE", -1, 1, 0);
        touchTapCount = 0;
      } else if (touchTapCount == 1) {
        // Wait a bit to see if there's a second tap
        delay(300);
        if (touchTapCount == 1) {
          // Single tap confirmed
          if (DEBUG_SENSORS) Serial.println("SINGLE TAP DETECTED - Voice Assistant");
          sendEventToBackend("SINGLE_TAP_VOICE", "SINGLE", -1, 1, 0);
          touchTapCount = 0;
        }
      }
    }
  }
  
  // Reset tap count if timeout
  if (currentTime - lastTouchTime > TAP_TIMEOUT && touchTapCount > 0) {
    touchTapCount = 0;
  }
}

// ============================================
// EMERGENCY FUNCTIONS
// ============================================
void triggerSOS(String gestureType) {
  Serial.println("=== SOS TRIGGERED ===");
  digitalWrite(LED_PIN, HIGH);
  
  // Send SOS event first to get event_id
  String eventResponse = sendEventToBackend("SOS_TOUCH", gestureType, -1, 1, 0);
  
  // Extract event_id from response if available
  String eventId = "";
  int eventIdStart = eventResponse.indexOf("\"event_id\":");
  if (eventIdStart > 0) {
    int eventIdEnd = eventResponse.indexOf(",", eventIdStart);
    if (eventIdEnd < 0) eventIdEnd = eventResponse.indexOf("}", eventIdStart);
    if (eventIdEnd > 0) {
      eventId = eventResponse.substring(eventIdStart + 11, eventIdEnd);
      eventId.trim();
      // Remove quotes if present
      if (eventId.startsWith("\"")) eventId = eventId.substring(1);
      if (eventId.endsWith("\"")) eventId = eventId.substring(0, eventId.length() - 1);
    }
  }
  
  // Capture image and send with event_id
  camera_fb_t * fb = esp_camera_fb_get();
  if (fb) {
    sendSnapshotToBackend(fb, eventId);
    esp_camera_fb_return(fb);
    if (DEBUG_SENSORS) Serial.println("SOS photo captured and sent with event_id: " + eventId);
  }
  
  // Record audio from ESP32 external microphone (5 seconds)
  recordAndSendAudio(eventId, 5000);
  
  // Blink LED
  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

void triggerObstacleAlert(float distance) {
  if (DEBUG_SENSORS) Serial.printf("OBSTACLE ALERT: %.1f cm\n", distance);
  
  // Send obstacle alert first to get event_id
  String eventResponse = sendEventToBackend("OBSTACLE_ALERT", "Distance: " + String(distance), distance, 0, 0);
  
  // Extract event_id from response if available
  String eventId = "";
  int eventIdStart = eventResponse.indexOf("\"event_id\":");
  if (eventIdStart > 0) {
    int eventIdEnd = eventResponse.indexOf(",", eventIdStart);
    if (eventIdEnd < 0) eventIdEnd = eventResponse.indexOf("}", eventIdStart);
    if (eventIdEnd > 0) {
      eventId = eventResponse.substring(eventIdStart + 11, eventIdEnd);
      eventId.trim();
      // Remove quotes if present
      if (eventId.startsWith("\"")) eventId = eventId.substring(1);
      if (eventId.endsWith("\"")) eventId = eventId.substring(0, eventId.length() - 1);
    }
  }
  
  // Always capture image when obstacle is detected (50-100cm range)
  // User requirement: Photo capture on obstacle detection
  camera_fb_t * fb = esp_camera_fb_get();
  if (fb) {
    sendSnapshotToBackend(fb, eventId);
    esp_camera_fb_return(fb);
    if (DEBUG_SENSORS) Serial.println("Photo captured and sent to backend with event_id: " + eventId);
  }
  
  // Record audio from ESP32 external microphone (5 seconds)
  recordAndSendAudio(eventId, 5000);
  
  // Haptic feedback (LED blink)
  digitalWrite(LED_PIN, HIGH);
  delay(50);
  digitalWrite(LED_PIN, LOW);
}

void triggerLoudSoundAlert(int micValue) {
  if (DEBUG_SENSORS) Serial.printf("LOUD SOUND ALERT: %d\n", micValue);
  
  sendEventToBackend("LOUD_SOUND_ALERT", "Mic: " + String(micValue), -1, 0, micValue);
  
  // Strong vibration pattern (LED flash)
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

// ============================================
// HTTP COMMUNICATION
// ============================================

// Forward declarations
void sendSnapshotToBackend(camera_fb_t * fb, String eventId = "");
void recordAndSendAudio(String eventId, int durationMs = 5000);

void sendSensorDataToBackend(float distance, bool touched, int micRaw) {
  if (WiFi.status() != WL_CONNECTED) {
    if (DEBUG_HTTP) Serial.println("WiFi not connected");
    return;
  }

  WiFiClientSecure client;
  client.setInsecure(); // Skip SSL verification for self-signed certs (use proper cert in production)
  
  HTTPClient http;
  http.setTimeout(5000);
  
  // Get current IP address for stream URL
  String currentIP = WiFi.localIP().toString();
  String streamUrl = "http://" + currentIP + ":81/stream";
  
  String url = "https://" + String(BACKEND_SERVER_HOST) + ":" + String(BACKEND_SERVER_PORT) + "/saarthi/api/device/postSensorData.php";
  url += "?device_id=" + String(DEVICE_ID);
  if (currentUserId.length() > 0) {
    url += "&user_id=" + currentUserId;
  }
  url += "&distance=" + String(distance);
  url += "&touch=" + String(touched ? 1 : 0);
  url += "&mic=" + String(micRaw);
  // URL encode the stream URL to handle special characters
  String encodedStreamUrl = streamUrl;
  encodedStreamUrl.replace(":", "%3A");
  encodedStreamUrl.replace("/", "%2F");
  
  url += "&ip_address=" + currentIP;
  url += "&stream_url=" + encodedStreamUrl;

  if (DEBUG_HTTP) {
    Serial.printf("Sending sensor data: %s\n", url.c_str());
    Serial.printf("IP Address: %s\n", currentIP.c_str());
    Serial.printf("Stream URL: %s\n", streamUrl.c_str());
  }
  
  http.begin(client, url);
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    if (DEBUG_HTTP) Serial.printf("Response code: %d\n", httpResponseCode);
    String response = http.getString();
    if (DEBUG_HTTP) Serial.println("Response: " + response);
    
    // Parse response for event triggers
    if (response.indexOf("\"event_triggered\":true") > 0) {
      Serial.println("Backend confirmed event triggered");
    }
  } else {
    if (DEBUG_HTTP) Serial.printf("HTTP Error: %s\n", http.errorToString(httpResponseCode).c_str());
  }
  
  http.end();
}

String sendEventToBackend(String eventType, String payload, float distance, int touch, int mic) {
  if (WiFi.status() != WL_CONNECTED) return "";

  WiFiClientSecure client;
  client.setInsecure();
  
  HTTPClient http;
  http.setTimeout(5000);
  
  String url = "https://" + String(BACKEND_SERVER_HOST) + ":" + String(BACKEND_SERVER_PORT) + "/saarthi/api/device/postSensorData.php";
  url += "?device_id=" + String(DEVICE_ID);
  if (currentUserId.length() > 0) {
    url += "&user_id=" + currentUserId;
  }
  url += "&distance=" + String(distance);
  url += "&touch=" + String(touch);
  url += "&mic=" + String(mic);
  url += "&event_type=" + eventType;
  
  // Add touch_type for gesture detection
  if (payload == "LONG_PRESS") {
    url += "&touch_type=LONG_PRESS";
  } else if (payload == "DOUBLE") {
    url += "&touch_type=DOUBLE";
  } else if (payload == "SINGLE") {
    url += "&touch_type=SINGLE";
  }

  http.begin(client, url);
  int httpResponseCode = http.GET();
  String response = "";
  
  if (httpResponseCode > 0) {
    response = http.getString();
    if (DEBUG_HTTP) {
      Serial.printf("Event sent: %s, Response: %d\n", eventType.c_str(), httpResponseCode);
      Serial.println("Response: " + response);
    }
  }
  
  http.end();
  return response;
}

void sendSnapshotToBackend(camera_fb_t * fb, String eventId) {
  if (WiFi.status() != WL_CONNECTED || !fb) return;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(20000);
  
  if (!client.connect(BACKEND_SERVER_HOST, BACKEND_SERVER_PORT)) {
    if (DEBUG_HTTP) Serial.println("Connection to server failed");
    return;
  }
  
  // Create multipart form data
  String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
  
  // Build multipart body header
  String bodyHeader = "--" + boundary + "\r\n";
  bodyHeader += "Content-Disposition: form-data; name=\"device_id\"\r\n\r\n";
  bodyHeader += String(DEVICE_ID) + "\r\n";
  
  if (eventId.length() > 0) {
    bodyHeader += "--" + boundary + "\r\n";
    bodyHeader += "Content-Disposition: form-data; name=\"event_id\"\r\n\r\n";
    bodyHeader += eventId + "\r\n";
  }
  
  bodyHeader += "--" + boundary + "\r\n";
  bodyHeader += "Content-Disposition: form-data; name=\"image\"; filename=\"snapshot.jpg\"\r\n";
  bodyHeader += "Content-Type: image/jpeg\r\n\r\n";
  
  String bodyFooter = "\r\n--" + boundary + "--\r\n";
  
  // Calculate total size
  int totalSize = bodyHeader.length() + fb->len + bodyFooter.length();
  
  // Send HTTP POST request
  String request = "POST /saarthi/api/device/uploadSnapshot.php HTTP/1.1\r\n";
  request += "Host: " + String(BACKEND_SERVER_HOST) + "\r\n";
  request += "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";
  request += "Content-Length: " + String(totalSize) + "\r\n";
  request += "Connection: close\r\n\r\n";
  
  client.print(request);
  client.print(bodyHeader);
  client.write(fb->buf, fb->len);
  client.print(bodyFooter);
  
  // Wait for response
  unsigned long timeout = millis();
  while (client.available() == 0) {
    if (millis() - timeout > 20000) {
      if (DEBUG_HTTP) Serial.println("Client timeout");
      client.stop();
      return;
    }
  }
  
  // Read response
  String response = "";
  while (client.available()) {
    response += client.readStringUntil('\r');
  }
  
  if (DEBUG_HTTP) {
    Serial.println("Response: " + response);
    int statusCode = 0;
    if (response.indexOf("HTTP/1.1") >= 0) {
      int spacePos = response.indexOf(' ', response.indexOf("HTTP/1.1"));
      if (spacePos > 0) {
        statusCode = response.substring(spacePos + 1, spacePos + 4).toInt();
      }
    }
    Serial.printf("HTTP Status: %d\n", statusCode);
  }
  
  client.stop();
}

void recordAndSendAudio(String eventId, int durationMs) {
  if (WiFi.status() != WL_CONNECTED) return;
  
  if (DEBUG_SENSORS) Serial.println("Recording audio from ESP32 external microphone...");
  
  // Sample rate: 8kHz (8000 samples per second)
  // 16-bit samples (2 bytes per sample)
  // Duration: durationMs milliseconds
  int sampleRate = 8000;
  int samplesNeeded = (sampleRate * durationMs) / 1000;
  int maxSamples = 4000; // Limit to ~0.5 seconds to avoid memory issues (8KB)
  if (samplesNeeded > maxSamples) samplesNeeded = maxSamples;
  
  // Allocate buffer for audio samples (16-bit = 2 bytes per sample)
  uint8_t* audioBuffer = (uint8_t*)malloc(samplesNeeded * 2);
  if (!audioBuffer) {
    if (DEBUG_SENSORS) Serial.println("Failed to allocate audio buffer");
    return;
  }
  
  // Configure ADC for microphone
  analogReadResolution(12); // 12-bit ADC (0-4095)
  analogSetPinAttenuation(MIC_PIN, ADC_11db); // 0-3.3V range
  
  // Record audio samples
  unsigned long startTime = millis();
  int sampleIndex = 0;
  int sampleInterval = 1000000 / sampleRate; // microseconds between samples
  
  while (sampleIndex < samplesNeeded && (millis() - startTime) < durationMs) {
    // Read analog value (0-4095)
    int adcValue = analogRead(MIC_PIN);
    
    // Convert 12-bit ADC (0-4095) to 16-bit signed integer (-32768 to 32767)
    // Center at 2048 (midpoint), scale to 16-bit range
    int16_t sample = ((adcValue - 2048) * 32767) / 2048;
    
    // Store as little-endian 16-bit
    audioBuffer[sampleIndex * 2] = sample & 0xFF;
    audioBuffer[sampleIndex * 2 + 1] = (sample >> 8) & 0xFF;
    
    sampleIndex++;
    delayMicroseconds(sampleInterval);
  }
  
  if (DEBUG_SENSORS) Serial.printf("Recorded %d audio samples\n", sampleIndex);
  
  // Send audio to backend
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(20000);
  
  if (!client.connect(BACKEND_SERVER_HOST, BACKEND_SERVER_PORT)) {
    if (DEBUG_HTTP) Serial.println("Connection to server failed for audio upload");
    free(audioBuffer);
    return;
  }
  
  // Create multipart form data
  String boundary = "----WebKitFormBoundaryAudio";
  
  String bodyHeader = "--" + boundary + "\r\n";
  bodyHeader += "Content-Disposition: form-data; name=\"device_id\"\r\n\r\n";
  bodyHeader += String(DEVICE_ID) + "\r\n";
  
  if (eventId.length() > 0) {
    bodyHeader += "--" + boundary + "\r\n";
    bodyHeader += "Content-Disposition: form-data; name=\"event_id\"\r\n\r\n";
    bodyHeader += eventId + "\r\n";
  }
  
  bodyHeader += "--" + boundary + "\r\n";
  bodyHeader += "Content-Disposition: form-data; name=\"audio\"; filename=\"audio.raw\"\r\n";
  bodyHeader += "Content-Type: application/octet-stream\r\n\r\n";
  
  String bodyFooter = "\r\n--" + boundary + "--\r\n";
  
  int audioDataSize = sampleIndex * 2;
  int totalSize = bodyHeader.length() + audioDataSize + bodyFooter.length();
  
  // Send HTTP POST request
  String request = "POST /saarthi/api/device/uploadAudioFromESP32.php HTTP/1.1\r\n";
  request += "Host: " + String(BACKEND_SERVER_HOST) + "\r\n";
  request += "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";
  request += "Content-Length: " + String(totalSize) + "\r\n";
  request += "Connection: close\r\n\r\n";
  
  client.print(request);
  client.print(bodyHeader);
  client.write(audioBuffer, audioDataSize);
  client.print(bodyFooter);
  
  // Wait for response
  unsigned long timeout = millis();
  while (client.available() == 0) {
    if (millis() - timeout > 20000) {
      if (DEBUG_HTTP) Serial.println("Audio upload timeout");
      client.stop();
      free(audioBuffer);
      return;
    }
  }
  
  // Read response
  String response = "";
  while (client.available()) {
    response += client.readStringUntil('\r');
  }
  
  if (DEBUG_HTTP) {
    Serial.println("Audio upload response: " + response);
  }
  
  client.stop();
  free(audioBuffer);
  
  if (DEBUG_SENSORS) Serial.println("Audio recorded and uploaded successfully");
}

void syncThresholdsFromBackend() {
  if (WiFi.status() != WL_CONNECTED) return;
  
  // This would call an API to get thresholds
  // For now, using defaults set in constants
  if (DEBUG_HTTP) Serial.println("Threshold sync (placeholder)");
}

// ============================================
// EEPROM TOKEN MANAGEMENT
// ============================================

void initEEPROM() {
  EEPROM.begin(EEPROM_SIZE);
  Serial.println("EEPROM initialized");
}

String loadTokenFromEEPROM() {
  String token = "";
  char buffer[EEPROM_TOKEN_MAX_LEN + 1];
  
  for (int i = 0; i < EEPROM_TOKEN_MAX_LEN; i++) {
    char c = EEPROM.read(EEPROM_TOKEN_ADDRESS + i);
    if (c == '\0' || c == 0xFF) break;
    buffer[i] = c;
    token += c;
  }
  buffer[EEPROM_TOKEN_MAX_LEN] = '\0';
  
  if (token.length() > 0) {
    Serial.println("Token loaded from EEPROM");
    return token;
  }
  return "";
}

void saveTokenToEEPROM(String token) {
  if (token.length() == 0 || token.length() > EEPROM_TOKEN_MAX_LEN) {
    Serial.println("Invalid token length for EEPROM");
    return;
  }
  
  // Clear EEPROM area first
  for (int i = 0; i < EEPROM_TOKEN_MAX_LEN; i++) {
    EEPROM.write(EEPROM_TOKEN_ADDRESS + i, 0);
  }
  
  // Write token
  for (int i = 0; i < token.length(); i++) {
    EEPROM.write(EEPROM_TOKEN_ADDRESS + i, token.charAt(i));
  }
  EEPROM.write(EEPROM_TOKEN_ADDRESS + token.length(), '\0');
  
  if (EEPROM.commit()) {
    Serial.println("Token saved to EEPROM successfully");
  } else {
    Serial.println("Failed to save token to EEPROM");
  }
}

void clearTokenFromEEPROM() {
  for (int i = 0; i < EEPROM_TOKEN_MAX_LEN; i++) {
    EEPROM.write(EEPROM_TOKEN_ADDRESS + i, 0);
  }
  EEPROM.commit();
  Serial.println("Token cleared from EEPROM");
}

// Fetch token dynamically from backend (if device is already registered)
bool fetchTokenFromBackend() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, cannot fetch token");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();
  
  HTTPClient http;
  http.setTimeout(10000);
  
  String url = "https://" + String(BACKEND_SERVER_HOST) + ":" + String(BACKEND_SERVER_PORT) + "/saarthi/api/device/getToken.php";
  url += "?device_id=" + String(DEVICE_ID);

  if (DEBUG_HTTP) Serial.printf("Fetching token from: %s\n", url.c_str());
  
  http.begin(client, url);
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    if (DEBUG_HTTP) Serial.printf("Token fetch response: %d\n", httpResponseCode);
    String response = http.getString();
    if (DEBUG_HTTP) Serial.println("Response: " + response);
    
    if (response.indexOf("\"success\":true") > 0) {
      // Parse token from response (handle both direct and nested in data)
      String token = "";
      
      // Try nested format first: "data":{"device_token":"..."}
      int dataStart = response.indexOf("\"data\":{");
      if (dataStart > 0) {
        int tokenStart = response.indexOf("\"device_token\":\"", dataStart);
        if (tokenStart > 0) {
          tokenStart += 16; // Length of "device_token":"
          int tokenEnd = response.indexOf("\"", tokenStart);
          if (tokenEnd > tokenStart) {
            token = response.substring(tokenStart, tokenEnd);
          }
        }
      } else {
        // Try direct format: "device_token":"..."
        int tokenStart = response.indexOf("\"device_token\":\"");
        if (tokenStart > 0) {
          tokenStart += 16; // Length of "device_token":"
          int tokenEnd = response.indexOf("\"", tokenStart);
          if (tokenEnd > tokenStart) {
            token = response.substring(tokenStart, tokenEnd);
          }
        }
      }
      
      if (token.length() > 0) {
        deviceToken = token;
        saveTokenToEEPROM(deviceToken);
        Serial.println("✓ Token fetched and saved to EEPROM");
        Serial.printf("Token length: %d\n", deviceToken.length());
        http.end();
        return true;
      } else {
        Serial.println("✗ Token not found in response");
      }
    } else {
      // Parse error message for better debugging
      int msgStart = response.indexOf("\"message\":\"");
      if (msgStart > 0) {
        msgStart += 11;
        int msgEnd = response.indexOf("\"", msgStart);
        if (msgEnd > msgStart) {
          String errorMsg = response.substring(msgStart, msgEnd);
          Serial.println("✗ Token fetch failed: " + errorMsg);
        } else {
          Serial.println("✗ Token fetch failed: " + response);
        }
      } else {
        Serial.println("✗ Token fetch failed: " + response);
      }
    }
  } else {
    if (DEBUG_HTTP) Serial.printf("HTTP Error: %s\n", http.errorToString(httpResponseCode).c_str());
  }
  
  http.end();
  return false;
}

// Fetch complete user configuration from backend
bool fetchUserConfiguration() {
  if (WiFi.status() != WL_CONNECTED || deviceToken.length() == 0) {
    Serial.println("Cannot fetch user config: WiFi not connected or token missing");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();
  
  HTTPClient http;
  http.setTimeout(15000);
  
  String url = "https://" + String(BACKEND_SERVER_HOST) + ":" + String(BACKEND_SERVER_PORT) + "/saarthi/api/device/getUserConfig.php";
  url += "?device_id=" + String(DEVICE_ID);
  url += "&device_token=" + deviceToken;

  if (DEBUG_HTTP) Serial.printf("Fetching user configuration from: %s\n", url.c_str());
  
  http.begin(client, url);
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    if (DEBUG_HTTP) Serial.printf("User config response: %d\n", httpResponseCode);
    String response = http.getString();
    if (DEBUG_HTTP) Serial.println("Response: " + response);
    
    if (response.indexOf("\"success\":true") > 0) {
      // Parse user info
      int userIdStart = response.indexOf("\"user\":{");
      if (userIdStart > 0) {
        // Parse user ID
        int idStart = response.indexOf("\"id\":", userIdStart);
        if (idStart > 0) {
          int idEnd = response.indexOf(",", idStart);
          if (idEnd == -1) idEnd = response.indexOf("}", idStart);
          if (idEnd > idStart) {
            String userIdStr = response.substring(idStart + 5, idEnd);
            // Remove any quotes or whitespace
            userIdStr.trim();
            userIdStr.replace("\"", "");
            userIdStr.replace("'", "");
            userConfig.userId = userIdStr;
            currentUserId = userConfig.userId;
          }
        }
        
        // Parse user name
        int nameStart = response.indexOf("\"name\":\"", userIdStart);
        if (nameStart > 0) {
          nameStart += 8;
          int nameEnd = response.indexOf("\"", nameStart);
          if (nameEnd > nameStart) {
            userConfig.userName = response.substring(nameStart, nameEnd);
          }
        }
        
        // Parse user phone
        int phoneStart = response.indexOf("\"phone\":\"", userIdStart);
        if (phoneStart > 0) {
          phoneStart += 9;
          int phoneEnd = response.indexOf("\"", phoneStart);
          if (phoneEnd > phoneStart) {
            userConfig.userPhone = response.substring(phoneStart, phoneEnd);
          }
        }
        
        // Parse user email
        int emailStart = response.indexOf("\"email\":\"", userIdStart);
        if (emailStart > 0) {
          emailStart += 9;
          int emailEnd = response.indexOf("\"", emailStart);
          if (emailEnd > emailStart) {
            userConfig.userEmail = response.substring(emailStart, emailEnd);
          }
        }
        
        // Parse language preference
        int langStart = response.indexOf("\"language_preference\":\"", userIdStart);
        if (langStart > 0) {
          langStart += 24;
          int langEnd = response.indexOf("\"", langStart);
          if (langEnd > langStart) {
            userConfig.languagePreference = response.substring(langStart, langEnd);
          }
        }
        
        // Parse disability type
        int disabilityStart = response.indexOf("\"disability_type\":\"", userIdStart);
        if (disabilityStart > 0) {
          disabilityStart += 20;
          int disabilityEnd = response.indexOf("\"", disabilityStart);
          if (disabilityEnd > disabilityStart) {
            userConfig.disabilityType = response.substring(disabilityStart, disabilityEnd);
          }
        }
      }
      
      // Parse thresholds
      int thresholdsStart = response.indexOf("\"thresholds\":{");
      if (thresholdsStart > 0) {
        // Ultrasonic threshold
        int ultrasonicStart = response.indexOf("\"ultrasonic_min_distance\":", thresholdsStart);
        if (ultrasonicStart > 0) {
          int ultrasonicEnd = response.indexOf(",", ultrasonicStart);
          if (ultrasonicEnd > ultrasonicStart) {
            String distStr = response.substring(ultrasonicStart + 26, ultrasonicEnd);
            userConfig.ultrasonicThreshold = distStr.toFloat();
            ULTRASONIC_THRESHOLD = userConfig.ultrasonicThreshold;
          }
        }
        
        // Mic threshold
        int micStart = response.indexOf("\"mic_loud_threshold\":", thresholdsStart);
        if (micStart > 0) {
          int micEnd = response.indexOf(",", micStart);
          if (micEnd > micStart) {
            String micStr = response.substring(micStart + 21, micEnd);
            userConfig.micThreshold = micStr.toInt();
            MIC_THRESHOLD = userConfig.micThreshold;
          }
        }
        
        // Night mode
        int nightModeStart = response.indexOf("\"night_mode_enabled\":", thresholdsStart);
        if (nightModeStart > 0) {
          int nightModeEnd = response.indexOf(",", nightModeStart);
          if (nightModeEnd > nightModeStart) {
            String nightModeStr = response.substring(nightModeStart + 21, nightModeEnd);
            userConfig.nightModeEnabled = (nightModeStr == "true" || nightModeStr == "1");
          }
        }
        
        // Continuous tracking
        int trackingStart = response.indexOf("\"continuous_tracking_enabled\":", thresholdsStart);
        if (trackingStart > 0) {
          int trackingEnd = response.indexOf(",", trackingStart);
          if (trackingEnd > trackingStart) {
            String trackingStr = response.substring(trackingStart + 31, trackingEnd);
            userConfig.continuousTracking = (trackingStr == "true" || trackingStr == "1");
          }
        }
      }
      
      // Parse emergency contacts
      int contactsStart = response.indexOf("\"emergency_contacts\":[");
      if (contactsStart > 0) {
        userConfig.emergencyContactCount = 0;
        int contactIndex = 0;
        int searchPos = contactsStart;
        
        while (contactIndex < 5) {
          int phoneStart = response.indexOf("\"phone\":\"", searchPos);
          if (phoneStart > 0 && phoneStart < response.indexOf("]", contactsStart)) {
            phoneStart += 9;
            int phoneEnd = response.indexOf("\"", phoneStart);
            if (phoneEnd > phoneStart) {
              userConfig.emergencyContacts[contactIndex] = response.substring(phoneStart, phoneEnd);
              contactIndex++;
              userConfig.emergencyContactCount = contactIndex;
              searchPos = phoneEnd;
            } else {
              break;
            }
          } else {
            break;
          }
        }
      }
      
      Serial.println("\n=== User Configuration Loaded ===");
      Serial.println("User ID: " + userConfig.userId);
      Serial.println("User Name: " + userConfig.userName);
      Serial.println("User Phone: " + userConfig.userPhone);
      Serial.println("Language: " + userConfig.languagePreference);
      Serial.println("Disability Type: " + userConfig.disabilityType);
      Serial.println("Ultrasonic Threshold: " + String(userConfig.ultrasonicThreshold) + " cm");
      Serial.println("Mic Threshold: " + String(userConfig.micThreshold));
      Serial.println("Emergency Contacts: " + String(userConfig.emergencyContactCount));
      Serial.println("==================================\n");
      
      http.end();
      return true;
    } else {
      Serial.println("✗ Failed to fetch user configuration");
    }
  } else {
    if (DEBUG_HTTP) Serial.printf("HTTP Error: %s\n", http.errorToString(httpResponseCode).c_str());
  }
  
  http.end();
  return false;
}

bool deviceAuthenticate() {
  if (WiFi.status() != WL_CONNECTED) {
    if (DEBUG_HTTP) Serial.println("WiFi not connected, cannot authenticate device");
    return false;
  }

  // Load token from EEPROM or use initial token
  if (deviceToken.length() == 0) {
    deviceToken = loadTokenFromEEPROM();
  }
  
  // If still no token, try initial token (for first-time setup)
  if (deviceToken.length() == 0 && strlen(INITIAL_DEVICE_TOKEN) > 0) {
    deviceToken = String(INITIAL_DEVICE_TOKEN);
    Serial.println("Using initial token for first-time setup");
  }
  
  // Check if device token is available
  if (deviceToken.length() == 0) {
    Serial.println("⚠️ WARNING: Device token not found!");
    Serial.println("Please generate token from app (Settings > Device Pairing)");
    Serial.println("Then update INITIAL_DEVICE_TOKEN in firmware and upload once.");
    Serial.println("Token will be saved to EEPROM automatically.");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();
  
  HTTPClient http;
  http.setTimeout(10000);
  
  // Use POST for security
  String url = "https://" + String(BACKEND_SERVER_HOST) + ":" + String(BACKEND_SERVER_PORT) + "/saarthi/api/device/authenticate.php";
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  
  // URL encode the parameters
  String postData = "device_id=";
  postData += String(DEVICE_ID);
  postData += "&device_token=";
  postData += deviceToken;

  if (DEBUG_HTTP) {
    Serial.printf("Device authentication to: %s\n", url.c_str());
    Serial.printf("POST data: device_id=%s&device_token=%s\n", String(DEVICE_ID).c_str(), deviceToken.c_str());
  }
  
  int httpResponseCode = http.POST(postData);
  
  if (httpResponseCode > 0) {
    if (DEBUG_HTTP) Serial.printf("Device login response: %d\n", httpResponseCode);
    String response = http.getString();
    if (DEBUG_HTTP) {
      Serial.println("Response: " + response);
      Serial.printf("Device ID sent: %s\n", String(DEVICE_ID).c_str());
      Serial.printf("Token length: %d\n", deviceToken.length());
    }
    
    if (response.indexOf("\"success\":true") > 0) {
      // Parse user_id from response
      int userIdStart = response.indexOf("\"user_id\":");
      if (userIdStart > 0) {
        int userIdEnd = response.indexOf(",", userIdStart);
        if (userIdEnd == -1) userIdEnd = response.indexOf("}", userIdStart);
        if (userIdEnd > userIdStart) {
          String userIdStr = response.substring(userIdStart + 10, userIdEnd);
          // Remove any quotes or whitespace
          userIdStr.trim();
          userIdStr.replace("\"", "");
          userIdStr.replace("'", "");
          currentUserId = userIdStr;
          Serial.println("✓ Device authenticated successfully! User ID: " + currentUserId);
        }
      }
      
      // Parse and update thresholds
      int thresholdStart = response.indexOf("\"thresholds\":");
      if (thresholdStart > 0) {
        int ultrasonicStart = response.indexOf("\"ultrasonic_min_distance\":", thresholdStart);
        int micStart = response.indexOf("\"mic_loud_threshold\":", thresholdStart);
        
        if (ultrasonicStart > 0) {
          int ultrasonicEnd = response.indexOf(",", ultrasonicStart);
          if (ultrasonicEnd > ultrasonicStart) {
            String distStr = response.substring(ultrasonicStart + 26, ultrasonicEnd);
            ULTRASONIC_THRESHOLD = distStr.toFloat();
            userConfig.ultrasonicThreshold = ULTRASONIC_THRESHOLD;
            Serial.println("Updated ultrasonic threshold: " + String(ULTRASONIC_THRESHOLD));
          }
        }
        
        if (micStart > 0) {
          int micEnd = response.indexOf("}", micStart);
          if (micEnd > micStart) {
            String micStr = response.substring(micStart + 21, micEnd);
            MIC_THRESHOLD = micStr.toInt();
            userConfig.micThreshold = MIC_THRESHOLD;
            Serial.println("Updated mic threshold: " + String(MIC_THRESHOLD));
          }
        }
      }
      
      // Save token to EEPROM if using initial token (first-time setup)
      if (strlen(INITIAL_DEVICE_TOKEN) > 0 && deviceToken == String(INITIAL_DEVICE_TOKEN)) {
        saveTokenToEEPROM(deviceToken);
        Serial.println("Token saved to EEPROM for future use");
      }
      
      // Fetch complete user configuration
      fetchUserConfiguration();
      
      http.end();
      return true;
    } else {
      Serial.println("✗ Device authentication failed");
      Serial.println("Please check your device token.");
      // If authentication fails, clear invalid token
      if (deviceToken.length() > 0) {
        Serial.println("Clearing invalid token from EEPROM");
        clearTokenFromEEPROM();
        deviceToken = "";
      }
      http.end();
      return false;
    }
  } else {
    if (DEBUG_HTTP) Serial.printf("HTTP Error during authentication: %s\n", http.errorToString(httpResponseCode).c_str());
    http.end();
    return false;
  }
}

// ============================================
// SETUP
// ============================================
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); // Disable brownout detector

  Serial.begin(115200);
  Serial.setTxBufferSize(1024);
  delay(100);

  Serial.println("\n===================================");
  Serial.println("SAARTHI ESP32-CAM Starting...");
  Serial.println("===================================\n");

  // Initialize user configuration
  initUserConfig();

  // Initialize EEPROM for token storage
  initEEPROM();
  
  // Load device token from EEPROM
  deviceToken = loadTokenFromEEPROM();
  if (deviceToken.length() > 0) {
    Serial.println("Device token loaded from EEPROM");
  } else {
    Serial.println("No token found in EEPROM");
    Serial.println("Attempting to fetch token from backend...");
  }

  // Initialize pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(TOUCH_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Configure microphone ADC
  analogReadResolution(12); // 0-4095
  analogSetAttenuation(ADC_11db); // 0-3.3V
  analogSetPinAttenuation(MIC_PIN, ADC_11db);

  // Connect WiFi
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    
    // Step 1: Try to load token from EEPROM first
    deviceToken = loadTokenFromEEPROM();
    
    // Step 2: If no token in EEPROM, try to fetch from backend (if device already registered)
    if (deviceToken.length() == 0) {
      Serial.println("No token in EEPROM. Attempting to fetch from backend...");
      Serial.println("(This happens if token was generated from app)");
      if (fetchTokenFromBackend()) {
        Serial.println("✓ Token fetched successfully from backend and saved to EEPROM");
      } else {
        Serial.println("⚠️ Could not fetch token from backend.");
        Serial.println("This is normal for first-time setup.");
        Serial.println("Please generate token from app (Settings > Device Pairing)");
        Serial.println("Then restart ESP32 - it will fetch token automatically.");
      }
    } else {
      Serial.println("✓ Token loaded from EEPROM");
    }
    
    // Step 3: Authenticate device with backend using token
    Serial.println("Authenticating device with backend...");
    bool authSuccess = false;
    
    // Try authentication up to 3 times
    for (int attempt = 1; attempt <= 3; attempt++) {
      if (deviceAuthenticate()) {
        authSuccess = true;
        Serial.println("✓ Device authenticated successfully!");
        break;
      } else {
        Serial.printf("Authentication attempt %d/3 failed.\n", attempt);
        if (attempt < 3) {
          // If authentication fails, try fetching token again (in case it was just generated)
          if (attempt == 2) {
            Serial.println("Retrying token fetch from backend...");
            if (fetchTokenFromBackend()) {
              Serial.println("✓ Token refreshed from backend");
            }
          }
          delay(3000);
        }
      }
    }
    
    if (!authSuccess) {
      Serial.println("⚠️ Device authentication failed after 3 attempts.");
      Serial.println("Please ensure:");
      Serial.println("1. Token is generated from app (Settings > Device Pairing)");
      Serial.println("2. Device ID matches: " + String(DEVICE_ID));
      Serial.println("3. ESP32 is connected to internet");
      Serial.println("Restarting ESP32 in 10 seconds to retry...");
      delay(10000);
      ESP.restart();
    }
    delay(1000); // Give login time to complete
  } else {
    Serial.println("WiFi connection failed. Restarting...");
    delay(5000);
    ESP.restart();
  }

  // Initialize camera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = 5;
  config.pin_d1 = 18;
  config.pin_d2 = 19;
  config.pin_d3 = 21;
  config.pin_d4 = 22;
  config.pin_d5 = 23;
  config.pin_d6 = 35;
  config.pin_d7 = 34;
  config.pin_xclk = 0;
  config.pin_pclk = 26;
  config.pin_vsync = 25;
  config.pin_href = 23;
  config.pin_sscb_sda = 26;
  config.pin_sscb_scl = 27;
  config.pin_pwdn = 32;
  config.pin_reset = -1;

  if (config.pin_pwdn != -1) {
    pinMode(config.pin_pwdn, OUTPUT);
    digitalWrite(config.pin_pwdn, LOW);
    delay(10);
  }

  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QVGA;
  config.jpeg_quality = 10;
  config.fb_count = 2;

  Serial.println("Initializing camera...");
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    Serial.println("Restarting in 5 seconds...");
    delay(5000);
    ESP.restart();
  } else {
    Serial.println("Camera initialized successfully");
  }

  // Start camera streaming server
  startCameraServer();

  Serial.println("\n=== SAARTHI Ready ===");
  Serial.println("Device ID: " + String(DEVICE_ID));
  Serial.println("Stream: http://" + WiFi.localIP().toString() + ":81/stream");
  Serial.println("====================\n");
}

// ============================================
// MAIN LOOP
// ============================================
void loop() {
  // Handle touch gestures
  handleTouchGesture();

  // Read sensors
  float distance = readUltrasonic();
  int micRaw = readMicrophone();

  // Check for obstacles - Alert for 50-100cm, NO alert for 10-30cm
  // User requirement: Alert when object is far (50-100cm), not when too close (10-30cm)
  if (distance > 0) {
    // Alert for 50-100cm range OR very close (<10cm)
    // NO alert for 10-30cm range
    if ((distance >= 50 && distance <= 100) || distance < 10) {
      triggerObstacleAlert(distance);
    }
    // No alert for 10-30cm range (user requirement)
  }

  // Check for loud sounds
  if (micRaw > MIC_THRESHOLD) {
    triggerLoudSoundAlert(micRaw);
  }

  // Periodically send sensor data
  if (millis() - lastSensorSend >= SENSOR_SEND_INTERVAL) {
    sendSensorDataToBackend(distance, readTouch(), micRaw);
    lastSensorSend = millis();
  }

  // Sync thresholds from backend
  if (millis() - lastThresholdSync >= THRESHOLD_SYNC_INTERVAL) {
    syncThresholdsFromBackend();
    lastThresholdSync = millis();
  }

  // Debug output
  if (DEBUG_SENSORS && millis() % 1000 < 100) {
    Serial.printf("Dist: %.1f cm | Mic: %d\n", distance, micRaw);
  }

  delay(50); // Small delay to prevent watchdog
}

