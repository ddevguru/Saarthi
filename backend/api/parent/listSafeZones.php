<?php
/**
 * SAARTHI Backend - List Safe Zones API
 * GET /api/parent/listSafeZones.php?child_id=1
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
        SELECT id, name, center_lat, center_lon, radius_meters, 
               is_restricted, active_start_time, active_end_time, is_active, created_at
        FROM safe_zones
        WHERE user_id = ? AND is_active = 1
        ORDER BY created_at DESC
    ");
    $stmt->execute([$childId]);
    $safeZones = $stmt->fetchAll();

    sendResponse(true, "Safe zones retrieved", [
        'safe_zones' => $safeZones
    ], 200);
} catch (PDOException $e) {
    error_log("Error listing safe zones: " . $e->getMessage());
    sendResponse(false, "Failed to retrieve safe zones", null, 500);
}

