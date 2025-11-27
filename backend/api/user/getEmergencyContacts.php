<?php
/**
 * SAARTHI Backend - Get Emergency Contacts API
 * GET /api/user/getEmergencyContacts.php
 * Returns user's emergency contacts
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$userId = $user['user_id'];

// Get emergency contacts
$stmt = $db->prepare("
    SELECT id, name, phone, relationship, is_primary, is_active
    FROM emergency_contacts
    WHERE user_id = ? AND is_active = 1
    ORDER BY is_primary DESC, name ASC
");
$stmt->execute([$userId]);
$contacts = $stmt->fetchAll(PDO::FETCH_ASSOC);

// If no emergency contacts, also check parent-child links
if (empty($contacts)) {
    $stmt = $db->prepare("
        SELECT u.id, u.name, u.phone, 'Parent' as relationship, 1 as is_primary
        FROM users u
        INNER JOIN parent_child_links pcl ON u.id = pcl.parent_id
        WHERE pcl.child_id = ? AND pcl.status = 'ACTIVE'
    ");
    $stmt->execute([$userId]);
    $contacts = $stmt->fetchAll(PDO::FETCH_ASSOC);
}

sendResponse(true, "Emergency contacts retrieved", $contacts, 200);

