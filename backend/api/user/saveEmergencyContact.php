<?php
/**
 * SAARTHI Backend - Save Emergency Contact API
 * POST /api/user/saveEmergencyContact.php
 * Save or update emergency contact
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
validateRequired($data, ['name', 'phone']);

$userId = $user['user_id'];
$contactId = $data['id'] ?? null;
$name = trim($data['name']);
$phone = preg_replace('/[^0-9+]/', '', trim($data['phone'])); // Clean phone number
$relationship = trim($data['relationship'] ?? 'Friend');
$isPrimary = isset($data['is_primary']) ? (bool)$data['is_primary'] : false;

// If setting as primary, unset other primary contacts
if ($isPrimary) {
    $stmt = $db->prepare("UPDATE emergency_contacts SET is_primary = 0 WHERE user_id = ?");
    $stmt->execute([$userId]);
}

if ($contactId) {
    // Update existing contact
    $stmt = $db->prepare("
        UPDATE emergency_contacts
        SET name = ?, phone = ?, relationship = ?, is_primary = ?, updated_at = NOW()
        WHERE id = ? AND user_id = ?
    ");
    $stmt->execute([$name, $phone, $relationship, $isPrimary ? 1 : 0, $contactId, $userId]);
    
    if ($stmt->rowCount() > 0) {
        sendResponse(true, "Emergency contact updated", ['id' => $contactId], 200);
    } else {
        sendResponse(false, "Contact not found or unauthorized", null, 404);
    }
} else {
    // Create new contact
    try {
        $stmt = $db->prepare("
            INSERT INTO emergency_contacts (user_id, name, phone, relationship, is_primary, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 1, NOW(), NOW())
        ");
        $result = $stmt->execute([$userId, $name, $phone, $relationship, $isPrimary ? 1 : 0]);
        
        if ($result && $stmt->rowCount() > 0) {
            $contactId = $db->lastInsertId();
            sendResponse(true, "Emergency contact saved", ['id' => $contactId], 201);
        } else {
            error_log("Emergency contact insert failed: No rows inserted. User ID: $userId, Name: $name, Phone: $phone");
            sendResponse(false, "Failed to save emergency contact. No rows inserted.", null, 500);
        }
    } catch (PDOException $e) {
        error_log("Emergency contact insert error: " . $e->getMessage() . " | Code: " . $e->getCode());
        sendResponse(false, "Failed to save emergency contact: " . $e->getMessage(), null, 500);
    }
}

