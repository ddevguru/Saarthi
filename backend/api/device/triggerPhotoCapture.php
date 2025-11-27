<?php
/**
 * SAARTHI Backend - Trigger Photo Capture API
 * POST /api/device/triggerPhotoCapture.php
 * Called by Flutter app to trigger ESP32-CAM photo capture
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
validateRequired($data, ['device_id', 'event_type']);

$userId = $user['user_id'];
$deviceId = trim($data['device_id']);
$eventType = trim($data['event_type']);

// Get device info
$stmt = $db->prepare("SELECT id, user_id FROM devices WHERE device_id = ? AND user_id = ?");
$stmt->execute([$deviceId, $userId]);
$device = $stmt->fetch();

if (!$device) {
    sendResponse(false, "Device not found or unauthorized", null, 404);
}

// Note: ESP32-CAM will automatically capture photos when events are triggered
// This endpoint just confirms the request and returns success
// The actual photo capture happens on ESP32 when it receives the event

sendResponse(true, "Photo capture triggered", [
    'device_id' => $deviceId,
    'event_type' => $eventType,
    'message' => 'ESP32-CAM will capture photo on next sensor data update'
], 200);

