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
// Accept either child_id or child_phone for backward compatibility
if (!isset($data['child_id']) && !isset($data['child_phone'])) {
    sendResponse(false, "child_id or child_phone is required", null, 400);
}

$parentId = $user['user_id'];
$childId = isset($data['child_id']) ? intval($data['child_id']) : null;

// If child_id is provided, use it directly
if ($childId) {
    $stmt = $db->prepare("SELECT id, name, role, is_active, phone FROM users WHERE id = ?");
    $stmt->execute([$childId]);
    $child = $stmt->fetch();
} else {
    // Fallback to phone number search (for backward compatibility)
    $childPhone = trim($data['child_phone']);
    
    // Remove any non-digit characters except +
    $childPhone = preg_replace('/[^0-9+]/', '', $childPhone);
    
    // Normalize phone number (add country code if missing)
    if (strlen($childPhone) == 10) {
        $childPhone = '91' . $childPhone;
    } elseif (strlen($childPhone) == 11 && substr($childPhone, 0, 1) == '0') {
        $childPhone = '91' . substr($childPhone, 1);
    }
    
    // Find child user by phone - try multiple formats
    $child = null;
    $searchPhones = [
        $childPhone,
        '+' . $childPhone,
        ltrim($childPhone, '+'),
    ];
    
    if (strlen($childPhone) >= 12 && substr($childPhone, 0, 2) == '91') {
        $searchPhones[] = substr($childPhone, 2);
    }
    
    foreach ($searchPhones as $searchPhone) {
        $stmt = $db->prepare("SELECT id, name, role, is_active, phone FROM users WHERE phone = ? OR phone = ? OR phone = ?");
        $stmt->execute([$searchPhone, '+' . $searchPhone, ltrim($searchPhone, '+')]);
        $child = $stmt->fetch();
        if ($child) {
            break;
        }
    }
}

if (!$child) {
    sendResponse(false, "User not found. Please select a valid child from the list.", null, 404);
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
        INSERT INTO parent_child_links (parent_id, child_id, status, created_at, updated_at)
        VALUES (?, ?, 'ACTIVE', NOW(), NOW())
    ");
    $result = $stmt->execute([$parentId, $child['id']]);
    
    if ($result && $stmt->rowCount() > 0) {
        $linkId = $db->lastInsertId();
        
        sendResponse(true, "Child linked successfully", [
            'link_id' => $linkId,
            'child_id' => $child['id'],
            'child_name' => $child['name'],
            'child_phone' => $child['phone'] ?? ''
        ], 200);
    } else {
        sendResponse(false, "Failed to create link. No rows inserted.", null, 500);
    }
} catch (PDOException $e) {
    error_log("Add child error: " . $e->getMessage() . " | Code: " . $e->getCode());
    if ($e->getCode() == 23000) {
        // Duplicate entry
        sendResponse(false, "Child is already linked to your account.", null, 400);
    }
    sendResponse(false, "Failed to link child: " . $e->getMessage(), null, 500);
}

