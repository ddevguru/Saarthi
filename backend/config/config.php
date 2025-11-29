<?php
/**
 * SAARTHI Backend - Main Configuration
 */

// Error reporting (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Create logs directory if it doesn't exist
$logsDir = __DIR__ . '/../logs/';
if (!file_exists($logsDir)) {
    if (!mkdir($logsDir, 0755, true)) {
        // If can't create logs directory, use system error log
        ini_set('error_log', sys_get_temp_dir() . '/saarthi_error.log');
    } else {
        ini_set('error_log', $logsDir . 'error.log');
    }
} else {
    ini_set('error_log', $logsDir . 'error.log');
}

// Ensure logs directory is writable
if (file_exists($logsDir) && !is_writable($logsDir)) {
    chmod($logsDir, 0755);
}

// Timezone
date_default_timezone_set('Asia/Kolkata');

// CORS Headers
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Constants
define('JWT_SECRET', 'saarthi_secret_key_change_in_production_2024');
define('JWT_ALGORITHM', 'HS256');
define('JWT_EXPIRY', 3600); // 1 hour
define('REFRESH_TOKEN_EXPIRY', 604800); // 7 days

// WhatsApp API Configuration (CallMeBot or similar)
define('WHATSAPP_API_URL', 'https://api.callmebot.com/whatsapp.php');
define('WHATSAPP_API_KEY', '683bfe5fc5a1d'); // Replace with your actual key
define('WHATSAPP_INSTANCE_ID', '690ED82947B5D'); // Replace with your instance ID

// File upload paths
define('UPLOAD_DIR', __DIR__ . '/../uploads/');
define('UPLOAD_IMAGES_DIR', UPLOAD_DIR . 'images/');
define('UPLOAD_AUDIO_DIR', UPLOAD_DIR . 'audio/');

// Create upload directories if they don't exist with proper permissions
if (!file_exists(UPLOAD_DIR)) {
    if (!mkdir(UPLOAD_DIR, 0755, true)) {
        error_log("Failed to create upload directory: " . UPLOAD_DIR);
    }
}

if (!file_exists(UPLOAD_IMAGES_DIR)) {
    if (!mkdir(UPLOAD_IMAGES_DIR, 0755, true)) {
        error_log("Failed to create upload images directory: " . UPLOAD_IMAGES_DIR);
    } else {
        // Set proper permissions
        chmod(UPLOAD_IMAGES_DIR, 0755);
        error_log("Created upload images directory: " . UPLOAD_IMAGES_DIR);
    }
} else {
    // Ensure directory is writable
    if (!is_writable(UPLOAD_IMAGES_DIR)) {
        chmod(UPLOAD_IMAGES_DIR, 0755);
        error_log("Fixed permissions for upload images directory: " . UPLOAD_IMAGES_DIR);
    }
}

if (!file_exists(UPLOAD_AUDIO_DIR)) {
    if (!mkdir(UPLOAD_AUDIO_DIR, 0755, true)) {
        error_log("Failed to create upload audio directory: " . UPLOAD_AUDIO_DIR);
    } else {
        // Set proper permissions
        chmod(UPLOAD_AUDIO_DIR, 0755);
        error_log("Created upload audio directory: " . UPLOAD_AUDIO_DIR);
    }
} else {
    // Ensure directory is writable
    if (!is_writable(UPLOAD_AUDIO_DIR)) {
        chmod(UPLOAD_AUDIO_DIR, 0755);
        error_log("Fixed permissions for upload audio directory: " . UPLOAD_AUDIO_DIR);
    }
}

// Backend base URL
define('BASE_URL', 'https://devloperwala.in/saarthi');

// Helper function to send JSON response
function sendResponse($success, $message, $data = null, $statusCode = 200) {
    http_response_code($statusCode);
    $response = [
        'success' => $success,
        'message' => $message
    ];
    if ($data !== null) {
        $response['data'] = $data;
    }
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}

// Helper function to get request body (JSON or form-urlencoded)
function getRequestBody() {
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    
    // Check if it's form-urlencoded
    if (strpos($contentType, 'application/x-www-form-urlencoded') !== false) {
        // Parse form-urlencoded data
        parse_str(file_get_contents('php://input'), $data);
        return $data ?: [];
    }
    
    // Otherwise try JSON
    $input = file_get_contents('php://input');
    if (empty($input)) {
        return [];
    }
    
    $json = json_decode($input, true);
    return $json ?: [];
}

// Helper function to validate required fields
function validateRequired($data, $requiredFields) {
    $missing = [];
    foreach ($requiredFields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            $missing[] = $field;
        }
    }
    if (!empty($missing)) {
        sendResponse(false, "Missing required fields: " . implode(', ', $missing), null, 400);
    }
}

