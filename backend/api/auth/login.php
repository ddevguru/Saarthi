<?php
/**
 * SAARTHI Backend - User Login API
 * POST /api/auth/login
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$data = getRequestBody();

validateRequired($data, ['email', 'password']);

$email = trim($data['email']);
$password = $data['password'];

// Find user
$stmt = $db->prepare("
    SELECT id, name, email, phone, password_hash, role, language_preference, disability_type, is_active
    FROM users
    WHERE email = ? OR phone = ?
");
$stmt->execute([$email, $email]);
$user = $stmt->fetch();

if (!$user) {
    sendResponse(false, "Invalid email or password", null, 401);
}

if (!$user['is_active']) {
    sendResponse(false, "Account is inactive. Please contact administrator", null, 403);
}

// Verify password
if (!password_verify($password, $user['password_hash'])) {
    sendResponse(false, "Invalid email or password", null, 401);
}

// Generate token
$token = AuthMiddleware::generateToken($user['id']);

// Get user devices
$stmt = $db->prepare("SELECT id, device_id, device_name, status, last_seen, ip_address, stream_url FROM devices WHERE user_id = ?");
$stmt->execute([$user['id']]);
$devices = $stmt->fetchAll();

// Ensure device_id is always present (even if null)
foreach ($devices as &$device) {
    if (!isset($device['device_id']) || $device['device_id'] === null) {
        $device['device_id'] = '';
    }
}
unset($device);

sendResponse(true, "Login successful", [
    'token' => $token,
    'user' => [
        'id' => $user['id'],
        'name' => $user['name'],
        'email' => $user['email'],
        'phone' => $user['phone'],
        'role' => $user['role'],
        'language_preference' => $user['language_preference'],
        'disability_type' => $user['disability_type']
    ],
    'devices' => $devices
], 200);

