<?php
/**
 * SAARTHI Backend - AI Behavioral Pattern Learning API
 * POST /api/ai/learnUserPatterns.php
 * Learns user behavior patterns for personalization
 * For Mumbai Hackathon - Health IoT Project
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$userId = $data['user_id'] ?? $user['user_id'];
$learningPeriod = $data['learning_period'] ?? '30_days';

// Learn user patterns
$patterns = learnUserPatterns($userId, $learningPeriod, $db);

sendResponse(true, "User patterns learned", $patterns, 200);

function learnUserPatterns($userId, $period, $db) {
    // Get activity patterns from events
    $stmt = $db->prepare("
        SELECT 
            HOUR(created_at) as hour,
            DAYOFWEEK(created_at) as day_of_week,
            event_type,
            COUNT(*) as frequency
        FROM sensor_events
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY HOUR(created_at), DAYOFWEEK(created_at), event_type
        ORDER BY frequency DESC
    ");
    $days = str_replace('_days', '', $period);
    $stmt->execute([$userId, $days]);
    $activityData = $stmt->fetchAll();
    
    // Get location patterns
    $stmt = $db->prepare("
        SELECT 
            latitude,
            longitude,
            COUNT(*) as visit_count,
            MAX(created_at) as last_visit
        FROM locations
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        GROUP BY ROUND(latitude, 3), ROUND(longitude, 3)
        ORDER BY visit_count DESC
        LIMIT 10
    ");
    $stmt->execute([$userId, $days]);
    $locationData = $stmt->fetchAll();
    
    // Analyze patterns
    $activityPatterns = analyzeActivityPatterns($activityData);
    $locationPatterns = analyzeLocationPatterns($locationData);
    $timePatterns = analyzeTimePatterns($activityData);
    
    // Identify habits
    $habits = identifyHabits($activityPatterns, $locationPatterns, $timePatterns);
    
    return [
        'activity_patterns' => $activityPatterns,
        'location_patterns' => $locationPatterns,
        'time_patterns' => $timePatterns,
        'pattern_confidence' => calculateConfidence($activityData, $locationData),
        'identified_habits' => $habits,
    ];
}

function analyzeActivityPatterns($data) {
    $patterns = [];
    foreach ($data as $row) {
        $key = $row['hour'] . '_' . $row['day_of_week'];
        if (!isset($patterns[$key])) {
            $patterns[$key] = [];
        }
        $patterns[$key][$row['event_type']] = $row['frequency'];
    }
    return $patterns;
}

function analyzeLocationPatterns($data) {
    $patterns = [];
    foreach ($data as $row) {
        $patterns[] = [
            'lat' => floatval($row['latitude']),
            'lng' => floatval($row['longitude']),
            'visit_count' => intval($row['visit_count']),
            'last_visit' => $row['last_visit'],
        ];
    }
    return $patterns;
}

function analyzeTimePatterns($data) {
    $hourlyPattern = [];
    foreach ($data as $row) {
        $hour = intval($row['hour']);
        if (!isset($hourlyPattern[$hour])) {
            $hourlyPattern[$hour] = 0;
        }
        $hourlyPattern[$hour] += intval($row['frequency']);
    }
    return ['hourly' => $hourlyPattern];
}

function identifyHabits($activity, $location, $time) {
    $habits = [];
    
    // Identify frequent routes
    if (count($location) >= 3) {
        $habits[] = 'Frequent routes identified';
    }
    
    // Identify time-based patterns
    if (isset($time['hourly'])) {
        $maxHour = array_search(max($time['hourly']), $time['hourly']);
        if ($maxHour !== false) {
            $habits[] = "Most active around {$maxHour}:00";
        }
    }
    
    return $habits;
}

function calculateConfidence($activityData, $locationData) {
    $totalDataPoints = count($activityData) + count($locationData);
    return min($totalDataPoints / 100.0, 1.0); // Normalize to 0-1
}

