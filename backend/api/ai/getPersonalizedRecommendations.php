<?php
/**
 * SAARTHI Backend - AI Personalized Recommendations API
 * POST /api/ai/getPersonalizedRecommendations.php
 * Provides personalized recommendations based on user patterns
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$userId = $data['user_id'] ?? $user['user_id'];

// Get personalized recommendations
$recommendations = generatePersonalizedRecommendations($userId, $db);

sendResponse(true, "Personalized recommendations generated", [
    'recommendations' => $recommendations
], 200);

function generatePersonalizedRecommendations($userId, $db) {
    $recommendations = [];
    
    // Get user's recent activity
    $stmt = $db->prepare("
        SELECT event_type, severity, created_at
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ORDER BY created_at DESC
        LIMIT 20
    ");
    $stmt->execute([$userId]);
    $recentEvents = $stmt->fetchAll();
    
    // Analyze and generate recommendations
    $obstacleCount = 0;
    $emergencyCount = 0;
    
    foreach ($recentEvents as $event) {
        if ($event['event_type'] == 'OBSTACLE_ALERT') {
            $obstacleCount++;
        }
        if (in_array($event['severity'], ['HIGH', 'CRITICAL'])) {
            $emergencyCount++;
        }
    }
    
    // Generate recommendations based on patterns
    if ($obstacleCount > 5) {
        $recommendations[] = [
            'type' => 'safety',
            'title' => 'Frequent Obstacle Detection',
            'description' => 'You\'ve encountered multiple obstacles recently. Consider using a different route or being extra cautious.',
            'priority' => 4,
            'action' => 'Review your navigation settings',
        ];
    }
    
    if ($emergencyCount > 2) {
        $recommendations[] = [
            'type' => 'health',
            'title' => 'Multiple Emergency Events',
            'description' => 'Several emergency situations detected. Ensure your emergency contacts are updated.',
            'priority' => 5,
            'action' => 'Update emergency contacts',
        ];
    }
    
    // Time-based recommendations
    $hour = (int)date('H');
    if ($hour >= 20) {
        $recommendations[] = [
            'type' => 'safety',
            'title' => 'Evening Travel',
            'description' => 'It\'s getting late. Make sure you\'re heading to a safe location.',
            'priority' => 3,
            'action' => 'Share your location with a trusted contact',
        ];
    }
    
    // Default recommendation if none generated
    if (empty($recommendations)) {
        $recommendations[] = [
            'type' => 'general',
            'title' => 'Stay Safe',
            'description' => 'Your activity patterns look normal. Continue staying alert and safe.',
            'priority' => 2,
            'action' => 'Continue monitoring',
        ];
    }
    
    return $recommendations;
}

