<?php
/**
 * SAARTHI Backend - AI Fall Detection API
 * POST /api/ai/detectFall.php
 * Detects falls from sensor patterns
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$sensorData = $data['sensor_data'] ?? [];

// Detect fall
$fallDetection = detectFall($sensorData);

sendResponse(true, "Fall detection completed", $fallDetection, 200);

function detectFall($sensorData) {
    $hasFallen = false;
    $confidence = 0.0;
    $fallTime = null;
    $fallType = 'unknown';
    $impactForce = 0.0;
    
    // Fall detection algorithm
    // Check for sudden changes in sensor readings
    
    if (isset($sensorData['distance'])) {
        $distance = floatval($sensorData['distance']);
        // Sudden change in distance might indicate fall
        if ($distance < 5) {
            $hasFallen = true;
            $confidence = 0.7;
            $fallType = 'forward';
            $impactForce = 0.8;
            $fallTime = date('Y-m-d H:i:s');
        }
    }
    
    // Check for touch sensor activation (might indicate impact)
    if (isset($sensorData['touch']) && $sensorData['touch'] == 1) {
        if (!$hasFallen) {
            $hasFallen = true;
            $confidence = 0.5;
            $fallType = 'impact';
            $impactForce = 0.6;
            $fallTime = date('Y-m-d H:i:s');
        } else {
            $confidence = min($confidence + 0.2, 1.0);
        }
    }
    
    return [
        'has_fallen' => $hasFallen,
        'confidence' => $confidence,
        'fall_time' => $fallTime,
        'fall_type' => $fallType,
        'impact_force' => $impactForce,
    ];
}

