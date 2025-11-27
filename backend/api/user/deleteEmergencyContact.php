<?php
/**
 * SAARTHI Backend - Delete Emergency Contact API
 * POST /api/user/deleteEmergencyContact.php
 * Delete emergency contact
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
validateRequired($data, ['id']);

$userId = $user['user_id'];
$contactId = $data['id'];

// Soft delete (set is_active = 0)
$stmt = $db->prepare("
    UPDATE emergency_contacts
    SET is_active = 0, updated_at = NOW()
    WHERE id = ? AND user_id = ?
");
$stmt->execute([$contactId, $userId]);

if ($stmt->rowCount() > 0) {
    sendResponse(true, "Emergency contact deleted", null, 200);
} else {
    sendResponse(false, "Contact not found or unauthorized", null, 404);
}

