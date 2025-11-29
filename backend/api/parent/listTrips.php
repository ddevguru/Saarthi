<?php
/**
 * SAARTHI Backend - List Trips API
 * GET /api/parent/listTrips.php?child_id=1
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$childId = isset($_GET['child_id']) ? intval($_GET['child_id']) : null;

if (!$childId) {
    sendResponse(false, "Child ID is required", null, 400);
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

try {
    $stmt = $db->prepare("
        SELECT id, destination_name, start_location_lat, start_location_lon,
               end_location_lat, end_location_lon, start_time, expected_end_time,
               actual_end_time, status, notes, created_at
        FROM trips
        WHERE user_id = ? AND status IN ('ACTIVE', 'DELAYED', 'COMPLETED')
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $stmt->execute([$childId]);
    $trips = $stmt->fetchAll();

    sendResponse(true, "Trips retrieved", [
        'trips' => $trips
    ], 200);
} catch (PDOException $e) {
    error_log("Error listing trips: " . $e->getMessage());
    sendResponse(false, "Failed to retrieve trips", null, 500);
}

