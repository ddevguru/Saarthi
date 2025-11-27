<?php
/**
 * SAARTHI Backend - Generate Device Token API
 * POST /api/device/generateToken.php
 * Generates a secure token for ESP32 device authentication
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
validateRequired($data, ['device_id']);

$deviceId = trim($data['device_id']);
$userId = $user['user_id'];

// Generate secure random token
$deviceToken = bin2hex(random_bytes(32)); // 64 character hex string

// Check if device exists
$stmt = $db->prepare("SELECT id FROM devices WHERE device_id = ?");
$stmt->execute([$deviceId]);
$existing = $stmt->fetch();

if ($existing) {
    // Update device with token
    $stmt = $db->prepare("
        UPDATE devices 
        SET user_id = ?, device_token = ?, token_generated_at = NOW()
        WHERE id = ?
    ");
    $stmt->execute([$userId, $deviceToken, $existing['id']]);
} else {
    // Create new device with token
    $stmt = $db->prepare("
        INSERT INTO devices (user_id, device_id, device_name, device_token, token_generated_at, status, last_seen)
        VALUES (?, ?, 'ESP32-CAM', ?, NOW(), 'ONLINE', NOW())
    ");
    $stmt->execute([$userId, $deviceId, $deviceToken]);
    
    $deviceDbId = $db->lastInsertId();
    
    // Create default thresholds
    $stmt = $db->prepare("
        INSERT INTO sensor_thresholds (user_id, device_id, ultrasonic_min_distance, mic_loud_threshold)
        VALUES (?, ?, 30.0, 2000)
    ");
    $stmt->execute([$userId, $deviceDbId]);
}

// Return response using standard sendResponse function
sendResponse(true, "Device token generated successfully", [
    'device_id' => $deviceId,
    'device_token' => $deviceToken,
    'expires_in' => 31536000, // 1 year in seconds
    'token_generated_at' => date('Y-m-d H:i:s')
], 200);

