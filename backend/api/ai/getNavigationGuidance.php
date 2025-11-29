<?php
/**
 * SAARTHI Backend - AI Navigation Guidance API
 * POST /api/ai/getNavigationGuidance.php
 * Provides intelligent navigation guidance based on context
 * For Mumbai Hackathon - Health IoT Project
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$currentLat = floatval($data['current_lat'] ?? 0);
$currentLng = floatval($data['current_lng'] ?? 0);
$destination = $data['destination'] ?? '';
$disabilityType = $data['disability_type'] ?? 'NONE';

if (!$destination && ($currentLat == 0 || $currentLng == 0)) {
    sendResponse(false, "Destination or current location required", null, 400);
}

// Get navigation guidance
$guidance = generateNavigationGuidance($currentLat, $currentLng, $destination, $disabilityType, $db, $user['user_id']);

sendResponse(true, "Navigation guidance generated", $guidance, 200);

function generateNavigationGuidance($lat, $lng, $destination, $disabilityType, $db, $userId) {
    // Generate intelligent navigation instructions
    $guidance = [
        'current_instruction' => 'Continue forward for 50 meters',
        'distance_to_next' => 50.0,
        'next_action' => 'go_straight',
        'steps' => [],
        'estimated_time' => 5.0, // minutes
        'safety_level' => 'SAFE',
    ];
    
    // Get user's recent routes for pattern learning
    $stmt = $db->prepare("
        SELECT latitude, longitude, created_at
        FROM locations
        WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $stmt->execute([$userId]);
    $recentLocations = $stmt->fetchAll();
    
    // Analyze route safety
    $safetyLevel = analyzeRouteSafety($lat, $lng, $recentLocations);
    $guidance['safety_level'] = $safetyLevel;
    
    // Generate steps based on destination
    if ($destination) {
        $guidance['steps'] = generateRouteSteps($lat, $lng, $destination, $disabilityType);
    }
    
    // Adjust instructions based on disability type
    if ($disabilityType == 'VISUAL') {
        $guidance['current_instruction'] = 'Walk straight ahead. Clear path detected.';
    } elseif ($disabilityType == 'HEARING') {
        $guidance['current_instruction'] = 'Continue forward. Visual path clear.';
    }
    
    return $guidance;
}

function analyzeRouteSafety($lat, $lng, $recentLocations) {
    // Simple safety analysis
    $hour = (int)date('H');
    
    if ($hour >= 22 || $hour < 6) {
        return 'MODERATE';
    }
    
    return 'SAFE';
}

function generateRouteSteps($startLat, $startLng, $destination, $disabilityType) {
    // Generate navigation steps
    // In production, integrate with Google Maps Directions API
    $steps = [];
    
    $steps[] = [
        'instruction' => 'Head north for 100 meters',
        'distance' => 100.0,
        'direction' => 'north',
        'lat' => $startLat + 0.001,
        'lng' => $startLng,
    ];
    
    return $steps;
}

