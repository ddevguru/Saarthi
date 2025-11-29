<?php
/**
 * SAARTHI Backend - AI Emergency Assessment API
 * POST /api/ai/assessEmergency.php
 * Advanced emergency situation detection using AI
 * For Mumbai Hackathon - Health IoT Project
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$sensorData = $data['sensor_data'] ?? [];
$imageUrl = $data['image_url'] ?? null;
$audioUrl = $data['audio_url'] ?? null;

// AI Emergency Assessment
$assessment = performEmergencyAssessment($sensorData, $imageUrl, $audioUrl, $db, $user['user_id']);

sendResponse(true, "Emergency assessment completed", $assessment, 200);

function performEmergencyAssessment($sensorData, $imageUrl, $audioUrl, $db, $userId) {
    $emergencyScore = 0.0;
    $indicators = [];
    $emergencyType = 'unknown';
    $recommendedAction = 'Monitor situation';
    
    // Analyze sensor data
    if (isset($sensorData['distance'])) {
        $distance = floatval($sensorData['distance']);
        if ($distance < 10 || ($distance >= 50 && $distance <= 100)) {
            $emergencyScore += 0.3;
            $indicators[] = 'Obstacle detected at ' . round($distance, 1) . ' cm';
        }
    }
    
    if (isset($sensorData['touch']) && $sensorData['touch'] == 1) {
        $emergencyScore += 0.5;
        $indicators[] = 'Touch sensor activated';
        $emergencyType = 'manual_trigger';
    }
    
    if (isset($sensorData['mic'])) {
        $micValue = intval($sensorData['mic']);
        if ($micValue > 3000) {
            $emergencyScore += 0.2;
            $indicators[] = 'Loud sound detected';
        }
    }
    
    // Analyze image if available
    if ($imageUrl) {
        $imageAnalysis = analyzeEmergencyImage($imageUrl);
        if ($imageAnalysis['has_emergency']) {
            $emergencyScore += 0.3;
            $indicators[] = $imageAnalysis['indicator'];
        }
    }
    
    // Analyze audio if available
    if ($audioUrl) {
        $audioAnalysis = analyzeEmergencyAudio($audioUrl);
        if ($audioAnalysis['has_distress']) {
            $emergencyScore += 0.4;
            $indicators[] = 'Distress signals detected in audio';
            $emergencyType = 'distress';
        }
    }
    
    // Determine if emergency
    $isEmergency = $emergencyScore >= 0.5;
    
    if ($isEmergency) {
        if ($emergencyScore >= 0.8) {
            $recommendedAction = 'IMMEDIATE ACTION REQUIRED: Contact emergency services and notify guardians';
        } else {
            $recommendedAction = 'Alert guardians and monitor closely';
        }
    }
    
    return [
        'is_emergency' => $isEmergency,
        'emergency_score' => min($emergencyScore, 1.0),
        'emergency_type' => $emergencyType,
        'confidence' => min($emergencyScore * 1.2, 1.0),
        'indicators' => $indicators,
        'recommended_action' => $recommendedAction,
    ];
}

function analyzeEmergencyImage($imageUrl) {
    // Simulate image analysis for emergency detection
    // In production, use ML models for object detection
    return [
        'has_emergency' => false,
        'indicator' => 'Image analysis unavailable',
    ];
}

function analyzeEmergencyAudio($audioUrl) {
    // Simulate audio analysis for distress detection
    // In production, use audio ML models
    return [
        'has_distress' => false,
        'distress_level' => 0.0,
    ];
}

