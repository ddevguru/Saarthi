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
if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    sendResponse(false, "No image file uploaded or upload error", null, 400);
}

$file = $_FILES['image'];
$allowedTypes = ['image/jpeg', 'image/jpg'];
$maxSize = 5 * 1024 * 1024; // 5MB

if (!in_array($file['type'], $allowedTypes)) {
    sendResponse(false, "Invalid file type. Only JPEG allowed", null, 400);
}

if ($file['size'] > $maxSize) {
    sendResponse(false, "File too large. Max 5MB", null, 400);
}

// Generate unique filename
$filename = 'snapshot_' . $deviceId . '_' . time() . '_' . uniqid() . '.jpg';
$filepath = UPLOAD_IMAGES_DIR . $filename;

if (!move_uploaded_file($file['tmp_name'], $filepath)) {
    sendResponse(false, "Failed to save image", null, 500);
}

// Update event with image path if event_id provided
if ($eventId) {
    $stmt = $db->prepare("
        UPDATE sensor_events
        SET image_path = ?
        WHERE id = ? AND user_id = ?
    ");
    $stmt->execute(['uploads/images/' . $filename, $eventId, $userId]);
}

// Also create a standalone event if no event_id
if (!$eventId) {
    $stmt = $db->prepare("
        INSERT INTO sensor_events (user_id, device_id, event_type, image_path, severity)
        VALUES (?, ?, 'OTHER', ?, 'LOW')
    ");
    $stmt->execute([$userId, $deviceDbId, 'uploads/images/' . $filename]);
}

sendResponse(true, "Image uploaded successfully", [
    'image_path' => 'uploads/images/' . $filename,
    'event_id' => $eventId
], 200);

