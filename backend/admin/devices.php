<?php
/**
 * SAARTHI Admin Panel - Devices List Page
 * Shows all registered devices
 */

header("Content-Type: text/html; charset=UTF-8");

session_start();
require_once __DIR__ . '/../config/database.php';
date_default_timezone_set('Asia/Kolkata');

// FIX: Prevent redirect loop - check session first, then role
if (!isset($_SESSION['user_id'])) {
    header('Location: login.php');
    exit;
}

// FIX: Check role with proper string comparison (case-insensitive)
$userRole = isset($_SESSION['user_role']) ? strtoupper(trim($_SESSION['user_role'])) : '';
if ($userRole !== 'ADMIN') {
    // Always redirect to login.php (NOT users.php) to prevent infinite redirect loop
    header('Location: login.php');
    exit;
}

$db = (new Database())->getConnection();

// Get all devices
$stmt = $db->prepare("
    SELECT d.*, u.name as user_name, u.email as user_email
    FROM devices d
    LEFT JOIN users u ON d.user_id = u.id
    ORDER BY d.last_seen DESC
");
$stmt->execute();
$devices = $stmt->fetchAll();

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Devices - SAARTHI Admin</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .devices-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 20px;
        }
        .device-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .device-card h3 {
            margin-top: 0;
            color: #667eea;
        }
        .device-info {
            display: grid;
            gap: 10px;
            margin-top: 15px;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            color: #666;
            font-size: 0.9em;
        }
        .info-value {
            font-weight: bold;
            color: #333;
        }
    </style>
</head>
<body>
    <?php include 'header.php'; ?>
    
    <div class="container">
        <h1>Registered Devices (<?php echo count($devices); ?>)</h1>
        
        <div class="devices-grid">
            <?php if (empty($devices)): ?>
            <div style="grid-column: 1 / -1; text-align: center; padding: 40px; color: #666;">
                No devices registered yet.
            </div>
            <?php else: ?>
            <?php foreach ($devices as $device): ?>
            <div class="device-card">
                <h3><?php echo htmlspecialchars($device['device_name'] ?? $device['device_id']); ?></h3>
                <p style="color: #666; font-size: 0.9em; margin: 5px 0;"><?php echo htmlspecialchars($device['device_id']); ?></p>
                
                <div class="device-info">
                    <div class="info-row">
                        <span class="info-label">Status</span>
                        <span class="info-value">
                            <span class="badge status-<?php echo strtolower($device['status']); ?>">
                                <?php echo $device['status']; ?>
                            </span>
                        </span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">User</span>
                        <span class="info-value">
                            <?php if ($device['user_name']): ?>
                            <a href="user_detail.php?id=<?php echo $device['user_id']; ?>">
                                <?php echo htmlspecialchars($device['user_name']); ?>
                            </a>
                            <?php else: ?>
                            User #<?php echo $device['user_id']; ?>
                            <?php endif; ?>
                        </span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">IP Address</span>
                        <span class="info-value"><?php echo htmlspecialchars($device['ip_address'] ?? 'N/A'); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Last Seen</span>
                        <span class="info-value">
                            <?php echo $device['last_seen'] ? date('d M Y H:i:s', strtotime($device['last_seen'])) : 'Never'; ?>
                        </span>
                    </div>
                    <?php if ($device['stream_url']): ?>
                    <div class="info-row">
                        <span class="info-label">Stream</span>
                        <span class="info-value">
                            <a href="<?php echo htmlspecialchars($device['stream_url']); ?>" target="_blank">View Stream</a>
                        </span>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
            <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>

    <?php include 'footer.php'; ?>
</body>
</html>

