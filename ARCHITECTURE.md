# SAARTHI: Architecture Documentation

## Overview

SAARTHI is an ultra-low-cost IoT assistive system designed for India, supporting multiple disabilities (visual impairment, hearing loss, speech impairment) and women's safety. The system costs under ₹3000 and works in low-bandwidth conditions.

## System Architecture

```
┌─────────────────┐
│  ESP32-CAM      │  Hardware Node
│  + Sensors      │  - Ultrasonic, Touch, Mic
└────────┬────────┘  - Live MJPEG Stream
         │
         │ HTTPS
         ▼
┌─────────────────┐
│  PHP Backend    │  REST API + MySQL
│  + Services     │  - Auth, Events, Location
└────────┬────────┘  - WhatsApp, Geofencing
         │
         │ HTTPS
         ▼
┌─────────────────┐
│  Flutter App    │  Mobile Application
│  (User/Parent)  │  - Multilingual (EN/HI)
└─────────────────┘  - Role-based UI
```

## Components

### 1. Hardware (ESP32-CAM)

**Components:**
- ESP32-CAM module (main board)
- Ultrasonic sensor (HC-SR04) - GPIO 13/12
- Touch sensor - GPIO 15
- Microphone (MAX9814) - GPIO 14 (ADC)
- LED indicator - GPIO 4

**Features:**
- Live MJPEG video streaming (port 81)
- Continuous sensor monitoring
- Emergency detection (obstacle, sound, touch)
- HTTP communication with backend
- Image capture on alerts

**Firmware Location:** `firmware/saarthi_esp32cam.ino`

### 2. Backend (PHP + MySQL)

**Structure:**
```
backend/
├── config/
│   ├── database.php      # DB connection
│   └── config.php        # App config
├── middleware/
│   └── auth.php          # Token validation
├── api/
│   ├── auth/             # Login, Register
│   ├── device/           # Sensor data, Snapshots
│   ├── location/         # GPS updates
│   └── parent/           # Parent dashboard APIs
└── services/
    ├── whatsapp_service.php
    └── geofence_service.php
```

**Database Schema:** `database/saarthi_schema.sql`

**Key Tables:**
- `users` - User accounts (USER, PARENT, ADMIN)
- `devices` - ESP32-CAM devices
- `sensor_events` - Obstacle, SOS, sound alerts
- `locations` - GPS tracking data
- `safe_zones` - Geofencing zones
- `trips` - Trip mode tracking
- `notification_logs` - WhatsApp alerts

**API Endpoints:**
- `POST /api/auth/login.php`
- `POST /api/auth/register.php`
- `GET /api/device/postSensorData.php`
- `POST /api/device/uploadSnapshot.php`
- `POST /api/location/update.php`
- `GET /api/parent/childDashboardData.php`
- `POST /api/parent/createSafeZone.php`
- `POST /api/parent/createTrip.php`

### 3. Flutter Mobile App

**Structure:**
```
lib/
├── core/
│   ├── constants.dart    # App constants
│   └── app_theme.dart    # UI theme
├── data/
│   ├── models/           # User, Device, Event, Location
│   └── services/         # API client, Auth, Location
├── presentation/
│   ├── screens/
│   │   ├── auth/         # Login, Signup
│   │   ├── user/         # User home, Navigation
│   │   └── parent/       # Parent dashboard
│   └── widgets/          # Reusable components
└── l10n/                 # Localization (EN, HI)
```

**Features:**
- Role-based navigation (User/Parent/Admin)
- Multilingual support (English + Hindi)
- High contrast, accessible UI
- Live location tracking
- Camera stream viewing
- SOS button
- Quick message phrases (TTS)
- Parent dashboard with maps

## Data Flow

### 1. Sensor Data Flow
```
ESP32-CAM → Reads sensors (ultrasonic, touch, mic)
         → Detects threshold breaches
         → Captures image (if alert)
         → POST /api/device/postSensorData.php
         → Backend stores event
         → Triggers WhatsApp alert (if critical)
         → Parent receives notification
```

