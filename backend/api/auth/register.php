<?php
/**
 * SAARTHI Backend - User Registration API
 * POST /api/auth/register
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';

$db = (new Database())->getConnection();
$data = getRequestBody();

// Validate required fields
validateRequired($data, ['name', 'email', 'phone', 'password', 'role']);

$name = trim($data['name']);
$email = trim($data['email']);
$phone = trim($data['phone']);
$password = $data['password'];
$role = strtoupper($data['role']);
$language = $data['language_preference'] ?? 'en';
$disabilityType = $data['disability_type'] ?? 'NONE';

// Validate role
if (!in_array($role, ['USER', 'PARENT', 'ADMIN'])) {
    sendResponse(false, "Invalid role. Must be USER, PARENT, or ADMIN", null, 400);
}

// Validate email format
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendResponse(false, "Invalid email format", null, 400);
}

// Check if email already exists
$stmt = $db->prepare("SELECT id FROM users WHERE email = ? OR phone = ?");
$stmt->execute([$email, $phone]);
if ($stmt->fetch()) {
    sendResponse(false, "Email or phone number already registered", null, 409);
}

// Hash password
$passwordHash = password_hash($password, PASSWORD_BCRYPT);

// Insert user
try {
    $stmt = $db->prepare("
        INSERT INTO users (name, email, phone, password_hash, role, language_preference, disability_type)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([$name, $email, $phone, $passwordHash, $role, $language, $disabilityType]);
    
    $userId = $db->lastInsertId();
    
    // Create default sensor thresholds
    $stmt = $db->prepare("
        INSERT INTO sensor_thresholds (user_id, ultrasonic_min_distance, mic_loud_threshold)
        VALUES (?, 30.0, 2000)
    ");
    $stmt->execute([$userId]);
    
    sendResponse(true, "User registered successfully", [
        'user_id' => $userId,
        'name' => $name,
        'email' => $email,
        'role' => $role
    ], 201);
    
} catch (PDOException $e) {
    error_log("Registration error: " . $e->getMessage());
    sendResponse(false, "Registration failed", null, 500);
}

