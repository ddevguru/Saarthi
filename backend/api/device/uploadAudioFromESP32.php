<?php
/**
 * SAARTHI Backend - Upload Audio from ESP32-CAM API
 * POST /api/device/uploadAudioFromESP32
 * Called by ESP32-CAM to upload audio recordings from external microphone
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Accept multipart/form-data or raw audio data
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

// Handle file upload (multipart)
if (isset($_FILES['audio']) && $_FILES['audio']['error'] === UPLOAD_ERR_OK) {
    $file = $_FILES['audio'];
    $allowedExtensions = ['wav', 'raw', 'pcm'];
    $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    
    if (!in_array($fileExtension, $allowedExtensions)) {
        sendResponse(false, "Invalid file type. Allowed: wav, raw, pcm", null, 400);
    }
    
    $maxSize = 5 * 1024 * 1024; // 5MB
    if ($file['size'] > $maxSize) {
        sendResponse(false, "File too large. Max 5MB", null, 400);
    }
    
    // Generate unique filename (convert to WAV for compatibility)
    $filename = 'audio_esp32_' . $deviceId . '_' . time() . '_' . uniqid() . '.wav';
    $filepath = UPLOAD_AUDIO_DIR . $filename;
    
    // If raw/PCM, convert to WAV format
    if ($fileExtension === 'raw' || $fileExtension === 'pcm') {
        // Read raw audio data
        $rawData = file_get_contents($file['tmp_name']);
        
        // Create WAV header (16-bit PCM, 8kHz mono)
        $sampleRate = 8000;
        $bitsPerSample = 16;
        $channels = 1;
        $dataSize = strlen($rawData);
        $fileSize = 36 + $dataSize;
        
        $wavHeader = pack('a4Va4a4VvvVVa4V',
            'RIFF',                    // ChunkID
            $fileSize,                  // ChunkSize
            'WAVE',                     // Format
            'fmt ',                     // Subchunk1ID
            16,                         // Subchunk1Size (PCM)
            1,                          // AudioFormat (PCM)
            $channels,                  // NumChannels
            $sampleRate,                // SampleRate
            $sampleRate * $channels * ($bitsPerSample / 8), // ByteRate
            $channels * ($bitsPerSample / 8), // BlockAlign
            $bitsPerSample,             // BitsPerSample
            'data',                     // Subchunk2ID
            $dataSize                   // Subchunk2Size
        );
        
        // Write WAV file
        file_put_contents($filepath, $wavHeader . $rawData);
    } else {
        // Direct copy for WAV files
        if (!move_uploaded_file($file['tmp_name'], $filepath)) {
            sendResponse(false, "Failed to save audio file", null, 500);
        }
    }
    
    // Update event with audio path if event_id provided
    if ($eventId) {
        $stmt = $db->prepare("
            UPDATE sensor_events
            SET audio_path = ?
            WHERE id = ? AND user_id = ?
        ");
        $stmt->execute(['uploads/audio/' . $filename, $eventId, $userId]);
    } else {
        // Create standalone event
        $stmt = $db->prepare("
            INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity)
            VALUES (?, ?, 'AUDIO_RECORDING_ESP32', ?, 'LOW')
        ");
        $stmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
        $eventId = $db->lastInsertId();
    }
    
    sendResponse(true, "Audio uploaded successfully from ESP32", [
        'audio_path' => 'uploads/audio/' . $filename,
        'event_id' => $eventId
    ], 200);
} else {
    // Try to accept raw audio data in POST body
    $rawAudio = file_get_contents('php://input');
    
    if (empty($rawAudio) || strlen($rawAudio) < 100) {
        sendResponse(false, "No audio data received", null, 400);
    }
    
    // Generate unique filename
    $filename = 'audio_esp32_' . $deviceId . '_' . time() . '_' . uniqid() . '.wav';
    $filepath = UPLOAD_AUDIO_DIR . $filename;
    
    // Create WAV header (16-bit PCM, 8kHz mono)
    $sampleRate = 8000;
    $bitsPerSample = 16;
    $channels = 1;
    $dataSize = strlen($rawAudio);
    $fileSize = 36 + $dataSize;
    
    $wavHeader = pack('a4Va4a4VvvVVa4V',
        'RIFF',                    // ChunkID
        $fileSize,                  // ChunkSize
        'WAVE',                     // Format
        'fmt ',                     // Subchunk1ID
        16,                         // Subchunk1Size (PCM)
        1,                          // AudioFormat (PCM)
        $channels,                  // NumChannels
        $sampleRate,                // SampleRate
        $sampleRate * $channels * ($bitsPerSample / 8), // ByteRate
        $channels * ($bitsPerSample / 8), // BlockAlign
        $bitsPerSample,             // BitsPerSample
        'data',                     // Subchunk2ID
        $dataSize                   // Subchunk2Size
    );
    
    // Write WAV file
    if (file_put_contents($filepath, $wavHeader . $rawAudio) === false) {
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
    } else {
        // Create standalone event
        $stmt = $db->prepare("
            INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity)
            VALUES (?, ?, 'AUDIO_RECORDING_ESP32', ?, 'LOW')
        ");
        $stmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
        $eventId = $db->lastInsertId();
    }
    
    sendResponse(true, "Audio uploaded successfully from ESP32", [
        'audio_path' => 'uploads/audio/' . $filename,
        'event_id' => $eventId
    ], 200);
}

