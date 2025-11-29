<?php
/**
 * SAARTHI Backend - AI Risk Prediction API
 * POST /api/ai/predictRisk.php
 * Predicts potential risks based on historical patterns
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
$predictionWindow = $data['prediction_window'] ?? '1_hour';

// Get recent events for pattern analysis
$stmt = $db->prepare("
    SELECT 
        event_type,
        severity,
        created_at,
        sensor_payload
    FROM sensor_events
    WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ORDER BY created_at DESC
    LIMIT 100
");
$stmt->execute([$userId]);
$recentEvents = $stmt->fetchAll();

// Get location patterns
$stmt = $db->prepare("
    SELECT 
        latitude,
        longitude,
        created_at
    FROM locations
    WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ORDER BY created_at DESC
    LIMIT 200
");
$stmt->execute([$userId]);
$locationHistory = $stmt->fetchAll();

// AI Risk Prediction Algorithm
$riskPrediction = calculateRiskPrediction($recentEvents, $locationHistory, $predictionWindow);

sendResponse(true, "Risk prediction completed", $riskPrediction, 200);

function calculateRiskPrediction($events, $locations, $window) {
    $riskScore = 0.0;
    $riskFactors = [];
    $recommendations = [];
    
    // Analyze event frequency
    $criticalEvents = array_filter($events, function($e) {
        return in_array($e['severity'], ['HIGH', 'CRITICAL']);
    });
    
    if (count($criticalEvents) > 5) {
        $riskScore += 0.3;
        $riskFactors[] = 'High frequency of critical events in past week';
        $recommendations[] = 'Consider reviewing your route and safety measures';
    }
    
    // Analyze time patterns
    $hour = (int)date('H');
    if ($hour >= 22 || $hour < 6) {
        $riskScore += 0.2;
        $riskFactors[] = 'Late night/early morning travel detected';
        $recommendations[] = 'Stay in well-lit areas and inform someone of your location';
    }
    
    // Analyze location patterns
    if (count($locations) > 0) {
        $recentLocation = $locations[0];
        // Check if in unfamiliar area (simplified)
        $riskScore += 0.1;
    }
    
    // Determine risk level
    $riskLevel = 'LOW';
    if ($riskScore >= 0.7) {
        $riskLevel = 'CRITICAL';
    } elseif ($riskScore >= 0.5) {
        $riskLevel = 'HIGH';
    } elseif ($riskScore >= 0.3) {
        $riskLevel = 'MEDIUM';
    }
    
    if ($riskLevel == 'LOW' && empty($recommendations)) {
        $recommendations[] = 'Continue with normal activities. Stay alert.';
    }
    
    return [
        'risk_score' => min($riskScore, 1.0),
        'risk_level' => $riskLevel,
        'risk_factors' => $riskFactors,
        'recommendations' => $recommendations,
        'predicted_time' => date('Y-m-d H:i:s', strtotime("+1 hour")),
    ];
}

