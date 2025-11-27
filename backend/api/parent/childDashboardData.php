<?php
/**
 * SAARTHI Backend - Parent Child Dashboard Data API
 * GET /api/parent/childDashboardData?child_id=X
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$childId = intval($_GET['child_id'] ?? 0);

if (!$childId) {
    sendResponse(false, "child_id required", null, 400);
}

// Verify parent-child relationship
$stmt = $db->prepare("
    SELECT status FROM parent_child_links
    WHERE parent_id = ? AND child_id = ? AND status = 'ACTIVE'
");
$stmt->execute([$user['user_id'], $childId]);
if (!$stmt->fetch()) {
    sendResponse(false, "Access denied. Child not linked to this parent.", null, 403);
}

// Get child info
$stmt = $db->prepare("SELECT id, name, phone, disability_type FROM users WHERE id = ?");
$stmt->execute([$childId]);
$child = $stmt->fetch();

// Get latest location
$stmt = $db->prepare("
    SELECT latitude, longitude, accuracy, speed, battery_level, created_at
    FROM locations
    WHERE user_id = ?
    ORDER BY created_at DESC LIMIT 1
");
$stmt->execute([$childId]);
$latestLocation = $stmt->fetch();

// Get active device (get the most recently seen device, not just ONLINE status)
$stmt = $db->prepare("
    SELECT id, device_id, device_name, status, last_seen, stream_url, ip_address, firmware_version
    FROM devices
    WHERE user_id = ?
    ORDER BY last_seen DESC LIMIT 1
");
$stmt->execute([$childId]);
$device = $stmt->fetch();

// Get recent events (last 24 hours) with photos and audio
$stmt = $db->prepare("
    SELECT id, event_type, severity, created_at, object_label, image_path, audio_path, sensor_payload
    FROM sensor_events
    WHERE user_id = ?
    AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ORDER BY created_at DESC
    LIMIT 20
");
$stmt->execute([$childId]);
$recentEvents = $stmt->fetchAll();

// Get active trip
$stmt = $db->prepare("
    SELECT id, start_time, expected_end_time, destination_name, status
    FROM trips
    WHERE user_id = ? AND status IN ('ACTIVE', 'DELAYED')
    ORDER BY start_time DESC LIMIT 1
");
$stmt->execute([$childId]);
$activeTrip = $stmt->fetch();

// Get safe zones
$stmt = $db->prepare("
    SELECT id, name, center_lat, center_lon, radius_meters, is_restricted
    FROM safe_zones
    WHERE user_id = ? AND is_active = 1
");
$stmt->execute([$childId]);
$safeZones = $stmt->fetchAll();

sendResponse(true, "Dashboard data retrieved", [
    'child' => $child,
    'latest_location' => $latestLocation,
    'device' => $device,
    'recent_events' => $recentEvents,
    'active_trip' => $activeTrip,
    'safe_zones' => $safeZones
], 200);

