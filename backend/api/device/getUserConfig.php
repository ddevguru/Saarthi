<?php
/**
 * SAARTHI Backend - Get User Configuration API (for ESP32)
 * GET /api/device/getUserConfig.php?device_id=X&device_token=Y
 * Returns all user-specific configuration for ESP32
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Accept both GET and POST
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $data = $_GET;
} else {
    $data = getRequestBody();
}

validateRequired($data, ['device_id', 'device_token']);

$deviceId = trim($data['device_id']);
$deviceToken = trim($data['device_token']);

// Verify device and token
$stmt = $db->prepare("
    SELECT id, user_id, device_token, status
    FROM devices
    WHERE device_id = ? AND device_token = ?
");
$stmt->execute([$deviceId, $deviceToken]);
$device = $stmt->fetch();

if (!$device) {
    sendResponse(false, "Invalid device credentials", null, 401);
}

$userId = $device['user_id'];
$deviceDbId = $device['id'];

// Get user info
$stmt = $db->prepare("
    SELECT id, name, phone, email, role, language_preference, disability_type
    FROM users
    WHERE id = ?
");
$stmt->execute([$userId]);
$user = $stmt->fetch();

// Get sensor thresholds
$stmt = $db->prepare("
    SELECT ultrasonic_min_distance, mic_loud_threshold, night_mode_enabled,
           night_mode_start, night_mode_end, continuous_tracking_enabled,
           manual_sos_enabled
    FROM sensor_thresholds
    WHERE user_id = ? AND (device_id = ? OR device_id IS NULL)
    ORDER BY device_id DESC
    LIMIT 1
");
$stmt->execute([$userId, $deviceDbId]);
$thresholds = $stmt->fetch() ?: [
    'ultrasonic_min_distance' => 30.0,
    'mic_loud_threshold' => 2000,
    'night_mode_enabled' => false,
    'night_mode_start' => '21:00:00',
    'night_mode_end' => '06:00:00',
    'continuous_tracking_enabled' => true,
    'manual_sos_enabled' => true
];

// Get emergency contacts (parent/guardian contacts)
$stmt = $db->prepare("
    SELECT u.id, u.name, u.phone, u.email
    FROM users u
    INNER JOIN parent_child_links pcl ON u.id = pcl.parent_id
    WHERE pcl.child_id = ? AND pcl.status = 'ACTIVE'
    LIMIT 5
");
$stmt->execute([$userId]);
$emergencyContacts = $stmt->fetchAll(PDO::FETCH_ASSOC);

// If no parent links, get user's own phone as emergency contact
if (empty($emergencyContacts)) {
    $emergencyContacts = [[
        'id' => $user['id'],
        'name' => $user['name'],
        'phone' => $user['phone'],
        'email' => $user['email']
    ]];
}

// Get device-specific settings
$stmt = $db->prepare("
    SELECT device_name, firmware_version, ip_address, stream_url, status, last_seen
    FROM devices
    WHERE id = ?
");
$stmt->execute([$deviceDbId]);
$deviceInfo = $stmt->fetch();

// Get latest location (if available)
$stmt = $db->prepare("
    SELECT latitude, longitude, accuracy, speed, created_at
    FROM locations
    WHERE user_id = ?
    ORDER BY created_at DESC
    LIMIT 1
");
$stmt->execute([$userId]);
$latestLocation = $stmt->fetch();

sendResponse(true, "User configuration retrieved", [
    'user' => [
        'id' => $user['id'],
        'name' => $user['name'],
        'phone' => $user['phone'],
        'email' => $user['email'],
        'role' => $user['role'],
        'language_preference' => $user['language_preference'],
        'disability_type' => $user['disability_type']
    ],
    'device' => [
        'id' => $deviceDbId,
        'device_id' => $deviceId,
        'device_name' => $deviceInfo['device_name'],
        'status' => $deviceInfo['status'],
        'ip_address' => $deviceInfo['ip_address'],
        'stream_url' => $deviceInfo['stream_url']
    ],
    'thresholds' => [
        'ultrasonic_min_distance' => floatval($thresholds['ultrasonic_min_distance']),
        'mic_loud_threshold' => intval($thresholds['mic_loud_threshold']),
        'night_mode_enabled' => (bool)$thresholds['night_mode_enabled'],
        'night_mode_start' => $thresholds['night_mode_start'],
        'night_mode_end' => $thresholds['night_mode_end'],
        'continuous_tracking_enabled' => (bool)$thresholds['continuous_tracking_enabled'],
        'manual_sos_enabled' => (bool)$thresholds['manual_sos_enabled']
    ],
    'emergency_contacts' => $emergencyContacts,
    'latest_location' => $latestLocation ? [
        'latitude' => floatval($latestLocation['latitude']),
        'longitude' => floatval($latestLocation['longitude']),
        'accuracy' => floatval($latestLocation['accuracy']),
        'speed' => floatval($latestLocation['speed']),
        'timestamp' => $latestLocation['created_at']
    ] : null
], 200);

