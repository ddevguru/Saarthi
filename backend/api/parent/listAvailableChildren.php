<?php
/**
 * SAARTHI Backend - List Available Children API
 * GET /api/parent/listAvailableChildren.php
 * Returns list of all USER accounts that can be linked as children
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$parentId = $user['user_id'];

// Get all USER accounts that are not already linked to this parent
// Check for ACTIVE links only - ignore PENDING or BLOCKED
$stmt = $db->prepare("
    SELECT 
        u.id,
        u.name,
        u.phone,
        u.email,
        u.disability_type,
        u.is_active,
        CASE 
            WHEN pcl.id IS NOT NULL AND pcl.status = 'ACTIVE' THEN 1 
            ELSE 0 
        END as is_linked,
        pcl.status as link_status
    FROM users u
    LEFT JOIN parent_child_links pcl ON u.id = pcl.child_id AND pcl.parent_id = ?
    WHERE u.role = 'USER' AND u.is_active = 1
    AND (pcl.id IS NULL OR pcl.status != 'ACTIVE')
    ORDER BY u.name
");
$stmt->execute([$parentId]);
$children = $stmt->fetchAll();

// Debug logging
error_log("Available children query for parent_id $parentId: Found " . count($children) . " children");

sendResponse(true, "Available children retrieved successfully", [
    'children' => $children
], 200);

