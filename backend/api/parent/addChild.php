<?php
/**
 * SAARTHI Backend - Add Child API
 * POST /api/parent/addChild.php
 * Allows parent to link a child account by phone number
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->requireRole(['PARENT', 'ADMIN']);

$data = getRequestBody();
validateRequired($data, ['child_phone']);

$parentId = $user['user_id'];
$childPhone = trim($data['child_phone']);

// Remove any non-digit characters except +
$childPhone = preg_replace('/[^0-9+]/', '', $childPhone);

// Normalize phone number (add country code if missing)
if (strlen($childPhone) == 10) {
    // Assume India (+91) if 10 digits
    $childPhone = '91' . $childPhone;
} elseif (strlen($childPhone) == 11 && substr($childPhone, 0, 1) == '0') {
    // Remove leading 0 and add 91
    $childPhone = '91' . substr($childPhone, 1);
}

// Find child user by phone
$stmt = $db->prepare("SELECT id, name, role, is_active FROM users WHERE phone = ?");
$stmt->execute([$childPhone]);
$child = $stmt->fetch();

if (!$child) {
    sendResponse(false, "No user found with phone number: $childPhone. Please ensure the child has registered first.", null, 404);
}

// Check if child is a USER (not PARENT or ADMIN)
if ($child['role'] !== 'USER') {
    sendResponse(false, "Cannot link this account. Only USER accounts can be linked as children.", null, 400);
}

// Check if child account is active
if (!$child['is_active']) {
    sendResponse(false, "Child account is inactive. Please contact support.", null, 400);
}

// Check if already linked
$stmt = $db->prepare("
    SELECT id, status FROM parent_child_links 
    WHERE parent_id = ? AND child_id = ?
");
$stmt->execute([$parentId, $child['id']]);
$existingLink = $stmt->fetch();

if ($existingLink) {
    if ($existingLink['status'] === 'ACTIVE') {
        sendResponse(false, "Child is already linked to your account.", null, 400);
    } elseif ($existingLink['status'] === 'BLOCKED') {
        sendResponse(false, "This child link was blocked. Please contact support.", null, 403);
    } else {
        // Reactivate PENDING link
        $stmt = $db->prepare("
            UPDATE parent_child_links 
            SET status = 'ACTIVE', updated_at = NOW() 
            WHERE id = ?
        ");
        $stmt->execute([$existingLink['id']]);
        
        sendResponse(true, "Child linked successfully", [
            'child_id' => $child['id'],
            'child_name' => $child['name'],
            'child_phone' => $childPhone
        ], 200);
    }
}

// Create new link
try {
    $stmt = $db->prepare("
        INSERT INTO parent_child_links (parent_id, child_id, status)
        VALUES (?, ?, 'ACTIVE')
    ");
    $stmt->execute([$parentId, $child['id']]);
    
    sendResponse(true, "Child linked successfully", [
        'child_id' => $child['id'],
        'child_name' => $child['name'],
        'child_phone' => $childPhone
    ], 200);
} catch (PDOException $e) {
    if ($e->getCode() == 23000) {
        // Duplicate entry
        sendResponse(false, "Child is already linked to your account.", null, 400);
    }
    sendResponse(false, "Failed to link child: " . $e->getMessage(), null, 500);
}

