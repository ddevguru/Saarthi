<?php
/**
 * SAARTHI Backend - Emergency Alert API
 * POST /api/device/emergencyAlert.php
 * Called by Flutter app to trigger emergency alerts
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';
require_once __DIR__ . '/../../services/whatsapp_service.php';
require_once __DIR__ . '/../../services/geofence_service.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
validateRequired($data, ['event_type']);

$userId = $user['user_id'];
$eventType = trim($data['event_type']);
$deviceId = trim($data['device_id'] ?? '');

// Get device info
$deviceDbId = null;
if ($deviceId) {
    $stmt = $db->prepare("SELECT id FROM devices WHERE device_id = ? AND user_id = ?");
    $stmt->execute([$deviceId, $userId]);
    $device = $stmt->fetch();
    if ($device) {
        $deviceDbId = $device['id'];
    }
}

// Create emergency event
$severity = 'CRITICAL';
$sensorPayload = json_encode([
    'event_type' => $eventType,
    'triggered_by' => 'APP',
    'timestamp' => date('Y-m-d H:i:s')
]);

$stmt = $db->prepare("
    INSERT INTO sensor_events (user_id, device_id, event_type, sensor_payload, severity)
    VALUES (?, ?, ?, ?, ?)
");
$stmt->execute([$userId, $deviceDbId, $eventType, $sensorPayload, $severity]);
$eventId = $db->lastInsertId();

// Get user info
$stmt = $db->prepare("SELECT name, phone FROM users WHERE id = ?");
$stmt->execute([$userId]);
$userInfo = $stmt->fetch();

// Get latest location
$stmt = $db->prepare("
    SELECT latitude, longitude FROM locations
    WHERE user_id = ?
    ORDER BY created_at DESC LIMIT 1
");
$stmt->execute([$userId]);
$location = $stmt->fetch();

// Send WhatsApp alerts to parents and emergency contacts
$whatsappService = new WhatsAppService($db);
$geofenceService = new GeofenceService($db);

// Check geofence
if ($location) {
    $geofenceService->checkGeofence($userId, $location['latitude'] ?? null, $location['longitude'] ?? null);
}

// Prepare message
$message = "🚨 SAARTHI Emergency Alert\n\n";
$message .= "User: " . $userInfo['name'] . "\n";
$message .= "Event: " . $eventType . "\n";
$message .= "Time: " . date('d M Y, h:i A') . "\n";

if ($location) {
    $mapsUrl = "https://www.google.com/maps?q=" . $location['latitude'] . "," . $location['longitude'];
    $message .= "📍 Location: " . $mapsUrl . "\n";
}

$message .= "\nPlease check the SAARTHI app for details.";

// Get parent phone numbers
$stmt = $db->prepare("
    SELECT u.phone FROM users u
    INNER JOIN parent_child_links pcl ON u.id = pcl.parent_id
    WHERE pcl.child_id = ? AND pcl.status = 'ACTIVE'
");
$stmt->execute([$userId]);
$parents = $stmt->fetchAll();

// Get emergency contacts
$emergencyContacts = [];
try {
    $stmt = $db->prepare("
        SELECT phone FROM emergency_contacts
        WHERE user_id = ?
    ");
    $stmt->execute([$userId]);
    $emergencyContacts = $stmt->fetchAll();
} catch (PDOException $e) {
    error_log("Emergency contacts error: " . $e->getMessage());
}

// Combine all contacts
$allContacts = array_merge($parents, $emergencyContacts);

// Send to all contacts
foreach ($allContacts as $contact) {
    $whatsappService->sendMessage($contact['phone'], $message, $userId, $eventId);
}

sendResponse(true, "Emergency alert sent", [
    'event_id' => $eventId,
    'event_type' => $eventType,
    'severity' => $severity
], 200);
