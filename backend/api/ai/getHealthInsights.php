<?php
/**
 * SAARTHI Backend - AI Health Insights API
 * POST /api/ai/getHealthInsights.php
 * Provides health insights based on activity patterns
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$userId = $data['user_id'] ?? $user['user_id'];
$period = $data['period'] ?? '7_days';

$days = str_replace('_days', '', $period);

// Get health insights
$insights = generateHealthInsights($userId, $days, $db);

sendResponse(true, "Health insights generated", $insights, 200);

function generateHealthInsights($userId, $days, $db) {
    // Get event statistics
    $stmt = $db->prepare("
        SELECT 
            COUNT(*) as total_events,
            SUM(CASE WHEN severity IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) as emergency_events,
            AVG(CASE 
                WHEN severity = 'LOW' THEN 0.2
                WHEN severity = 'MEDIUM' THEN 0.5
                WHEN severity = 'HIGH' THEN 0.8
                WHEN severity = 'CRITICAL' THEN 1.0
                ELSE 0.0
            END) as avg_risk_level
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    ");
    $stmt->execute([$userId, $days]);
    $stats = $stmt->fetch();
    
    // Calculate activity score
    $totalEvents = intval($stats['total_events'] ?? 0);
    $activityScore = min($totalEvents / ($days * 10.0), 1.0); // Normalize
    
    // Generate insights
    $insights = [];
    
    if ($totalEvents == 0) {
        $insights[] = 'No activity recorded in the selected period.';
    } else {
        $emergencyEvents = intval($stats['emergency_events'] ?? 0);
        $avgRisk = floatval($stats['avg_risk_level'] ?? 0.0);
        
        if ($emergencyEvents > 0) {
            $insights[] = "{$emergencyEvents} emergency situation(s) detected. Stay vigilant.";
        }
        
        if ($avgRisk > 0.7) {
            $insights[] = 'Average risk level is high. Consider reviewing your routes and safety measures.';
        } elseif ($avgRisk < 0.3) {
            $insights[] = 'Low risk levels detected. Good safety practices observed.';
        }
        
        $insights[] = "Total of {$totalEvents} events recorded, indicating active monitoring.";
    }
    
    // Identify patterns
    $patterns = [];
    $stmt = $db->prepare("
        SELECT event_type, COUNT(*) as count
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY event_type
        ORDER BY count DESC
        LIMIT 5
    ");
    $stmt->execute([$userId, $days]);
    $eventPatterns = $stmt->fetchAll();
    
    foreach ($eventPatterns as $pattern) {
        $patterns[$pattern['event_type']] = intval($pattern['count']);
    }
    
    return [
        'activity_score' => $activityScore,
        'total_events' => $totalEvents,
        'emergency_events' => intval($stats['emergency_events'] ?? 0),
        'average_risk_level' => floatval($stats['avg_risk_level'] ?? 0.0),
        'insights' => $insights,
        'patterns' => $patterns,
    ];
}

