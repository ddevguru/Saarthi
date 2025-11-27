<?php
/**
 * SAARTHI Backend - Register Device API (for ESP32)
 * POST /api/device/registerDevice.php
 * Allows ESP32 to register device with user_id (no auth required for initial setup)
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

// Required: device_id, user_id
validateRequired($data, ['device_id', 'user_id']);

$deviceId = trim($data['device_id']);
$userId = intval($data['user_id']);
$deviceName = $data['device_name'] ?? null;
$firmwareVersion = $data['firmware_version'] ?? '1.0.0';
$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;

// Verify user exists
$stmt = $db->prepare("SELECT id FROM users WHERE id = ?");
$stmt->execute([$userId]);
if (!$stmt->fetch()) {
    sendResponse(false, "User not found", null, 404);
}

// Check if device already exists
$stmt = $db->prepare("SELECT id, user_id FROM devices WHERE device_id = ?");
$stmt->execute([$deviceId]);
$existing = $stmt->fetch();

if ($existing) {
    // Update existing device
    $stmt = $db->prepare("
        UPDATE devices 
        SET user_id = ?, device_name = ?, firmware_version = ?, ip_address = ?, 
            status = 'ONLINE', last_seen = NOW()
        WHERE id = ?
    ");
    $stmt->execute([
        $userId,
        $deviceName,
        $firmwareVersion,
        $ipAddress,
        $existing['id']
    ]);
    
    // Update or create sensor thresholds
    $stmt = $db->prepare("
        SELECT id FROM sensor_thresholds 
        WHERE user_id = ? AND device_id = ?
    ");
    $stmt->execute([$userId, $existing['id']]);
    $thresholdExists = $stmt->fetch();
    
    if (!$thresholdExists) {
        $stmt = $db->prepare("
            INSERT INTO sensor_thresholds (user_id, device_id, ultrasonic_min_distance, mic_loud_threshold)
            VALUES (?, ?, 30.0, 2000)
        ");
        $stmt->execute([$userId, $existing['id']]);
    }
    
    sendResponse(true, "Device updated successfully", [
        'device_id' => $deviceId,
        'device_db_id' => $existing['id']
    ], 200);
} else {
    // Create new device
    $stmt = $db->prepare("
        INSERT INTO devices (user_id, device_id, device_name, firmware_version, ip_address, status, last_seen)
        VALUES (?, ?, ?, ?, ?, 'ONLINE', NOW())
    ");
    $stmt->execute([
        $userId,
        $deviceId,
        $deviceName,
        $firmwareVersion,
        $ipAddress
    ]);
    
    $deviceDbId = $db->lastInsertId();
    
    // Create default thresholds
    $stmt = $db->prepare("
        INSERT INTO sensor_thresholds (user_id, device_id, ultrasonic_min_distance, mic_loud_threshold)
        VALUES (?, ?, 30.0, 2000)
    ");
    $stmt->execute([$userId, $deviceDbId]);
    
    sendResponse(true, "Device registered successfully", [
        'device_id' => $deviceId,
        'device_db_id' => $deviceDbId
    ], 201);
}

