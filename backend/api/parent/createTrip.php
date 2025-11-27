<?php
/**
 * SAARTHI Backend - Create Trip API
 * POST /api/parent/createTrip
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$data = getRequestBody();
validateRequired($data, ['child_id', 'destination_name', 'end_location_lat', 'end_location_lon', 'expected_end_time']);

$childId = intval($data['child_id']);
$destinationName = trim($data['destination_name']);
$endLat = floatval($data['end_location_lat']);
$endLon = floatval($data['end_location_lon']);
$expectedEndTime = $data['expected_end_time'];
$startLat = $data['start_location_lat'] ?? null;
$startLon = $data['start_location_lon'] ?? null;
$notes = $data['notes'] ?? null;

// Verify parent-child relationship
$stmt = $db->prepare("
    SELECT status FROM parent_child_links
    WHERE parent_id = ? AND child_id = ? AND status = 'ACTIVE'
");
$stmt->execute([$user['user_id'], $childId]);
if (!$stmt->fetch()) {
    sendResponse(false, "Access denied. Child not linked to this parent.", null, 403);
}

// Get current location if start not provided
if (!$startLat || !$startLon) {
    $stmt = $db->prepare("
        SELECT latitude, longitude FROM locations
        WHERE user_id = ?
        ORDER BY created_at DESC LIMIT 1
    ");
    $stmt->execute([$childId]);
    $currentLoc = $stmt->fetch();
    if ($currentLoc) {
        $startLat = $currentLoc['latitude'];
        $startLon = $currentLoc['longitude'];
    }
}

try {
    $stmt = $db->prepare("
        INSERT INTO trips (user_id, guardian_id, start_location_lat, start_location_lon, 
                          end_location_lat, end_location_lon, destination_name, 
                          expected_end_time, status, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PLANNED', ?)
    ");
    $stmt->execute([
        $childId,
        $user['user_id'],
        $startLat,
        $startLon,
        $endLat,
        $endLon,
        $destinationName,
        $expectedEndTime,
        $notes
    ]);

    $tripId = $db->lastInsertId();

    sendResponse(true, "Trip created successfully", [
        'trip_id' => $tripId,
        'destination' => $destinationName,
        'status' => 'PLANNED'
    ], 201);

} catch (PDOException $e) {
    error_log("Trip creation error: " . $e->getMessage());
    sendResponse(false, "Failed to create trip", null, 500);
}

