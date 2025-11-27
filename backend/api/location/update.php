<?php
/**
 * SAARTHI Backend - Update Location API
 * POST /api/location/update
 * Called by Flutter app to send GPS coordinates
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';
require_once __DIR__ . '/../../services/geofence_service.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
validateRequired($data, ['latitude', 'longitude']);

$latitude = floatval($data['latitude']);
$longitude = floatval($data['longitude']);
$accuracy = floatval($data['accuracy'] ?? 0);
$speed = floatval($data['speed'] ?? 0);
$batteryLevel = intval($data['battery_level'] ?? null);
$deviceId = $data['device_id'] ?? null;

// Get device_id if not provided
if (!$deviceId) {
    $stmt = $db->prepare("SELECT id FROM devices WHERE user_id = ? ORDER BY last_seen DESC LIMIT 1");
    $stmt->execute([$user['user_id']]);
    $device = $stmt->fetch();
    $deviceId = $device ? $device['id'] : null;
}

// Validate coordinates
if ($latitude < -90 || $latitude > 90 || $longitude < -180 || $longitude > 180) {
    sendResponse(false, "Invalid coordinates", null, 400);
}

// Insert location
try {
    $stmt = $db->prepare("
        INSERT INTO locations (user_id, device_id, latitude, longitude, accuracy, speed, battery_level)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $user['user_id'],
        $deviceId,
        $latitude,
        $longitude,
        $accuracy,
        $speed,
        $batteryLevel
    ]);

    // Check geofence
    $geofenceService = new GeofenceService($db);
    $geofenceService->checkGeofence($user['user_id'], $latitude, $longitude);

    // Check active trips for delays
    $stmt = $db->prepare("
        SELECT id, expected_end_time, status
        FROM trips
        WHERE user_id = ? AND status = 'ACTIVE' AND expected_end_time IS NOT NULL
    ");
    $stmt->execute([$user['user_id']]);
    $activeTrip = $stmt->fetch();

    if ($activeTrip && strtotime($activeTrip['expected_end_time']) < time()) {
        // Trip delayed
        $stmt = $db->prepare("
            UPDATE trips SET status = 'DELAYED' WHERE id = ?
        ");
        $stmt->execute([$activeTrip['id']]);

        // Create delay event
        $stmt = $db->prepare("
            INSERT INTO sensor_events (user_id, event_type, severity)
            VALUES (?, 'TRIP_DELAY', 'HIGH')
        ");
        $stmt->execute([$user['user_id']]);
        $eventId = $db->lastInsertId();

        // Send alert
        require_once __DIR__ . '/../../services/whatsapp_service.php';
        $whatsappService = new WhatsAppService($db);
        
        $stmt = $db->prepare("SELECT name FROM users WHERE id = ?");
        $stmt->execute([$user['user_id']]);
        $userInfo = $stmt->fetch();

        $stmt = $db->prepare("
            SELECT u.phone FROM users u
            INNER JOIN parent_child_links pcl ON u.id = pcl.parent_id
            WHERE pcl.child_id = ? AND pcl.status = 'ACTIVE'
        ");
        $stmt->execute([$user['user_id']]);
        $parents = $stmt->fetchAll();

        $message = "⏰ Trip Delay Alert\n\n";
        $message .= "User: " . $userInfo['name'] . "\n";
        $message .= "Expected arrival time has passed.\n";
        $message .= "Current location: " . "https://www.google.com/maps?q=" . $latitude . "," . $longitude;

        foreach ($parents as $parent) {
            $whatsappService->sendMessage($parent['phone'], $message, $user['user_id'], $eventId);
        }
    }

    sendResponse(true, "Location updated successfully", [
        'latitude' => $latitude,
        'longitude' => $longitude,
        'timestamp' => date('Y-m-d H:i:s')
    ], 200);

} catch (PDOException $e) {
    error_log("Location update error: " . $e->getMessage());
    sendResponse(false, "Failed to update location", null, 500);
}

