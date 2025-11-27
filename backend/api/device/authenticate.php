<?php
/**
 * SAARTHI Backend - Device Authentication API (for ESP32)
 * POST /api/device/authenticate.php
 * Authenticates ESP32 using device_id and device_token
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Accept both GET (for ESP32 simplicity) and POST
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $data = $_GET;
} else {
    // For POST, try both form data and JSON
    $data = getRequestBody();
    
    // If empty, also check $_POST (for form submissions)
    if (empty($data) && !empty($_POST)) {
        $data = $_POST;
    }
}

// Required: device_id, device_token
validateRequired($data, ['device_id', 'device_token']);

$deviceId = trim($data['device_id']);
$deviceToken = trim($data['device_token']);

// Verify device and token
$stmt = $db->prepare("
    SELECT id, user_id, device_token, token_generated_at, status
    FROM devices
    WHERE device_id = ? AND device_token = ?
");
$stmt->execute([$deviceId, $deviceToken]);
$device = $stmt->fetch();

if (!$device) {
    sendResponse(false, "Invalid device credentials", null, 401);
}

// Check token expiry (optional - tokens don't expire by default, but can be revoked)
// Token is valid for 1 year from generation
$tokenAge = time() - strtotime($device['token_generated_at']);
if ($tokenAge > 31536000) { // 1 year
    sendResponse(false, "Device token expired. Please regenerate token from app.", null, 401);
}

$userId = $device['user_id'];
$deviceDbId = $device['id'];
$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;

// Update device status
$stmt = $db->prepare("
    UPDATE devices 
    SET ip_address = ?, status = 'ONLINE', last_seen = NOW()
    WHERE id = ?
");
$stmt->execute([$ipAddress, $deviceDbId]);

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

// Get user info
$stmt = $db->prepare("SELECT name FROM users WHERE id = ?");
$stmt->execute([$userId]);
$user = $stmt->fetch();

sendResponse(true, "Device authenticated successfully", [
    'user_id' => $userId,
    'device_id' => $deviceId,
    'device_db_id' => $deviceDbId,
    'user_name' => $user['name'] ?? 'User',
    'thresholds' => [
        'ultrasonic_min_distance' => floatval($thresholds['ultrasonic_min_distance']),
        'mic_loud_threshold' => intval($thresholds['mic_loud_threshold'])
    ]
], 200);