### 2. Location Tracking Flow
```
Flutter App → Gets GPS coordinates
           → POST /api/location/update.php
           → Backend stores location
           → Checks geofence boundaries
           → Triggers GEOFENCE_BREACH if needed
           → Parent dashboard updates map
```

### 3. Emergency SOS Flow
```
User → Long press touch sensor OR App SOS button
    → ESP32 captures image
    → Sends SOS_TOUCH event to backend
    → Backend marks as CRITICAL
    → WhatsApp sent to all linked parents
    → Live location included in alert
    → Parent can open live stream
```

### 4. Trip Monitoring Flow
```
Parent → Creates trip (destination + expected time)
      → User starts trip
      → Location updates tracked
      → If not reached by expected time → TRIP_DELAY event
      → WhatsApp alert sent
      → Parent can guide via app
```

## Safety Features

### For Visually Impaired:
- Ultrasonic obstacle detection with audio TTS
- Haptic feedback patterns (vibration)
- Object classification (CAR, STAIRS, etc.)
- Voice prompts for navigation

### For Deaf/Hard-of-Hearing:
- Loud sound detection → vibration + visual alerts
- Large high-contrast UI elements
- Icon-based sound type representation

### For Speech Impaired:
- Quick message buttons ("I need help", "Call guardian")
- Text-to-speech for selected phrases
- Manual SOS in app

### For Women Safety:
- Discreet SOS (touch pattern or hidden button)
- Continuous tracking during trips
- Geofence alerts
- Night mode with stricter alerts

## Parental Control Features

1. **Live Location Tracking**
   - Real-time GPS updates
   - Movement trail on map
   - Speed/status indicators

2. **Safe Zones (Geofencing)**
   - Define multiple zones (home, school, office)
   - Alerts on enter/exit
   - Time-based activation

3. **Trip Mode**
   - Set destination and expected arrival
   - Monitor live route
   - Auto-alert on delay
   - Guidance support

4. **Full Control**
   - Toggle continuous tracking
   - Configure sensor thresholds
   - View event history
   - Block/unblock features

## WhatsApp Integration

Uses CallMeBot API or similar gateway:
- Sends alerts on critical events
- Includes user name, event type, time
- Google Maps link with coordinates
- Sent to all linked parent numbers

## Deployment

### Backend:
1. Upload PHP files to web server
2. Import MySQL schema
3. Configure database credentials
4. Set WhatsApp API keys
5. Create upload directories

### ESP32-CAM:
1. Install Arduino IDE + ESP32 board support
2. Open `firmware/saarthi_esp32cam.ino`
3. Update WiFi credentials
4. Update backend URL
5. Upload to ESP32-CAM

### Flutter App:
1. Run `flutter pub get`
2. Update API base URL in `lib/core/constants.dart`
3. Build APK: `flutter build apk`
4. Install on Android device

## Cost Breakdown

- ESP32-CAM: ₹400-600
- Ultrasonic sensor: ₹50-100
- Touch sensor: ₹20-50
- Microphone: ₹50-100
- LED/Buzzer: ₹20-50
- **Total: ₹540-900** (well under ₹3000 target)

## Future Enhancements

- AI object detection (YOLO/MobileNet)
- Indoor navigation (BLE beacons)
- Offline mode with local storage
- Multi-language expansion (Marathi, Tamil)
- Voice commands
- Integration with emergency services

## Security Considerations

- HTTPS for all API calls
- Token-based authentication
- Password hashing (bcrypt)
- Input validation
- SQL injection prevention (PDO prepared statements)
- CORS configuration

## Support

For issues or questions, refer to:
- Database schema: `database/saarthi_schema.sql`
- API documentation: Check individual PHP files
- Flutter app: `lib/` directory structure
- Firmware: `firmware/saarthi_esp32cam.ino`

---

**Built for India. Built for Accessibility. Built for Safety.**

