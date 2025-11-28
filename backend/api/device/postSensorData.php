<?php
/**
 * SAARTHI Backend - Post Sensor Data API
 * POST /api/device/postSensorData
 * Called by ESP32-CAM to send sensor readings
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../services/whatsapp_service.php';
require_once __DIR__ . '/../../services/geofence_service.php';

$db = (new Database())->getConnection();

// Accept both GET (for ESP32 simplicity) and POST
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $data = $_GET;
} else {
    $data = getRequestBody();
}

// Required: device_id, user_id (optional, can be derived from device_id)
validateRequired($data, ['device_id']);

$deviceId = trim($data['device_id']);
$distance = floatval($data['distance'] ?? -1);
$touch = intval($data['touch'] ?? 0);
$touchType = trim($data['touch_type'] ?? ''); // 'SINGLE', 'DOUBLE', 'LONG_PRESS'
$micRaw = intval($data['mic'] ?? 0);
$userId = isset($data['user_id']) ? trim($data['user_id'], '"\'') : null; // Remove quotes if present

// Get device info
$stmt = $db->prepare("SELECT id, user_id, status FROM devices WHERE device_id = ?");
$stmt->execute([$deviceId]);
$device = $stmt->fetch();

if (!$device) {
    sendResponse(false, "Device not found. Please register device first.", null, 404);
}

$userId = $userId ?? $device['user_id'];
$deviceDbId = $device['id'];

// Get IP address and stream URL from request
$ipAddress = trim($data['ip_address'] ?? '');
$streamUrl = trim($data['stream_url'] ?? '');

// URL decode the stream URL if it's encoded
if (!empty($streamUrl)) {
    $streamUrl = urldecode($streamUrl);
}

// Update device last_seen, IP address, and stream URL
if ($ipAddress || $streamUrl) {
    if ($ipAddress && $streamUrl) {
        $stmt = $db->prepare("UPDATE devices SET last_seen = NOW(), status = 'ONLINE', ip_address = ?, stream_url = ? WHERE id = ?");
        $stmt->execute([$ipAddress, $streamUrl, $deviceDbId]);
    } else if ($ipAddress) {
        // Build stream URL from IP if not provided
        $streamUrl = "http://$ipAddress:81/stream";
        $stmt = $db->prepare("UPDATE devices SET last_seen = NOW(), status = 'ONLINE', ip_address = ?, stream_url = ? WHERE id = ?");
        $stmt->execute([$ipAddress, $streamUrl, $deviceDbId]);
    } else if ($streamUrl) {
        $stmt = $db->prepare("UPDATE devices SET last_seen = NOW(), status = 'ONLINE', stream_url = ? WHERE id = ?");
        $stmt->execute([$streamUrl, $deviceDbId]);
    }
} else {
    // Just update last_seen and status
    $stmt = $db->prepare("UPDATE devices SET last_seen = NOW(), status = 'ONLINE' WHERE id = ?");
    $stmt->execute([$deviceDbId]);
}

// Get sensor thresholds
$stmt = $db->prepare("
    SELECT ultrasonic_min_distance, mic_loud_threshold, night_mode_enabled
    FROM sensor_thresholds
    WHERE user_id = ? AND (device_id = ? OR device_id IS NULL)
    ORDER BY device_id DESC
    LIMIT 1
");
$stmt->execute([$userId, $deviceDbId]);
$thresholds = $stmt->fetch() ?: [
    'ultrasonic_min_distance' => 30.0,
    'mic_loud_threshold' => 2000,
    'night_mode_enabled' => false
];

$eventType = null;
$severity = 'LOW';
$sensorPayload = json_encode([
    'distance' => $distance,
    'touch' => $touch,
    'touch_type' => $touchType,
    'mic_raw' => $micRaw,
    'timestamp' => date('Y-m-d H:i:s')
]);

// Check for obstacles - Alert for 50-100cm range, NO alerts for 10-30cm
// User requirement: Alert when object is far (50-100cm), not when too close (10-30cm)
if ($distance > 0) {
    // Check if obstacle alert was recently sent (avoid spam)
    $stmt = $db->prepare("
        SELECT id, created_at FROM sensor_events
        WHERE user_id = ? 
        AND device_id = ?
        AND event_type = 'OBSTACLE_ALERT'
        AND created_at > DATE_SUB(NOW(), INTERVAL 10 SECOND)
        ORDER BY created_at DESC LIMIT 1
    ");
    $stmt->execute([$userId, $deviceDbId]);
    $recentAlert = $stmt->fetch();
    
    // Alert logic: 20cm range = alert, 50-100cm = alert
    $shouldAlert = false;
    if ($distance >= 50 && $distance <= 100) {
        // Alert for far objects (50-100cm)
        if (!$recentAlert) {
            $shouldAlert = true;
        }
    } else if ($distance >= 20 && $distance <= 30) {
        // Alert for 20cm range objects - user requirement
        if (!$recentAlert) {
            $shouldAlert = true;
        }
    } else if ($distance >= 10 && $distance < 20) {
        // NO alert for 10-20cm range (too close, might be false positive)
        $shouldAlert = false;
    } else if ($distance > 100) {
        // No alert for very far objects
        $shouldAlert = false;
    } else if ($distance < 10) {
        // Alert for very close objects (<10cm) - critical
        $shouldAlert = true;
    }
    
    if ($shouldAlert) {
        $eventType = 'OBSTACLE_ALERT';
        // Severity based on distance
        if ($distance < 10) {
            $severity = 'CRITICAL';
        } else if ($distance >= 20 && $distance <= 30) {
            $severity = 'HIGH'; // 20cm range is high priority
        } else if ($distance >= 50 && $distance <= 100) {
            $severity = 'MEDIUM';
        } else {
            $severity = 'LOW';
        }
        
        // Always trigger audio recording and photo capture for obstacle alerts
        $triggerRecording = true;
        $triggerPhotoCapture = true;
        
        $sensorPayload = json_encode([
            'distance' => $distance,
            'touch' => $touch,
            'touch_type' => $touchType,
            'mic_raw' => $micRaw,
            'trigger_audio_recording' => $triggerRecording,
            'trigger_photo_capture' => $triggerPhotoCapture,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
}

// Check for loud sounds
if ($micRaw > $thresholds['mic_loud_threshold']) {
    $eventType = 'LOUD_SOUND_ALERT';
    $severity = ($micRaw > 3500) ? 'HIGH' : 'MEDIUM';
}

// Check for touch gestures
if ($touch == 1) {
    if ($touchType === 'LONG_PRESS') {
        $eventType = 'LONG_PRESS_EMERGENCY';
        $severity = 'CRITICAL';
    } elseif ($touchType === 'DOUBLE') {
        $eventType = 'DOUBLE_TAP_MUSIC';
        $severity = 'LOW';
    } elseif ($touchType === 'SINGLE') {
        $eventType = 'SINGLE_TAP_VOICE';
        $severity = 'LOW';
    } else {
        // Default to SOS if no type specified
        $eventType = 'SOS_TOUCH';
        $severity = 'CRITICAL';
    }
}

// Store event if detected
if ($eventType) {
    $stmt = $db->prepare("
        INSERT INTO sensor_events (user_id, device_id, event_type, sensor_payload, severity)
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt->execute([$userId, $deviceDbId, $eventType, $sensorPayload, $severity]);
    $eventId = $db->lastInsertId();
    
    // Return event_id in response for photo/audio linking
    $responseData = [
        'event_triggered' => true,
        'event_type' => $eventType,
        'severity' => $severity,
        'event_id' => $eventId
    ];
    
    // Trigger alerts for critical/high events
    if (in_array($severity, ['HIGH', 'CRITICAL'])) {
        $whatsappService = new WhatsAppService($db);
        $geofenceService = new GeofenceService($db);
        
        // Get user info
        $stmt = $db->prepare("SELECT name, phone FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();
        
        // Get latest location
        $stmt = $db->prepare("
            SELECT latitude, longitude FROM locations
            WHERE user_id = ?
            ORDER BY created_at DESC LIMIT 1
        ");
        $stmt->execute([$userId]);
        $location = $stmt->fetch();
        
        // Check geofence
        $geofenceService->checkGeofence($userId, $location['latitude'] ?? null, $location['longitude'] ?? null);
        
        // Send WhatsApp alert to parents
        $message = "🚨 SAARTHI Alert\n\n";
        $message .= "User: " . $user['name'] . "\n";
        $message .= "Event: " . $eventType . "\n";
        $message .= "Severity: " . $severity . "\n";
        $message .= "Time: " . date('Y-m-d H:i:s') . "\n";
        
        if ($location) {
            $mapsUrl = "https://www.google.com/maps?q=" . $location['latitude'] . "," . $location['longitude'];
            $message .= "Location: " . $mapsUrl . "\n";
        }
        
        // Get parent phone numbers
        $stmt = $db->prepare("
            SELECT u.phone FROM users u
            INNER JOIN parent_child_links pcl ON u.id = pcl.parent_id
            WHERE pcl.child_id = ? AND pcl.status = 'ACTIVE'
        ");
        $stmt->execute([$userId]);
        $parents = $stmt->fetchAll();
        
        // Also get emergency contacts (handle both with and without is_active column)
        $emergencyContacts = [];
        try {
            // Try with is_active column first
            $stmt = $db->prepare("
                SELECT phone FROM emergency_contacts
                WHERE user_id = ? AND is_active = 1
            ");
            $stmt->execute([$userId]);
            $emergencyContacts = $stmt->fetchAll();
        } catch (PDOException $e) {
            // If is_active column doesn't exist, try without it
            try {
                $stmt = $db->prepare("
                    SELECT phone FROM emergency_contacts
                    WHERE user_id = ?
                ");
                $stmt->execute([$userId]);
                $emergencyContacts = $stmt->fetchAll();
            } catch (PDOException $e2) {
                // Table might not exist, log but continue
                error_log("Emergency contacts error: " . $e2->getMessage());
            }
        }
        
        // Combine all contacts
        $allContacts = array_merge($parents, $emergencyContacts);
        
        // Send to all contacts (parents + emergency contacts)
        foreach ($allContacts as $contact) {
            $whatsappService->sendMessage($contact['phone'], $message, $userId, $eventId);
        }
    }
}

// Return response with event info if event was created
if (isset($responseData)) {
    sendResponse(true, "Sensor data received", $responseData, 200);
} else {
    sendResponse(true, "Sensor data received", [
        'event_triggered' => false
    ], 200);
}

sendResponse(true, "Sensor data received", [
    'event_triggered' => $eventType !== null,
    'event_type' => $eventType,
    'severity' => $severity
], 200);

