<?php
/**
 * SAARTHI Backend - List Children API
 * GET /api/parent/listChildren.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$stmt = $db->prepare("
    SELECT 
        u.id,
        u.name,
        u.phone,
        u.disability_type,
        d.status as device_status,
        d.last_seen,
        (SELECT event_type FROM sensor_events 
         WHERE user_id = u.id 
         ORDER BY created_at DESC LIMIT 1) as last_event_type,
        (SELECT created_at FROM sensor_events 
         WHERE user_id = u.id 
         ORDER BY created_at DESC LIMIT 1) as last_event_time
    FROM users u
    INNER JOIN parent_child_links pcl ON u.id = pcl.child_id
    LEFT JOIN devices d ON u.id = d.user_id AND d.status = 'ONLINE'
    WHERE pcl.parent_id = ? AND pcl.status = 'ACTIVE'
    GROUP BY u.id
    ORDER BY u.name
");
$stmt->execute([$user['user_id']]);
$children = $stmt->fetchAll();

sendResponse(true, "Children retrieved successfully", [
    'children' => $children
], 200);

