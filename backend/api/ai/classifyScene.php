<?php
/**
 * SAARTHI Backend - AI Scene Classification API
 * POST /api/ai/classifyScene.php
 * Classifies scene type from image
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

// Classify scene
$scene = classifyScene($imageUrl);

sendResponse(true, "Scene classification completed", $scene, 200);

function classifyScene($imageUrl) {
    $sceneType = 'outdoor';
    $confidence = 0.7;
    $attributes = [];
    
    // Basic scene classification
    if (strpos($imageUrl, 'uploads/images/') !== false) {
        $imagePath = __DIR__ . '/../../' . $imageUrl;
        if (file_exists($imagePath)) {
            $imageInfo = @getimagesize($imagePath);
            if ($imageInfo) {
                // Simple classification based on image properties
                $width = $imageInfo[0];
                $height = $imageInfo[1];
                $aspectRatio = $width / $height;
                
                if ($aspectRatio > 1.5) {
                    $sceneType = 'outdoor_road';
                } elseif ($aspectRatio < 0.8) {
                    $sceneType = 'indoor_stairs';
                } else {
                    $sceneType = 'outdoor';
                }
            }
        }
    }
    
    return [
        'scene_type' => $sceneType,
        'confidence' => $confidence,
        'attributes' => $attributes,
    ];
}

