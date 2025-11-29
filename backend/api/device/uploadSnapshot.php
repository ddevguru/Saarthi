<?php
/**
 * SAARTHI Backend - Upload Camera Snapshot API
 * POST /api/device/uploadSnapshot
 * Called by ESP32-CAM to upload JPEG images
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Accept multipart/form-data
$deviceId = $_POST['device_id'] ?? $_GET['device_id'] ?? null;
$eventId = $_POST['event_id'] ?? $_GET['event_id'] ?? null;
$userId = $_POST['user_id'] ?? $_GET['user_id'] ?? null;

if (!$deviceId) {
    sendResponse(false, "device_id required", null, 400);
}

// Get device info
$stmt = $db->prepare("SELECT id, user_id FROM devices WHERE device_id = ?");
$stmt->execute([$deviceId]);
$device = $stmt->fetch();

if (!$device) {
    sendResponse(false, "Device not found", null, 404);
}

$userId = $userId ?? $device['user_id'];
$deviceDbId = $device['id'];

// Handle file upload
error_log("=== IMAGE UPLOAD REQUEST ===");
error_log("POST data: " . print_r($_POST, true));
error_log("FILES data: " . print_r($_FILES, true));
error_log("Device ID: " . ($deviceId ?? 'null'));
error_log("Event ID: " . ($eventId ?? 'null'));
error_log("User ID: " . ($userId ?? 'null'));

if (!isset($_FILES['image'])) {
    error_log("ERROR: No image file in upload. Files: " . print_r($_FILES, true));
    error_log("Request method: " . $_SERVER['REQUEST_METHOD']);
    error_log("Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
    sendResponse(false, "No image file uploaded", null, 400);
}

if ($_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    $errorMsg = "Upload error code: " . $_FILES['image']['error'];
    error_log($errorMsg);
    sendResponse(false, "Image upload error: $errorMsg", null, 400);
}

$file = $_FILES['image'];
$allowedTypes = ['image/jpeg', 'image/jpg'];
$maxSize = 5 * 1024 * 1024; // 5MB

// Check MIME type or file extension
$fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($file['type'], $allowedTypes) && $fileExtension !== 'jpg' && $fileExtension !== 'jpeg') {
    error_log("Invalid file type: " . $file['type'] . ", Extension: $fileExtension");
    sendResponse(false, "Invalid file type. Only JPEG allowed. Got: " . $file['type'], null, 400);
}

if ($file['size'] > $maxSize) {
    error_log("File too large: " . $file['size'] . " bytes");
    sendResponse(false, "File too large. Max 5MB", null, 400);
}

error_log("Image upload received: Name=" . $file['name'] . ", Size=" . $file['size'] . ", Type=" . $file['type']);

// Ensure upload directory exists and is writable
if (!file_exists(UPLOAD_IMAGES_DIR)) {
    if (!mkdir(UPLOAD_IMAGES_DIR, 0755, true)) {
        error_log("Failed to create upload images directory: " . UPLOAD_IMAGES_DIR);
        sendResponse(false, "Failed to create upload directory", null, 500);
    }
}

if (!is_writable(UPLOAD_IMAGES_DIR)) {
    error_log("Upload images directory is not writable: " . UPLOAD_IMAGES_DIR);
    sendResponse(false, "Upload directory is not writable", null, 500);
}

// Generate unique filename
$filename = 'snapshot_' . $deviceId . '_' . time() . '_' . uniqid() . '.jpg';
$filepath = UPLOAD_IMAGES_DIR . $filename;

// Log upload attempt
error_log("Attempting to save image: $filepath, Size: " . $file['size'] . " bytes");

if (!move_uploaded_file($file['tmp_name'], $filepath)) {
    $error = error_get_last();
    error_log("Failed to save image: " . ($error ? $error['message'] : 'Unknown error'));
    error_log("Upload error code: " . $file['error']);
    error_log("Temp file: " . $file['tmp_name']);
    error_log("Target path: " . $filepath);
    error_log("Directory exists: " . (file_exists(UPLOAD_IMAGES_DIR) ? 'Yes' : 'No'));
    error_log("Directory writable: " . (is_writable(UPLOAD_IMAGES_DIR) ? 'Yes' : 'No'));
    sendResponse(false, "Failed to save image: " . ($error ? $error['message'] : 'Unknown error'), null, 500);
}

// Verify file was saved
if (!file_exists($filepath)) {
    error_log("File was not saved: $filepath");
    sendResponse(false, "File was not saved", null, 500);
}

error_log("Image saved successfully: $filepath");

// Update event with image path if event_id provided
$updateSuccess = false;
if ($eventId) {
    // Convert eventId to integer for database query
    $eventIdInt = intval($eventId);
    error_log("Attempting to update event $eventIdInt (original: $eventId) with image path");
    
    $stmt = $db->prepare("
        UPDATE sensor_events
        SET image_path = ?
        WHERE id = ? AND user_id = ?
    ");
    $result = $stmt->execute(['uploads/images/' . $filename, $eventIdInt, $userId]);
    
    if ($result && $stmt->rowCount() > 0) {
        error_log("✓ Successfully updated event $eventIdInt with image path: uploads/images/$filename");
        $updateSuccess = true;
    } else {
        error_log("⚠️ Warning: Event $eventIdInt not found or not updated. Rows affected: " . $stmt->rowCount());
        error_log("Event ID (int): $eventIdInt, Event ID (original): $eventId, User ID: $userId, Image Path: uploads/images/$filename");
        error_log("SQL Error Info: " . print_r($stmt->errorInfo(), true));
        
        // Try to find the event by checking recent events
        $checkStmt = $db->prepare("SELECT id, event_type, created_at FROM sensor_events WHERE id = ? AND user_id = ?");
        $checkStmt->execute([$eventIdInt, $userId]);
        $eventCheck = $checkStmt->fetch();
        if ($eventCheck) {
            error_log("Event exists but UPDATE failed. Event details: " . print_r($eventCheck, true));
            // Retry UPDATE
            $retryStmt = $db->prepare("UPDATE sensor_events SET image_path = ? WHERE id = ? AND user_id = ?");
            $retryResult = $retryStmt->execute(['uploads/images/' . $filename, $eventIdInt, $userId]);
            if ($retryResult && $retryStmt->rowCount() > 0) {
                error_log("✓ Successfully updated event $eventIdInt with image path (retry)");
                $updateSuccess = true;
            }
        } else {
            error_log("Event $eventIdInt does not exist in database for user $userId");
        }
    }
}

// If UPDATE failed or no eventId, create/update event
if (!$updateSuccess) {
    if ($eventId) {
        // EventId was provided but UPDATE failed - try to link to most recent event without image
        $eventIdInt = intval($eventId);
        error_log("Trying to link image to most recent event for user $userId");
        
        // Find most recent event without image_path for this user/device
        $linkStmt = $db->prepare("
            SELECT id FROM sensor_events 
            WHERE user_id = ? AND device_id = ? 
            AND (image_path IS NULL OR image_path = '')
            ORDER BY created_at DESC 
            LIMIT 1
        ");
        $linkStmt->execute([$userId, $deviceDbId]);
        $recentEvent = $linkStmt->fetch();
        
        if ($recentEvent) {
            $linkEventId = $recentEvent['id'];
            error_log("Found recent event $linkEventId without image, linking image to it");
            $linkUpdateStmt = $db->prepare("UPDATE sensor_events SET image_path = ? WHERE id = ? AND user_id = ?");
            $linkResult = $linkUpdateStmt->execute(['uploads/images/' . $filename, $linkEventId, $userId]);
            if ($linkResult && $linkUpdateStmt->rowCount() > 0) {
                error_log("✓ Successfully linked image to event $linkEventId");
                $eventId = $linkEventId;
                $updateSuccess = true;
            }
        }
        
        // If still failed, create new event
        if (!$updateSuccess) {
            error_log("Creating new event for image since linking failed");
            $newStmt = $db->prepare("
                INSERT INTO sensor_events (user_id, device_id, event_type, image_path, severity, created_at)
                VALUES (?, ?, 'IMAGE_CAPTURE', ?, 'LOW', NOW())
            ");
            $newResult = $newStmt->execute([$userId, $deviceDbId, 'uploads/images/' . $filename]);
            if ($newResult) {
                $eventId = $db->lastInsertId();
                error_log("Created new event $eventId for image: uploads/images/$filename");
            } else {
                error_log("ERROR: Failed to create event for image");
                error_log("SQL Error Info: " . print_r($newStmt->errorInfo(), true));
            }
        }
    } else {
        // No eventId provided - create standalone event
        $newStmt = $db->prepare("
            INSERT INTO sensor_events (user_id, device_id, event_type, image_path, severity, created_at)
            VALUES (?, ?, 'IMAGE_CAPTURE', ?, 'LOW', NOW())
        ");
        $newResult = $newStmt->execute([$userId, $deviceDbId, 'uploads/images/' . $filename]);
        
        if ($newResult) {
            $eventId = $db->lastInsertId();
            error_log("Created new event $eventId for image: uploads/images/$filename");
        } else {
            error_log("ERROR: Failed to create event for image");
            error_log("SQL Error Info: " . print_r($newStmt->errorInfo(), true));
            error_log("User ID: $userId, Device DB ID: $deviceDbId, Image Path: uploads/images/$filename");
        }
    }
}

$fileSize = filesize($filepath);
$fileExists = file_exists($filepath);

error_log("=== IMAGE UPLOAD SUCCESS ===");
error_log("Image Path: uploads/images/$filename");
error_log("Full File Path: $filepath");
error_log("File Size: $fileSize bytes");
error_log("File Exists: " . ($fileExists ? 'Yes' : 'No'));
error_log("Event ID: " . ($eventId ?? 'null'));
error_log("User ID: $userId");
error_log("Device ID: $deviceId");
error_log("Device DB ID: $deviceDbId");
error_log("=============================");

sendResponse(true, "Image uploaded successfully", [
    'image_path' => 'uploads/images/' . $filename,
    'event_id' => $eventId,
    'file_size' => $fileSize,
    'file_exists' => $fileExists
], 200);

