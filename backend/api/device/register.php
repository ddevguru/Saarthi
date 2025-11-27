<?php
/**
 * SAARTHI Backend - Register Device API
 * POST /api/device/register.php
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
$deviceName = $data['device_name'] ?? null;
$firmwareVersion = $data['firmware_version'] ?? null;
$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;

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
        $user['user_id'],
        $deviceName,
        $firmwareVersion,
        $ipAddress,
        $existing['id']
    ]);
    
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
        $user['user_id'],
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
    $stmt->execute([$user['user_id'], $deviceDbId]);
    
    sendResponse(true, "Device registered successfully", [
        'device_id' => $deviceId,
        'device_db_id' => $deviceDbId
    ], 201);
}

