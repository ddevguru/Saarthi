<?php
/**
 * SAARTHI Backend - Upload Audio from ESP32-CAM API
 * POST /api/device/uploadAudioFromESP32
 * Called by ESP32-CAM to upload audio recordings from external microphone
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();

// Log incoming request
error_log("=== AUDIO UPLOAD REQUEST ===");
error_log("Request method: " . $_SERVER['REQUEST_METHOD']);
error_log("Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
error_log("POST data: " . print_r($_POST, true));
error_log("FILES data: " . print_r($_FILES, true));

// Accept multipart/form-data or raw audio data
$deviceId = $_POST['device_id'] ?? $_GET['device_id'] ?? null;
$eventId = $_POST['event_id'] ?? $_GET['event_id'] ?? null;
$userId = $_POST['user_id'] ?? $_GET['user_id'] ?? null;

error_log("Device ID: " . ($deviceId ?? 'null'));
error_log("Event ID: " . ($eventId ?? 'null'));
error_log("User ID: " . ($userId ?? 'null'));

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
    error_log("Processing multipart audio upload");
    $file = $_FILES['audio'];
    $allowedExtensions = ['wav', 'raw', 'pcm'];
    $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    
    // If no extension, assume raw/PCM from ESP32
    if (empty($fileExtension)) {
        $fileExtension = 'raw';
    }
    
    if (!in_array($fileExtension, $allowedExtensions)) {
        error_log("Invalid file extension: $fileExtension, File name: " . $file['name']);
        sendResponse(false, "Invalid file type. Allowed: wav, raw, pcm. Got: $fileExtension", null, 400);
    }
    
    $maxSize = 10 * 1024 * 1024; // 10MB (increased for 1 minute audio)
    if ($file['size'] > $maxSize) {
        error_log("File too large: " . $file['size'] . " bytes, Max: $maxSize");
        sendResponse(false, "File too large. Max 10MB", null, 400);
    }
    
    error_log("Audio upload received: Name=" . $file['name'] . ", Size=" . $file['size'] . ", Type=" . $file['type'] . ", Extension=$fileExtension");
    
    // Ensure upload directory exists and is writable
    if (!file_exists(UPLOAD_AUDIO_DIR)) {
        if (!mkdir(UPLOAD_AUDIO_DIR, 0755, true)) {
            error_log("Failed to create upload audio directory: " . UPLOAD_AUDIO_DIR);
            sendResponse(false, "Failed to create upload directory", null, 500);
        }
    }
    
    if (!is_writable(UPLOAD_AUDIO_DIR)) {
        error_log("Upload audio directory is not writable: " . UPLOAD_AUDIO_DIR);
        sendResponse(false, "Upload directory is not writable", null, 500);
    }
    
    // Generate unique filename (convert to WAV for compatibility)
    $filename = 'audio_esp32_' . $deviceId . '_' . time() . '_' . uniqid() . '.wav';
    $filepath = UPLOAD_AUDIO_DIR . $filename;
    
    error_log("Attempting to save audio: $filepath, Size: " . $file['size'] . " bytes");
    
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
        $writeResult = file_put_contents($filepath, $wavHeader . $rawData);
        if ($writeResult === false) {
            $error = error_get_last();
            error_log("Failed to write WAV file: " . ($error ? $error['message'] : 'Unknown error'));
            sendResponse(false, "Failed to save audio file: " . ($error ? $error['message'] : 'Unknown error'), null, 500);
        }
        error_log("WAV file created successfully: $filepath, Size: $writeResult bytes");
    } else {
        // Direct copy for WAV files
        if (!move_uploaded_file($file['tmp_name'], $filepath)) {
            $error = error_get_last();
            error_log("Failed to move uploaded audio file: " . ($error ? $error['message'] : 'Unknown error'));
            error_log("Upload error code: " . $file['error']);
            error_log("Temp file: " . $file['tmp_name']);
            error_log("Target path: " . $filepath);
            sendResponse(false, "Failed to save audio file: " . ($error ? $error['message'] : 'Unknown error'), null, 500);
        }
        error_log("Audio file moved successfully: $filepath");
    }
    
    // Verify file was saved
    if (!file_exists($filepath)) {
        error_log("Audio file was not saved: $filepath");
        sendResponse(false, "Audio file was not saved", null, 500);
    }
    
    // Update event with audio path if event_id provided
    $updateSuccess = false;
    if ($eventId) {
        // Convert eventId to integer for database query
        $eventIdInt = intval($eventId);
        error_log("Attempting to update event $eventIdInt (original: $eventId) with audio path");
        
        $stmt = $db->prepare("
            UPDATE sensor_events
            SET audio_path = ?
            WHERE id = ? AND user_id = ?
        ");
        $result = $stmt->execute(['uploads/audio/' . $filename, $eventIdInt, $userId]);
        
        if ($result && $stmt->rowCount() > 0) {
            error_log("✓ Successfully updated event $eventIdInt with audio path: uploads/audio/$filename");
            $updateSuccess = true;
        } else {
            error_log("⚠️ Warning: Event $eventIdInt not found or not updated. Rows affected: " . $stmt->rowCount());
            error_log("Event ID (int): $eventIdInt, Event ID (original): $eventId, User ID: $userId, Audio Path: uploads/audio/$filename");
            error_log("SQL Error Info: " . print_r($stmt->errorInfo(), true));
            
            // Try to find the event
            $checkStmt = $db->prepare("SELECT id, event_type, created_at FROM sensor_events WHERE id = ? AND user_id = ?");
            $checkStmt->execute([$eventIdInt, $userId]);
            $eventCheck = $checkStmt->fetch();
            if ($eventCheck) {
                error_log("Event exists but UPDATE failed. Event details: " . print_r($eventCheck, true));
                // Retry UPDATE
                $retryStmt = $db->prepare("UPDATE sensor_events SET audio_path = ? WHERE id = ? AND user_id = ?");
                $retryResult = $retryStmt->execute(['uploads/audio/' . $filename, $eventIdInt, $userId]);
                if ($retryResult && $retryStmt->rowCount() > 0) {
                    error_log("✓ Successfully updated event $eventIdInt with audio path (retry)");
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
            // EventId was provided but UPDATE failed - try to link to most recent event without audio
            $eventIdInt = intval($eventId);
            error_log("Trying to link audio to most recent event for user $userId");
            
            // Find most recent event without audio_path for this user/device
            $linkStmt = $db->prepare("
                SELECT id FROM sensor_events 
                WHERE user_id = ? AND device_id = ? 
                AND (audio_path IS NULL OR audio_path = '')
                ORDER BY created_at DESC 
                LIMIT 1
            ");
            $linkStmt->execute([$userId, $deviceDbId]);
            $recentEvent = $linkStmt->fetch();
            
            if ($recentEvent) {
                $linkEventId = $recentEvent['id'];
                error_log("Found recent event $linkEventId without audio, linking audio to it");
                $linkUpdateStmt = $db->prepare("UPDATE sensor_events SET audio_path = ? WHERE id = ? AND user_id = ?");
                $linkResult = $linkUpdateStmt->execute(['uploads/audio/' . $filename, $linkEventId, $userId]);
                if ($linkResult && $linkUpdateStmt->rowCount() > 0) {
                    error_log("✓ Successfully linked audio to event $linkEventId");
                    $eventId = $linkEventId;
                    $updateSuccess = true;
                }
            }
            
            // If still failed, create new event
            if (!$updateSuccess) {
                error_log("Creating new event for audio since linking failed");
                $newStmt = $db->prepare("
                    INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity, created_at)
                    VALUES (?, ?, 'AUDIO_RECORDING_ESP32', ?, 'LOW', NOW())
                ");
                $newResult = $newStmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
                if ($newResult) {
                    $newEventId = $db->lastInsertId();
                    error_log("Created new event $newEventId for audio: uploads/audio/$filename");
                    $eventId = $newEventId;
                } else {
                    error_log("ERROR: Failed to create event for audio");
                    error_log("SQL Error Info: " . print_r($newStmt->errorInfo(), true));
                }
            }
        } else {
            // No eventId provided - create standalone event
            $newStmt = $db->prepare("
                INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity, created_at)
                VALUES (?, ?, 'AUDIO_RECORDING_ESP32', ?, 'LOW', NOW())
            ");
            $newResult = $newStmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
            
            if ($newResult) {
                $eventId = $db->lastInsertId();
                error_log("Created new event $eventId for audio: uploads/audio/$filename");
            } else {
                error_log("ERROR: Failed to create event for audio");
                error_log("SQL Error Info: " . print_r($newStmt->errorInfo(), true));
                error_log("User ID: $userId, Device DB ID: $deviceDbId, Audio Path: uploads/audio/$filename");
            }
        }
    }
    
    $fileSize = filesize($filepath);
    $fileExists = file_exists($filepath);
    
    error_log("=== AUDIO UPLOAD SUCCESS (MULTIPART) ===");
    error_log("Audio Path: uploads/audio/$filename");
    error_log("Full File Path: $filepath");
    error_log("File Size: $fileSize bytes");
    error_log("File Exists: " . ($fileExists ? 'Yes' : 'No'));
    error_log("Event ID: " . ($eventId ?? 'null'));
    error_log("User ID: $userId");
    error_log("Device ID: $deviceId");
    error_log("Device DB ID: $deviceDbId");
    error_log("==========================================");
    
    sendResponse(true, "Audio uploaded successfully from ESP32", [
        'audio_path' => 'uploads/audio/' . $filename,
        'event_id' => $eventId,
        'file_size' => $fileSize,
        'file_exists' => $fileExists
    ], 200);
} else {
    // Try to accept raw audio data in POST body
    error_log("No multipart audio file, trying raw POST body");
    $rawAudio = file_get_contents('php://input');
    $rawAudioSize = strlen($rawAudio);
    error_log("Raw audio data size: $rawAudioSize bytes");
    
    if (empty($rawAudio) || $rawAudioSize < 100) {
        error_log("ERROR: No audio data received or too small. Size: $rawAudioSize");
        sendResponse(false, "No audio data received (size: $rawAudioSize bytes)", null, 400);
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
    
    // Ensure upload directory exists and is writable
    if (!file_exists(UPLOAD_AUDIO_DIR)) {
        if (!mkdir(UPLOAD_AUDIO_DIR, 0755, true)) {
            error_log("Failed to create upload audio directory: " . UPLOAD_AUDIO_DIR);
            sendResponse(false, "Failed to create upload directory", null, 500);
        }
    }
    
    if (!is_writable(UPLOAD_AUDIO_DIR)) {
        error_log("Upload audio directory is not writable: " . UPLOAD_AUDIO_DIR);
        sendResponse(false, "Upload directory is not writable", null, 500);
    }
    
    // Write WAV file
    $writeResult = file_put_contents($filepath, $wavHeader . $rawAudio);
    if ($writeResult === false) {
        $error = error_get_last();
        error_log("Failed to write WAV file from raw data: " . ($error ? $error['message'] : 'Unknown error'));
        sendResponse(false, "Failed to save audio file: " . ($error ? $error['message'] : 'Unknown error'), null, 500);
    }
    
    error_log("WAV file created from raw data: $filepath, Size: $writeResult bytes");
    
    // Verify file was saved
    if (!file_exists($filepath)) {
        error_log("Audio file was not saved: $filepath");
        sendResponse(false, "Audio file was not saved", null, 500);
    }
    
    // Update event with audio path if event_id provided (RAW DATA)
    $updateSuccess = false;
    if ($eventId) {
        // Convert eventId to integer for database query
        $eventIdInt = intval($eventId);
        error_log("Attempting to update event $eventIdInt (original: $eventId) with audio path (RAW DATA)");
        
        $stmt = $db->prepare("
            UPDATE sensor_events
            SET audio_path = ?
            WHERE id = ? AND user_id = ?
        ");
        $result = $stmt->execute(['uploads/audio/' . $filename, $eventIdInt, $userId]);
        
        if ($result && $stmt->rowCount() > 0) {
            error_log("✓ Successfully updated event $eventIdInt with audio path: uploads/audio/$filename");
            $updateSuccess = true;
        } else {
            error_log("⚠️ Warning: Event $eventIdInt not found or not updated. Rows affected: " . $stmt->rowCount());
            error_log("Event ID (int): $eventIdInt, Event ID (original): $eventId, User ID: $userId, Audio Path: uploads/audio/$filename");
            error_log("SQL Error Info: " . print_r($stmt->errorInfo(), true));
            
            // Try to find the event
            $checkStmt = $db->prepare("SELECT id, event_type, created_at FROM sensor_events WHERE id = ? AND user_id = ?");
            $checkStmt->execute([$eventIdInt, $userId]);
            $eventCheck = $checkStmt->fetch();
            if ($eventCheck) {
                error_log("Event exists but UPDATE failed. Event details: " . print_r($eventCheck, true));
                // Retry UPDATE
                $retryStmt = $db->prepare("UPDATE sensor_events SET audio_path = ? WHERE id = ? AND user_id = ?");
                $retryResult = $retryStmt->execute(['uploads/audio/' . $filename, $eventIdInt, $userId]);
                if ($retryResult && $retryStmt->rowCount() > 0) {
                    error_log("✓ Successfully updated event $eventIdInt with audio path (retry)");
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
            // EventId was provided but UPDATE failed - try to link to most recent event without audio
            $eventIdInt = intval($eventId);
            error_log("Trying to link audio to most recent event for user $userId (RAW DATA)");
            
            // Find most recent event without audio_path for this user/device
            $linkStmt = $db->prepare("
                SELECT id FROM sensor_events 
                WHERE user_id = ? AND device_id = ? 
                AND (audio_path IS NULL OR audio_path = '')
                ORDER BY created_at DESC 
                LIMIT 1
            ");
            $linkStmt->execute([$userId, $deviceDbId]);
            $recentEvent = $linkStmt->fetch();
            
            if ($recentEvent) {
                $linkEventId = $recentEvent['id'];
                error_log("Found recent event $linkEventId without audio, linking audio to it");
                $linkUpdateStmt = $db->prepare("UPDATE sensor_events SET audio_path = ? WHERE id = ? AND user_id = ?");
                $linkResult = $linkUpdateStmt->execute(['uploads/audio/' . $filename, $linkEventId, $userId]);
                if ($linkResult && $linkUpdateStmt->rowCount() > 0) {
                    error_log("✓ Successfully linked audio to event $linkEventId");
                    $eventId = $linkEventId;
                    $updateSuccess = true;
                }
            }
            
            // If still failed, create new event
            if (!$updateSuccess) {
                error_log("Creating new event for audio since linking failed (RAW DATA)");
                $newStmt = $db->prepare("
                    INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity, created_at)
                    VALUES (?, ?, 'AUDIO_RECORDING_ESP32', ?, 'LOW', NOW())
                ");
                $newResult = $newStmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
                if ($newResult) {
                    $newEventId = $db->lastInsertId();
                    error_log("Created new event $newEventId for audio: uploads/audio/$filename");
                    $eventId = $newEventId;
                } else {
                    error_log("ERROR: Failed to create event for audio");
                    error_log("SQL Error Info: " . print_r($newStmt->errorInfo(), true));
                }
            }
        } else {
            // No eventId provided - create standalone event
            $newStmt = $db->prepare("
                INSERT INTO sensor_events (user_id, device_id, event_type, audio_path, severity, created_at)
                VALUES (?, ?, 'AUDIO_RECORDING_ESP32', ?, 'LOW', NOW())
            ");
            $newResult = $newStmt->execute([$userId, $deviceDbId, 'uploads/audio/' . $filename]);
            
            if ($newResult) {
                $eventId = $db->lastInsertId();
                error_log("Created new event $eventId for audio: uploads/audio/$filename");
            } else {
                error_log("ERROR: Failed to create event for audio");
                error_log("SQL Error Info: " . print_r($newStmt->errorInfo(), true));
                error_log("User ID: $userId, Device DB ID: $deviceDbId, Audio Path: uploads/audio/$filename");
            }
        }
    }
    
    $fileSize = filesize($filepath);
    $fileExists = file_exists($filepath);
    
    error_log("=== AUDIO UPLOAD SUCCESS (RAW DATA) ===");
    error_log("Audio Path: uploads/audio/$filename");
    error_log("Full File Path: $filepath");
    error_log("File Size: $fileSize bytes");
    error_log("Raw Data Size: $rawAudioSize bytes");
    error_log("File Exists: " . ($fileExists ? 'Yes' : 'No'));
    error_log("Event ID: " . ($eventId ?? 'null'));
    error_log("User ID: $userId");
    error_log("Device ID: $deviceId");
    error_log("Device DB ID: $deviceDbId");
    error_log("=======================================");
    
    sendResponse(true, "Audio uploaded successfully from ESP32", [
        'audio_path' => 'uploads/audio/' . $filename,
        'event_id' => $eventId,
        'file_size' => $fileSize,
        'file_exists' => $fileExists
    ], 200);
}

