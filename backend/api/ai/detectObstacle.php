<?php
/**
 * SAARTHI Backend - AI Quick Obstacle Detection API
 * POST /api/ai/detectObstacle.php
 * Fast obstacle detection for real-time use
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$data = getRequestBody();
$imageUrl = $data['image_url'] ?? null;

if (!$imageUrl) {
    sendResponse(false, "image_url required", null, 400);
}

// Quick obstacle detection
$obstacleInfo = quickObstacleDetection($imageUrl);

sendResponse(true, "Obstacle detection completed", $obstacleInfo, 200);

function quickObstacleDetection($imageUrl) {
    // Fast obstacle detection (simplified for demo)
    // In production, use lightweight ML model
    
    $hasObstacle = false;
    $obstacleType = 'none';
    $distance = 0.0;
    $confidence = 0.6;
    $recommendation = 'Path appears clear';
    
    // Check if image exists
    if (strpos($imageUrl, 'uploads/images/') !== false) {
        $imagePath = __DIR__ . '/../../' . $imageUrl;
        if (file_exists($imagePath)) {
            // Basic analysis
            // In production: Use YOLO or MobileNet for object detection
            $hasObstacle = false; // Placeholder
            $obstacleType = 'none';
            $distance = 0.0;
        }
    }
    
    return [
        'has_obstacle' => $hasObstacle,
        'obstacle_type' => $obstacleType,
        'distance' => $distance,
        'confidence' => $confidence,
        'recommendation' => $recommendation,
    ];
}

