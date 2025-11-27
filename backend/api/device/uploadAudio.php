<?php
/**
 * SAARTHI Backend - Upload Audio Recording API
 * POST /api/device/uploadAudio
 * Called by Flutter app to upload audio recordings
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$userId = $user['user_id'];
$eventId = $_POST['event_id'] ?? $_GET['event_id'] ?? null;
$deviceId = $_POST['device_id'] ?? $_GET['device_id'] ?? null;

// Get device info if device_id provided
$deviceDbId = null;
if ($deviceId) {
    $stmt = $db->prepare("SELECT id FROM devices WHERE device_id = ? AND user_id = ?");
    $stmt->execute([$deviceId, $userId]);
    $device = $stmt->fetch();
    if ($device) {
        $deviceDbId = $device['id'];
    }
}

// Handle file upload
if (!isset($_FILES['audio']) || $_FILES['audio']['error'] !== UPLOAD_ERR_OK) {
    sendResponse(false, "No audio file uploaded or upload error", null, 400);
}

$file = $_FILES['audio'];
$allowedTypes = ['audio/m4a', 'audio/aac', 'audio/mpeg', 'audio/mp3', 'audio/wav'];
$maxSize = 10 * 1024 * 1024; // 10MB

// Check file type
$fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
$allowedExtensions = ['m4a', 'aac', 'mp3', 'wav'];

if (!in_array($fileExtension, $allowedExtensions)) {
    sendResponse(false, "Invalid file type. Allowed: m4a, aac, mp3, wav", null, 400);
}

if ($file['size'] > $maxSize) {
    sendResponse(false, "File too large. Max 10MB", null, 400);
}

// Generate unique filename
$filename = 'audio_' . $userId . '_' . time() . '_' . uniqid() . '.' . $fileExtension;
$filepath = UPLOAD_AUDIO_DIR . $filename;

if (!move_uploaded_file($file['tmp_name'], $filepath)) {
    sendResponse(false, "Failed to save audio file", null, 500);
}

// Update event with audio path if event_id provided
if ($eventId) {
    $stmt = $db->prepare("
        UPDATE sensor_events
        SET audio_path = ?
        WHERE id = ? AND user_id = ?
    ");
    $stmt->execute(['uploads/audio/' . $filename, $eventId, $userId]);
}

// Also create a standalone event if no event_id
if (!$eventId) {
    $stmt = $db->prepare("
        INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity)
        VALUES (?, ?, 'AUDIO_RECORDING', ?, 'LOW')
    ");
    $stmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
    $eventId = $db->lastInsertId();
}

sendResponse(true, "Audio uploaded successfully", [
    'audio_path' => 'uploads/audio/' . $filename,
    'event_id' => $eventId
], 200);

