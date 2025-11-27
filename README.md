<div align="center">

# 🛡️ SAARTHI
### Ultra-Low-Cost IoT Assistive System for India

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![PHP](https://img.shields.io/badge/PHP-8.0+-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![ESP32](https://img.shields.io/badge/ESP32-CAM-FF6F00?logo=arduino&logoColor=white)](https://www.espressif.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Cost](https://img.shields.io/badge/Cost-Under%20₹3000-success)]()

**Built for India. Built for Accessibility. Built for Safety.** 🇮🇳

[Features](#-features) • [Installation](#-installation) • [Architecture](#-architecture) • [Documentation](#-documentation) • [Contributing](#-contributing)

---

</div>

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [System Architecture](#-system-architecture)
- [Installation](#-installation)
- [Hardware Setup](#-hardware-setup)
- [API Documentation](#-api-documentation)
- [Usage Guide](#-usage-guide)
- [Cost Breakdown](#-cost-breakdown)
- [Security](#-security)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

---

## 🎯 Overview

**SAARTHI** is a comprehensive IoT assistive system designed specifically for India, providing affordable and reliable support for:

- 👁️ **Visually impaired** users (blind/low vision)
- 👂 **Deaf/hard-of-hearing** users
- 🗣️ **Speech impaired** users
- 👩 **Women safety** and general vulnerable users

### Key Highlights

- 💰 **Ultra-low cost**: Complete system under **₹3000**
- 🌐 **Low-bandwidth optimized**: Works reliably in Indian network conditions
- 🌍 **Multilingual support**: English + Hindi (expandable)
- 🔒 **Privacy-focused**: Secure data handling and user privacy
- 📱 **Cross-platform**: Android & iOS support
- ⚡ **Real-time**: Live tracking, streaming, and alerts

---

## ✨ Features

### 🎯 Core Features

| Feature | Description |
|---------|-------------|
| 📹 **Live Camera Streaming** | ESP32-CAM MJPEG stream accessible via mobile app |
| 🚧 **Obstacle Detection** | Ultrasonic sensor with real-time audio TTS alerts |
| 🆘 **SOS Emergency** | Touch sensor gestures + app-based emergency button |
| 🔊 **Sound Alerts** | Microphone-based loud sound detection |
| 📍 **GPS Tracking** | Real-time location updates with movement trail |
| 🗺️ **Geofencing** | Safe zones with enter/exit alerts |
| 🚗 **Trip Mode** | Time-based trip monitoring with delay alerts |
| 👨‍👩‍👧 **Parent Dashboard** | Full parental control and monitoring |
| 🌐 **Multilingual UI** | English + Hindi support (expandable) |
| 📲 **WhatsApp Alerts** | Instant emergency notifications via WhatsApp |

### 🛡️ Safety Features by User Type

#### 👁️ For Visually Impaired Users
- ✅ Ultrasonic obstacle detection with audio TTS feedback
- ✅ Haptic feedback patterns (vibration alerts)
- ✅ Object classification (CAR, STAIRS, PERSON, etc.)
- ✅ Voice prompts for navigation assistance
- ✅ High-contrast UI with large text support

#### 👂 For Deaf/Hard-of-Hearing Users
- ✅ Loud sound detection → vibration + visual alerts
- ✅ Large, high-contrast UI elements
- ✅ Icon-based sound type representation
- ✅ Visual emergency indicators
- ✅ Text-based communication support

#### 🗣️ For Speech Impaired Users
- ✅ Quick message buttons ("I need help", "Call guardian")
- ✅ Text-to-speech for selected phrases
- ✅ Manual SOS button in app
- ✅ Pre-configured emergency messages
- ✅ Contact-based quick actions

#### 👩 For Women Safety
- ✅ Discreet SOS (touch pattern or hidden button)
- ✅ Continuous tracking during trips
- ✅ Geofence breach alerts
- ✅ Night mode with stricter alert thresholds
- ✅ Emergency contact auto-dialing

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.10+
- **State Management**: Provider
- **Localization**: Flutter Intl (English, Hindi)
- **Maps**: Google Maps Flutter
- **Location**: Geolocator
- **Camera**: Camera Plugin
- **TTS/STT**: Flutter TTS, Speech to Text

### Backend
- **Language**: PHP 8.0+
- **Database**: MySQL 8.0+
- **Authentication**: Token-based JWT
- **API**: RESTful API
- **Services**: WhatsApp API integration

### Hardware
- **Microcontroller**: ESP32-CAM
- **Sensors**: 
  - HC-SR04 Ultrasonic Sensor
  - Touch Sensor
  - MAX9814 Microphone
  - LED Indicator
- **Firmware**: Arduino IDE

### Infrastructure
- **Web Server**: Apache/Nginx
- **SSL**: HTTPS (required for production)
- **Storage**: Local file system for images/audio

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SAARTHI System Architecture              │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  ESP32-CAM   │  HTTPS  │  PHP Backend │  HTTPS  │ Flutter App  │
│  + Sensors   │────────▶│  + MySQL     │────────▶│ (User/Parent)│
│              │         │  + Services  │         │              │
│ • Ultrasonic │         │              │         │ • Multilingual│
│ • Touch      │         │ • REST API   │         │ • Role-based │
│ • Microphone │         │ • WhatsApp   │         │ • Real-time  │
│ • Camera     │         │ • Geofencing │         │ • Maps       │
└──────────────┘         └──────────────┘         └──────────────┘
     Hardware                Server                  Mobile App
```

### Data Flow

1. **Sensor Data Flow**
   ```
   ESP32-CAM → Sensor Reading → Threshold Check → Image Capture
            → POST /api/device/postSensorData.php
            → Backend Storage → WhatsApp Alert (if critical)
            → Parent Notification
   ```

2. **Location Tracking Flow**
   ```
   Flutter App → GPS Coordinates → POST /api/location/update.php
              → Backend Storage → Geofence Check
              → Alert if Breach → Parent Dashboard Update
   ```

3. **Emergency SOS Flow**
   ```
   User Action (Touch/Button) → ESP32 Image Capture
                             → SOS Event → Backend (CRITICAL)
                             → WhatsApp to All Parents
                             → Live Location + Stream Link
   ```

---

## 🚀 Installation

### Prerequisites

- **Flutter SDK**: 3.10.1 or higher
- **PHP**: 8.0 or higher
- **MySQL**: 8.0 or higher
- **Arduino IDE**: Latest version
- **ESP32 Board Support**: Installed in Arduino IDE
- **Web Server**: Apache/Nginx with PHP support
- **SSL Certificate**: For HTTPS (production)

### 1️⃣ Database Setup

```bash
# Import MySQL schema
mysql -u root -p < database/saarthi_schema.sql
```

Update database credentials in `backend/config/database.php`:

```php
private $host = "localhost";
private $db_name = "saarthi_db";
private $username = "your_username";
private $password = "your_password";
```

### 2️⃣ Backend Setup

1. **Upload backend files** to your web server:
   ```bash
   # Upload backend/ directory to your server
   scp -r backend/ user@your-server.com:/var/www/html/saarthi/
   ```

2. **Set directory permissions**:
   ```bash
   chmod 755 backend/uploads/images/
   chmod 755 backend/uploads/audio/
   ```

3. **Configure WhatsApp API** in `backend/config/config.php`:
   ```php
   define('WHATSAPP_API_KEY', 'your_api_key');
   define('WHATSAPP_INSTANCE_ID', 'your_instance_id');
   define('WHATSAPP_API_URL', 'https://api.callmebot.com/whatsapp.php');
   ```

4. **Update CORS settings** if needed for cross-origin requests

### 3️⃣ ESP32-CAM Firmware Setup

1. **Install Arduino IDE** and ESP32 board support:
   - File → Preferences → Additional Board URLs
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Tools → Board → Boards Manager → Install "ESP32"

2. **Install required libraries**:
   - ESP32 Camera (via Library Manager)
   - WiFi (built-in)
   - HTTPClient (built-in)

3. **Configure firmware** in `firmware/saarthi_esp32cam.ino`:
   ```cpp
   const char* WIFI_SSID = "YourWiFi";
   const char* WIFI_PASSWORD = "YourPassword";
   const char* BACKEND_SERVER_HOST = "yourdomain.com";
   const char* DEVICE_ID = "ESP32_CAM_001";
   ```

4. **Upload to ESP32-CAM**:
   - Connect ESP32-CAM via USB
   - Select board: "ESP32 Wrover Module"
   - Select port
   - Upload

### 4️⃣ Flutter App Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/saarthi.git
cd saarthi

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run on connected device
flutter run

# Build APK for Android
flutter build apk --release

# Build iOS (macOS required)
flutter build ios --release
```

**Update API base URL** in `lib/core/constants.dart`:

```dart
static const String baseUrl = 'https://yourdomain.com/saarthi';
```

---

## 🔌 Hardware Setup

### Component Connections

| Component | ESP32-CAM Pin | Notes |
|-----------|---------------|-------|
| Ultrasonic TRIG | GPIO 13 | Trigger pin |
| Ultrasonic ECHO | GPIO 12 | Echo pin |
| Touch Sensor | GPIO 15 | Digital input |
| Microphone (ADC) | GPIO 14 | Analog input |
| LED Indicator | GPIO 4 | Status LED |

### Power Requirements

- **ESP32-CAM**: 5V, 2A minimum (for stable camera operation)
- **Sensors**: 3.3V or 5V (check sensor specifications)
- **Recommended**: Use a dedicated 5V 2A power supply

### Wiring Diagram

```
ESP32-CAM
├── VCC (5V) → Power Supply
├── GND → Common Ground
├── GPIO 13 → Ultrasonic TRIG
├── GPIO 12 → Ultrasonic ECHO
├── GPIO 15 → Touch Sensor
├── GPIO 14 → Microphone (ADC)
└── GPIO 4 → LED (with 220Ω resistor)
```

---

## 📡 API Documentation

### Authentication

#### Login
```http
POST /api/auth/login.php
Content-Type: application/json

{
  "phone": "+919876543210",
  "password": "userpassword"
}
```

#### Register
```http
POST /api/auth/register.php
Content-Type: application/json

{
  "name": "User Name",
  "email": "user@example.com",
  "phone": "+919876543210",
  "password": "securepassword",
  "role": "USER",
  "disability_type": "VISUAL"
}
```

### Device APIs

#### Post Sensor Data
```http
POST /api/device/postSensorData.php
Authorization: Bearer {token}
Content-Type: application/json

{
  "device_id": "ESP32_CAM_001",
  "event_type": "OBSTACLE_DETECTED",
  "severity": "MEDIUM",
  "sensor_payload": {
    "distance_cm": 25,
    "object_label": "CAR"
  }
}
```

#### Upload Snapshot
```http
POST /api/device/uploadSnapshot.php
Authorization: Bearer {token}
Content-Type: multipart/form-data

{
  "device_id": "ESP32_CAM_001",
  "image": [binary data]
}
```

### Location APIs

#### Update Location
```http
POST /api/location/update.php
Authorization: Bearer {token}
Content-Type: application/json

{
  "latitude": 28.6139,
  "longitude": 77.2090,
  "accuracy": 10.5,
  "speed": 5.2,
  "battery_level": 85
}
```

### Parent Dashboard APIs

#### Get Child Dashboard Data
```http
GET /api/parent/childDashboardData.php?child_id=123
Authorization: Bearer {token}
```

#### Create Safe Zone
```http
POST /api/parent/createSafeZone.php
Authorization: Bearer {token}
Content-Type: application/json

{
  "child_id": 123,
  "name": "Home",
  "center_lat": 28.6139,
  "center_lon": 77.2090,
  "radius_meters": 100,
  "is_restricted": false
}
```

#### Create Trip
```http
POST /api/parent/createTrip.php
Authorization: Bearer {token}
Content-Type: application/json

{
  "child_id": 123,
  "destination_name": "School",
  "destination_lat": 28.6139,
  "destination_lon": 77.2090,
  "expected_end_time": "2024-01-15 14:00:00"
}
```

For complete API documentation, see individual PHP files in `backend/api/`.

---

## 📖 Usage Guide

### For Users (End Users)

1. **Registration & Setup**
   - Register with phone number and email
   - Select your disability type (if applicable)
   - Choose language preference (English/Hindi)
   - Pair your ESP32-CAM device using device token

2. **Daily Usage**
   - Enable live location sharing
   - Use navigation assist for obstacle alerts
   - Access quick messages for communication
   - Use SOS button for emergencies

3. **Emergency Features**
   - Long press touch sensor on device for SOS
   - Or use SOS button in mobile app
   - Emergency contacts will be notified via WhatsApp

### For Parents/Guardians

1. **Account Setup**
   - Register as PARENT role
   - Link child accounts via phone number
   - Configure emergency contacts

2. **Monitoring Dashboard**
   - View live location on map
   - Monitor camera stream
   - Check recent events and alerts
   - View sensor data history

3. **Safety Features**
   - Create safe zones (home, school, etc.)
   - Set up trips with expected arrival times
   - Configure alert thresholds
   - Receive WhatsApp notifications on critical events

---

## 💰 Cost Breakdown

| Component | Price Range (₹) | Notes |
|-----------|----------------|-------|
| ESP32-CAM Module | 400 - 600 | Main microcontroller + camera |
| HC-SR04 Ultrasonic Sensor | 50 - 100 | Obstacle detection |
| Touch Sensor | 20 - 50 | SOS trigger |
| MAX9814 Microphone | 50 - 100 | Sound detection |
| LED/Buzzer | 20 - 50 | Visual/audio feedback |
| Wires & Connectors | 50 - 100 | Wiring components |
| Power Supply (5V 2A) | 100 - 200 | Dedicated power adapter |
| **Total Hardware Cost** | **₹690 - ₹1,200** | Well under ₹3000 target |

### Additional Costs (Optional)
- 3D Printed Enclosure: ₹200 - ₹500
- Battery Pack (Portable): ₹300 - ₹600
- **Grand Total**: ₹1,190 - ₹2,300

---

## 🔒 Security

### Implemented Security Measures

- ✅ **HTTPS**: All API communications encrypted
- ✅ **Token-based Authentication**: JWT tokens for API access
- ✅ **Password Hashing**: bcrypt with salt
- ✅ **SQL Injection Prevention**: PDO prepared statements
- ✅ **Input Validation**: Server-side validation for all inputs
- ✅ **CORS Configuration**: Controlled cross-origin access
- ✅ **Rate Limiting**: API rate limiting (recommended for production)

### Security Best Practices

1. **Change default credentials** immediately after installation
2. **Use strong passwords** for database and admin accounts
3. **Enable HTTPS** in production (SSL certificate required)
4. **Rotate API keys** regularly
5. **Implement rate limiting** on API endpoints
6. **Regular security updates** for PHP, MySQL, and dependencies
7. **Monitor access logs** for suspicious activity

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes** and test thoroughly
4. **Commit your changes**:
   ```bash
   git commit -m 'Add some amazing feature'
   ```
5. **Push to the branch**:
   ```bash
   git push origin feature/amazing-feature
   ```
6. **Open a Pull Request**

### Contribution Guidelines

- Follow existing code style and conventions
- Add comments for complex logic
- Update documentation for new features
- Write tests for new functionality
- Ensure backward compatibility

### Areas for Contribution

- 🌍 **Localization**: Add support for more Indian languages (Marathi, Tamil, Telugu, etc.)
- 🎨 **UI/UX**: Improve accessibility and user experience
- 🤖 **AI Features**: Object detection, voice commands
- 📱 **iOS Support**: Enhance iOS compatibility
- 🧪 **Testing**: Add unit and integration tests
- 📚 **Documentation**: Improve docs and add tutorials

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Note**: This project is designed for educational and assistive technology purposes. Please use responsibly and respect user privacy.

---

## 📞 Support

### Documentation

- 📘 [Architecture Documentation](ARCHITECTURE.md) - Detailed system architecture
- 🗄️ [Database Schema](database/saarthi_schema.sql) - Complete database structure
- 🔧 [API Documentation](#-api-documentation) - REST API endpoints

### Troubleshooting

#### ESP32-CAM Issues
- **Camera not initializing**: Check power supply (needs 5V, 2A minimum)
- **WiFi connection fails**: Verify SSID/password in firmware
- **Stream not accessible**: Check firewall, ensure port 81 is open

#### Backend Issues
- **Database connection error**: Verify credentials in `database.php`
- **WhatsApp not sending**: Check API key and phone number format
- **Upload fails**: Check directory permissions (755 for uploads/)

#### Flutter App Issues
- **Localization not working**: Run `flutter gen-l10n`
- **API errors**: Verify base URL in `constants.dart` and network connectivity
- **Location not updating**: Check GPS permissions in device settings

### Get Help

- 🐛 **Report Issues**: [GitHub Issues](https://github.com/yourusername/saarthi/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/yourusername/saarthi/discussions)
- 📧 **Email**: support@saarthi.in (if applicable)

---

## 🌟 Acknowledgments

- Built with ❤️ for the accessibility community in India
- Inspired by the need for affordable assistive technology
- Thanks to all contributors and testers

---

<div align="center">

### ⭐ Star this repo if you find it helpful!

**Made with ❤️ for India 🇮🇳**

[⬆ Back to Top](#-saarthi)

</div>
