<?php
/**
 * SAARTHI Backend - Get Latest Sensor Data API
 * GET /api/device/getLatestSensorData
 * Returns latest sensor data for a user's device
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$deviceId = $_GET['device_id'] ?? null;

// Get user's device
if (!$deviceId) {
    $stmt = $db->prepare("SELECT id, device_id FROM devices WHERE user_id = ? ORDER BY last_seen DESC LIMIT 1");
    $stmt->execute([$user['user_id']]);
    $device = $stmt->fetch();
    $deviceId = $device ? $device['device_id'] : null;
}

if (!$deviceId) {
    sendResponse(false, "No device found", null, 404);
}

// Get latest sensor event
$stmt = $db->prepare("
    SELECT event_type, sensor_payload, severity, created_at
    FROM sensor_events
    WHERE user_id = ? AND device_id = (SELECT id FROM devices WHERE device_id = ?)
    ORDER BY created_at DESC
    LIMIT 1
");
$stmt->execute([$user['user_id'], $deviceId]);
$event = $stmt->fetch();

if ($event) {
    $payload = json_decode($event['sensor_payload'], true) ?: [];
    sendResponse(true, "Latest sensor data", [
        'touch' => $payload['touch'] ?? 0,
        'touch_type' => $payload['touch_type'] ?? null,
        'distance' => $payload['distance'] ?? -1,
        'mic_raw' => $payload['mic_raw'] ?? 0,
        'event_type' => $event['event_type'],
        'severity' => $event['severity'],
        'timestamp' => $event['created_at'],
        'sensor_payload' => $payload
    ], 200);
} else {
    sendResponse(true, "No sensor data yet", [
        'touch' => 0,
        'touch_type' => null,
        'distance' => -1,
        'mic_raw' => 0,
        'event_type' => null,
        'severity' => null,
        'timestamp' => null,
        'sensor_payload' => []
    ], 200);
}

