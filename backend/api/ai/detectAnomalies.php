<?php
/**
 * SAARTHI Backend - AI Anomaly Detection API
 * POST /api/ai/detectAnomalies.php
 * Detects anomalies in user behavior and sensor data
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$userId = $data['user_id'] ?? $user['user_id'];
$timeWindow = $data['time_window'] ?? '24_hours';

// Detect anomalies
$anomalies = detectAnomalies($userId, $timeWindow, $db);

sendResponse(true, "Anomaly detection completed", $anomalies, 200);

function detectAnomalies($userId, $window, $db) {
    $anomalies = [];
    
    // Get recent events
    $hours = str_replace('_hours', '', $window);
    $stmt = $db->prepare("
        SELECT 
            event_type,
            severity,
            created_at,
            sensor_payload
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        ORDER BY created_at DESC
    ");
    $stmt->execute([$userId, $hours]);
    $events = $stmt->fetchAll();
    
    // Detect unusual patterns
    $eventCount = count($events);
    $criticalCount = 0;
    $recentTime = null;
    
    foreach ($events as $event) {
        if (in_array($event['severity'], ['HIGH', 'CRITICAL'])) {
            $criticalCount++;
        }
        if (!$recentTime) {
            $recentTime = $event['created_at'];
        }
    }
    
    // Anomaly: Sudden spike in events
    if ($eventCount > 20) {
        $anomalies[] = [
            'type' => 'unusual_pattern',
            'description' => "Unusually high number of events ({$eventCount}) detected in the last {$hours} hours",
            'severity' => 0.6,
            'detected_at' => date('Y-m-d H:i:s'),
        ];
    }
    
    // Anomaly: Multiple critical events
    if ($criticalCount > 3) {
        $anomalies[] = [
            'type' => 'spike',
            'description' => "Multiple critical events ({$criticalCount}) detected. Immediate attention may be required.",
            'severity' => 0.8,
            'detected_at' => date('Y-m-d H:i:s'),
        ];
    }
    
    // Anomaly: No activity when expected
    if ($eventCount == 0 && $hours >= 12) {
        $anomalies[] = [
            'type' => 'missing_data',
            'description' => 'No activity detected for an extended period. Device may be offline.',
            'severity' => 0.4,
            'detected_at' => date('Y-m-d H:i:s'),
        ];
    }
    
    return [
        'has_anomalies' => !empty($anomalies),
        'anomalies' => $anomalies,
        'summary' => empty($anomalies) 
            ? 'No anomalies detected. Normal activity patterns observed.'
            : count($anomalies) . ' anomaly(ies) detected.',
    ];
}

