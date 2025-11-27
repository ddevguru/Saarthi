<?php
/**
 * SAARTHI Backend - Device Login API (for ESP32)
 * POST /api/device/login.php
 * Allows ESP32 to login and get user_id dynamically
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Accept both GET (for ESP32 simplicity) and POST
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $data = $_GET;
} else {
    $data = getRequestBody();
}

// Required: device_id, email (or phone), password
validateRequired($data, ['device_id', 'email', 'password']);

$deviceId = trim($data['device_id']);
$email = trim($data['email']);
$password = $data['password'];

// Find user
$stmt = $db->prepare("
    SELECT id, name, email, phone, password_hash, role, is_active
    FROM users
    WHERE email = ? OR phone = ?
");
$stmt->execute([$email, $email]);
$user = $stmt->fetch();

if (!$user) {
    sendResponse(false, "Invalid credentials", null, 401);
}

if (!$user['is_active']) {
    sendResponse(false, "Account is inactive", null, 403);
}

// Verify password
if (!password_verify($password, $user['password_hash'])) {
    sendResponse(false, "Invalid credentials", null, 401);
}

$userId = $user['id'];

// Register or update device
$stmt = $db->prepare("SELECT id, user_id FROM devices WHERE device_id = ?");
$stmt->execute([$deviceId]);
$existing = $stmt->fetch();

$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;

if ($existing) {
    // Update existing device with new user_id
    $stmt = $db->prepare("
        UPDATE devices 
        SET user_id = ?, ip_address = ?, status = 'ONLINE', last_seen = NOW()
        WHERE id = ?
    ");
    $stmt->execute([$userId, $ipAddress, $existing['id']]);
    $deviceDbId = $existing['id'];
} else {
    // Create new device
    $stmt = $db->prepare("
        INSERT INTO devices (user_id, device_id, device_name, firmware_version, ip_address, status, last_seen)
        VALUES (?, ?, 'ESP32-CAM', '1.0.0', ?, 'ONLINE', NOW())
    ");
    $stmt->execute([$userId, $deviceId, $ipAddress]);
    $deviceDbId = $db->lastInsertId();
    
    // Create default thresholds
    $stmt = $db->prepare("
        INSERT INTO sensor_thresholds (user_id, device_id, ultrasonic_min_distance, mic_loud_threshold)
        VALUES (?, ?, 30.0, 2000)
    ");
    $stmt->execute([$userId, $deviceDbId]);
}

// Get sensor thresholds
$stmt = $db->prepare("
    SELECT ultrasonic_min_distance, mic_loud_threshold
    FROM sensor_thresholds
    WHERE user_id = ? AND (device_id = ? OR device_id IS NULL)
    ORDER BY device_id DESC
    LIMIT 1
");
$stmt->execute([$userId, $deviceDbId]);
$thresholds = $stmt->fetch() ?: [
    'ultrasonic_min_distance' => 30.0,
    'mic_loud_threshold' => 2000
];

sendResponse(true, "Device login successful", [
    'user_id' => $userId,
    'device_id' => $deviceId,
    'device_db_id' => $deviceDbId,
    'user_name' => $user['name'],
    'thresholds' => [
        'ultrasonic_min_distance' => floatval($thresholds['ultrasonic_min_distance']),
        'mic_loud_threshold' => intval($thresholds['mic_loud_threshold'])
    ]
], 200);

