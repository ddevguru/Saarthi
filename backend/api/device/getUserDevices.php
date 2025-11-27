<?php
/**
 * SAARTHI Backend - Get User Devices API
 * GET /api/device/getUserDevices.php
 * Returns all devices for the logged-in user
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../middleware/auth.php';

$db = (new Database())->getConnection();
$auth = new AuthMiddleware();
$user = $auth->validateToken();

$userId = $user['user_id'];

// Get user devices
$stmt = $db->prepare("
    SELECT id, device_id, device_name, status, last_seen, ip_address, stream_url
    FROM devices
    WHERE user_id = ?
    ORDER BY last_seen DESC
");
$stmt->execute([$userId]);
$devices = $stmt->fetchAll(PDO::FETCH_ASSOC);

sendResponse(true, "Devices retrieved successfully", [
    'devices' => $devices
], 200);

