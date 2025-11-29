<?php
/**
 * SAARTHI Backend - AI Behavior Anomaly Detection API
 * POST /api/ai/detectBehaviorAnomaly.php
 * Detects anomalies in user behavior patterns
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$userId = $data['user_id'] ?? $user['user_id'];

// Detect behavior anomaly
$anomaly = detectBehaviorAnomaly($userId, $db);

sendResponse(true, "Behavior anomaly detection completed", $anomaly, 200);

function detectBehaviorAnomaly($userId, $db) {
    $hasAnomaly = false;
    $anomalyType = 'unknown';
    $description = '';
    $severity = 0.0;
    
    // Get recent activity
    $stmt = $db->prepare("
        SELECT 
            event_type,
            created_at,
            HOUR(created_at) as hour
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ORDER BY created_at DESC
    ");
    $stmt->execute([$userId]);
    $recentActivity = $stmt->fetchAll();
    
    // Compare with historical patterns
    $stmt = $db->prepare("
        SELECT 
            AVG(COUNT(*)) as avg_events,
            HOUR(created_at) as hour
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY HOUR(created_at)
    ");
    $stmt->execute([$userId]);
    $historicalPatterns = $stmt->fetchAll();
    
    // Detect anomalies
    $currentHour = (int)date('H');
    $currentEventCount = count($recentActivity);
    
    foreach ($historicalPatterns as $pattern) {
        if ($pattern['hour'] == $currentHour) {
            $avgEvents = floatval($pattern['avg_events']);
            if ($currentEventCount > ($avgEvents * 2)) {
                $hasAnomaly = true;
                $anomalyType = 'unusual_activity_spike';
                $description = "Unusually high activity detected. {$currentEventCount} events vs average {$avgEvents}";
                $severity = min(($currentEventCount / $avgEvents) / 3.0, 1.0);
                break;
            }
        }
    }
    
    // Check for missing activity
    if ($currentEventCount == 0 && !empty($historicalPatterns)) {
        $hasAnomaly = true;
        $anomalyType = 'missing_activity';
        $description = 'No activity detected when activity is normally expected';
        $severity = 0.5;
    }
    
    return [
        'has_anomaly' => $hasAnomaly,
        'anomaly_type' => $anomalyType,
        'description' => $description,
        'severity' => $severity,
        'detected_at' => date('Y-m-d H:i:s'),
    ];
}

