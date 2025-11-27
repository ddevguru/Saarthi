<?php
/**
 * SAARTHI Backend - Create Safe Zone API
 * POST /api/parent/createSafeZone
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$data = getRequestBody();
validateRequired($data, ['child_id', 'name', 'center_lat', 'center_lon', 'radius_meters']);

$childId = intval($data['child_id']);
$name = trim($data['name']);
$centerLat = floatval($data['center_lat']);
$centerLon = floatval($data['center_lon']);
$radiusMeters = intval($data['radius_meters']);
$isRestricted = isset($data['is_restricted']) ? (bool)$data['is_restricted'] : false;
$activeStartTime = $data['active_start_time'] ?? null;
$activeEndTime = $data['active_end_time'] ?? null;

// Verify parent-child relationship
$stmt = $db->prepare("
    SELECT status FROM parent_child_links
    WHERE parent_id = ? AND child_id = ? AND status = 'ACTIVE'
");
$stmt->execute([$user['user_id'], $childId]);
if (!$stmt->fetch()) {
    sendResponse(false, "Access denied. Child not linked to this parent.", null, 403);
}

// Validate coordinates
if ($centerLat < -90 || $centerLat > 90 || $centerLon < -180 || $centerLon > 180) {
    sendResponse(false, "Invalid coordinates", null, 400);
}

if ($radiusMeters < 10 || $radiusMeters > 10000) {
    sendResponse(false, "Radius must be between 10 and 10000 meters", null, 400);
}

try {
    $stmt = $db->prepare("
        INSERT INTO safe_zones (user_id, name, center_lat, center_lon, radius_meters, is_restricted, active_start_time, active_end_time)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $childId,
        $name,
        $centerLat,
        $centerLon,
        $radiusMeters,
        $isRestricted ? 1 : 0,
        $activeStartTime,
        $activeEndTime
    ]);

    $zoneId = $db->lastInsertId();

    sendResponse(true, "Safe zone created successfully", [
        'zone_id' => $zoneId,
        'name' => $name
    ], 201);

} catch (PDOException $e) {
    error_log("Safe zone creation error: " . $e->getMessage());
    sendResponse(false, "Failed to create safe zone", null, 500);
}

