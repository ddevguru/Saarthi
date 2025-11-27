<?php
/**
 * SAARTHI Backend - Get Device Token API (for ESP32)
 * GET /api/device/getToken.php?device_id=X
 * Returns device token if device is already registered
 * Note: This is less secure, use only for initial provisioning
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Accept GET for ESP32 simplicity
$data = $_GET;
validateRequired($data, ['device_id']);

$deviceId = trim($data['device_id']);

// Get device token
$stmt = $db->prepare("
    SELECT device_token, token_generated_at, user_id, status
    FROM devices
    WHERE device_id = ?
");
$stmt->execute([$deviceId]);
$device = $stmt->fetch();

if (!$device) {
    sendResponse(false, "Device not found. Please register device first from the app.", null, 404);
}

if (empty($device['device_token'])) {
    sendResponse(false, "Device token not generated. Please generate token from app (Settings > Device Pairing).", null, 404);
}

// Check token age (optional security - tokens older than 1 year need regeneration)
if (!empty($device['token_generated_at'])) {
    $tokenAge = time() - strtotime($device['token_generated_at']);
    if ($tokenAge > 31536000) { // 1 year
        sendResponse(false, "Device token expired. Please regenerate token from app.", null, 401);
    }
}

// Return token (only if device is registered)
sendResponse(true, "Device token retrieved", [
    'device_token' => $device['device_token'],
    'user_id' => $device['user_id'],
    'status' => $device['status']
], 200);

