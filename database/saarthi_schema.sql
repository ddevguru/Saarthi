-- ============================================
-- SAARTHI IoT Assistive System - MySQL Database Schema
-- ============================================
-- Ultra-low-cost IoT system for India
-- Supports: Visual impairment, Hearing loss, Speech impairment, Women safety
-- ============================================

-- Drop existing tables if they exist (for fresh install)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS notification_logs;
DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS safe_zones;
DROP TABLE IF EXISTS sensor_events;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS sensor_thresholds;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS parent_child_links;
DROP TABLE IF EXISTS auth_tokens;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('USER', 'PARENT', 'ADMIN') NOT NULL DEFAULT 'USER',
    language_preference VARCHAR(10) DEFAULT 'en' COMMENT 'en, hi, mr, ta, etc.',
    disability_type ENUM('VISUAL', 'HEARING', 'SPEECH', 'MULTIPLE', 'NONE') DEFAULT 'NONE',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- PARENT-CHILD LINKS TABLE
-- ============================================
CREATE TABLE parent_child_links (
    id INT PRIMARY KEY AUTO_INCREMENT,
    parent_id INT NOT NULL,
    child_id INT NOT NULL,
    status ENUM('ACTIVE', 'PENDING', 'BLOCKED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (child_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_link (parent_id, child_id),
    INDEX idx_parent (parent_id),
    INDEX idx_child (child_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- DEVICES TABLE
-- ============================================
CREATE TABLE devices (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    device_id VARCHAR(100) UNIQUE NOT NULL COMMENT 'ESP32-CAM unique identifier',
    device_name VARCHAR(255),
    status ENUM('ONLINE', 'OFFLINE', 'MAINTENANCE') DEFAULT 'OFFLINE',
    last_seen TIMESTAMP NULL,
    firmware_version VARCHAR(50),
    ip_address VARCHAR(45),
    stream_url VARCHAR(500) COMMENT 'MJPEG stream URL',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_device_id (device_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- SENSOR THRESHOLDS TABLE
-- ============================================
CREATE TABLE sensor_thresholds (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    device_id INT,
    ultrasonic_min_distance FLOAT DEFAULT 30.0 COMMENT 'Distance in cm',
    mic_loud_threshold INT DEFAULT 2000 COMMENT 'Raw ADC value (0-4095)',
    night_mode_enabled BOOLEAN DEFAULT FALSE,
    night_mode_start TIME DEFAULT '21:00:00',
    night_mode_end TIME DEFAULT '06:00:00',
    continuous_tracking_enabled BOOLEAN DEFAULT TRUE,
    manual_sos_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    UNIQUE KEY unique_user_device (user_id, device_id),
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- SENSOR EVENTS TABLE
-- ============================================
CREATE TABLE sensor_events (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    device_id INT,
    event_type ENUM(
        'SOS_TOUCH',
        'OBSTACLE_ALERT',
        'LOUD_SOUND_ALERT',
        'MANUAL_SOS',
        'GEOFENCE_BREACH',
        'TRIP_DELAY',
        'TRIP_STARTED',
        'TRIP_COMPLETED',
        'DEVICE_OFFLINE',
        'OTHER'
    ) NOT NULL,
    sensor_payload TEXT COMMENT 'JSON with distance, touch, mic, etc.',
    object_label VARCHAR(100) COMMENT 'AI-detected object: CAR, PERSON, STAIRS, etc.',
    object_confidence FLOAT COMMENT '0.0 to 1.0',
    image_path VARCHAR(500) COMMENT 'Path to snapshot image',
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') DEFAULT 'MEDIUM',
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    INDEX idx_user (user_id),
    INDEX idx_device (device_id),
    INDEX idx_event_type (event_type),
    INDEX idx_created_at (created_at),
    INDEX idx_severity (severity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- LOCATIONS TABLE
-- ============================================
CREATE TABLE locations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    device_id INT,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy FLOAT COMMENT 'GPS accuracy in meters',
    speed FLOAT DEFAULT 0.0 COMMENT 'Speed in m/s',
    altitude FLOAT,
    heading FLOAT COMMENT 'Direction in degrees',
    battery_level INT COMMENT '0-100 if available',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    INDEX idx_user (user_id),
    INDEX idx_device (device_id),
    INDEX idx_created_at (created_at),
    INDEX idx_location (latitude, longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- SAFE ZONES TABLE (Geofencing)
-- ============================================
CREATE TABLE safe_zones (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL COMMENT 'Home, School, Office, etc.',
    center_lat DECIMAL(10, 8) NOT NULL,
    center_lon DECIMAL(11, 8) NOT NULL,
    radius_meters INT NOT NULL DEFAULT 100,
    active_start_time TIME NULL COMMENT 'Optional time window start',
    active_end_time TIME NULL COMMENT 'Optional time window end',
    is_restricted BOOLEAN DEFAULT FALSE COMMENT 'TRUE = alert when entering, FALSE = alert when exiting',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_location (center_lat, center_lon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TRIPS TABLE (Trip Mode)
-- ============================================
CREATE TABLE trips (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    guardian_id INT NOT NULL COMMENT 'Parent who created/approved trip',
    start_time TIMESTAMP NULL,
    expected_end_time TIMESTAMP NULL,
    actual_end_time TIMESTAMP NULL,
    start_location_lat DECIMAL(10, 8),
    start_location_lon DECIMAL(11, 8),
    end_location_lat DECIMAL(10, 8),
    end_location_lon DECIMAL(11, 8),
    destination_name VARCHAR(255),
    status ENUM('PLANNED', 'ACTIVE', 'COMPLETED', 'DELAYED', 'CANCELLED') DEFAULT 'PLANNED',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (guardian_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_guardian (guardian_id),
    INDEX idx_status (status),
    INDEX idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- NOTIFICATION LOGS TABLE
-- ============================================
CREATE TABLE notification_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    event_id INT COMMENT 'Reference to sensor_events.id',
    target_phone VARCHAR(20) NOT NULL,
    channel ENUM('WHATSAPP', 'INAPP', 'SMS_PLACEHOLDER', 'EMAIL') NOT NULL,
    title VARCHAR(255),
    message TEXT NOT NULL,
    status ENUM('PENDING', 'SENT', 'FAILED', 'DELIVERED') DEFAULT 'PENDING',
    response_data TEXT COMMENT 'API response from WhatsApp gateway',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (event_id) REFERENCES sensor_events(id) ON DELETE SET NULL,
    INDEX idx_user (user_id),
    INDEX idx_event (event_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- AUTH TOKENS TABLE (JWT/Refresh tokens)
-- ============================================
CREATE TABLE auth_tokens (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    token VARCHAR(500) NOT NULL,
    token_type ENUM('ACCESS', 'REFRESH') DEFAULT 'ACCESS',
    expires_at TIMESTAMP NOT NULL,
    device_info VARCHAR(255),
    ip_address VARCHAR(45),
    is_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_token (token(255)),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- INSERT DEFAULT ADMIN USER
-- ============================================
-- Password: admin123 (change in production!)
-- Use password_hash = password_hash('admin123', PASSWORD_BCRYPT) in PHP
INSERT INTO users (name, email, phone, password_hash, role, language_preference) VALUES
('System Admin', 'admin@saarthi.in', '+919999999999', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN', 'en');

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- View: Latest location per user
CREATE OR REPLACE VIEW v_user_latest_location AS
SELECT 
    l.user_id,
    u.name,
    l.latitude,
    l.longitude,
    l.accuracy,
    l.speed,
    l.battery_level,
    l.created_at as last_update
FROM locations l
INNER JOIN users u ON l.user_id = u.id
INNER JOIN (
    SELECT user_id, MAX(created_at) as max_time
    FROM locations
    GROUP BY user_id
) latest ON l.user_id = latest.user_id AND l.created_at = latest.max_time;

-- View: Recent critical events for parents
CREATE OR REPLACE VIEW v_parent_critical_events AS
SELECT 
    se.id,
    se.user_id,
    se.device_id,
    se.event_type,
    se.severity,
    se.created_at,
    u.name as user_name,
    u.phone as user_phone,
    d.device_id as device_identifier,
    pcl.parent_id
FROM sensor_events se
INNER JOIN users u ON se.user_id = u.id
LEFT JOIN devices d ON se.device_id = d.id
INNER JOIN parent_child_links pcl ON se.user_id = pcl.child_id
WHERE se.severity IN ('HIGH', 'CRITICAL')
AND se.created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
AND pcl.status = 'ACTIVE';

-- ============================================
-- END OF SCHEMA
-- ============================================

