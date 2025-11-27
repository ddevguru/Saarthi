<?php
/**
 * SAARTHI Admin Panel
 * Main dashboard for administrators
 */

// Set HTML content type for admin panel
header("Content-Type: text/html; charset=UTF-8");

session_start();
require_once __DIR__ . '/../config/database.php';

// Don't include config.php here as it sets JSON headers
// We'll include only what we need
date_default_timezone_set('Asia/Kolkata');

// Check if user is logged in and is admin (manual check, don't use auth middleware as it sets JSON headers)
if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'ADMIN') {
    header('Location: login.php');
    exit;
}

$db = (new Database())->getConnection();
$userId = $_SESSION['user_id'];

// Get statistics
$stats = [];

// Total users
$stmt = $db->prepare("SELECT COUNT(*) as count FROM users WHERE role = 'USER'");
$stmt->execute();
$stats['total_users'] = $stmt->fetch()['count'];

// Total parents
$stmt = $db->prepare("SELECT COUNT(*) as count FROM users WHERE role = 'PARENT'");
$stmt->execute();
$stats['total_parents'] = $stmt->fetch()['count'];

// Total devices
$stmt = $db->prepare("SELECT COUNT(*) as count FROM devices");
$stmt->execute();
$stats['total_devices'] = $stmt->fetch()['count'];

// Online devices
$stmt = $db->prepare("SELECT COUNT(*) as count FROM devices WHERE status = 'ONLINE' AND last_seen > DATE_SUB(NOW(), INTERVAL 10 MINUTE)");
$stmt->execute();
$stats['online_devices'] = $stmt->fetch()['count'];

// Recent events (last 24 hours)
$stmt = $db->prepare("
    SELECT COUNT(*) as count 
    FROM sensor_events 
    WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
");
$stmt->execute();
$stats['recent_events'] = $stmt->fetch()['count'];

// Critical events (last 24 hours)
$stmt = $db->prepare("
    SELECT COUNT(*) as count 
    FROM sensor_events 
    WHERE severity = 'CRITICAL' AND created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
");
$stmt->execute();
$stats['critical_events'] = $stmt->fetch()['count'];

// Get recent events
$stmt = $db->prepare("
    SELECT se.*, u.name as user_name, u.phone as user_phone, d.device_id
    FROM sensor_events se
    INNER JOIN users u ON se.user_id = u.id
    LEFT JOIN devices d ON se.device_id = d.id
    ORDER BY se.created_at DESC
    LIMIT 50
");
$stmt->execute();
$recentEvents = $stmt->fetchAll();

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SAARTHI Admin Panel</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>SAARTHI Admin Panel</h1>
            <div class="user-info">
                <span>Welcome, <?php echo htmlspecialchars($_SESSION['user_name'] ?? 'Admin'); ?></span>
                <a href="logout.php" class="btn btn-secondary">Logout</a>
            </div>
        </header>

        <div class="stats-grid">
            <div class="stat-card">
                <h3>Total Users</h3>
                <p class="stat-number"><?php echo $stats['total_users']; ?></p>
            </div>
            <div class="stat-card">
                <h3>Total Parents</h3>
                <p class="stat-number"><?php echo $stats['total_parents']; ?></p>
            </div>
            <div class="stat-card">
                <h3>Total Devices</h3>
                <p class="stat-number"><?php echo $stats['total_devices']; ?></p>
            </div>
            <div class="stat-card">
                <h3>Online Devices</h3>
                <p class="stat-number"><?php echo $stats['online_devices']; ?></p>
            </div>
            <div class="stat-card">
                <h3>Recent Events (24h)</h3>
                <p class="stat-number"><?php echo $stats['recent_events']; ?></p>
            </div>
            <div class="stat-card critical">
                <h3>Critical Events (24h)</h3>
                <p class="stat-number"><?php echo $stats['critical_events']; ?></p>
            </div>
        </div>

        <div class="section">
            <h2>Recent Events</h2>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Time</th>
                            <th>User</th>
                            <th>Device</th>
                            <th>Event Type</th>
                            <th>Severity</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($recentEvents as $event): ?>
                        <tr class="severity-<?php echo strtolower($event['severity']); ?>">
                            <td><?php echo date('Y-m-d H:i:s', strtotime($event['created_at'])); ?></td>
                            <td><?php echo htmlspecialchars($event['user_name']); ?></td>
                            <td><?php echo htmlspecialchars($event['device_id'] ?? 'N/A'); ?></td>
                            <td><?php echo htmlspecialchars($event['event_type']); ?></td>
                            <td><span class="badge badge-<?php echo strtolower($event['severity']); ?>"><?php echo $event['severity']; ?></span></td>
                            <td>
                                <a href="event_detail.php?id=<?php echo $event['id']; ?>" class="btn btn-sm">View</a>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <h2>Quick Actions</h2>
            <div class="action-buttons">
                <a href="users.php" class="btn btn-primary">Manage Users (<?php echo $stats['total_users']; ?>)</a>
                <a href="users.php" class="btn btn-primary">View All Users</a>
                <a href="index.php" class="btn btn-primary">Refresh Dashboard</a>
            </div>
        </div>

        <div class="section">
            <h2>Recent Users Activity</h2>
            <?php
            // Get users with recent activity
            $stmt = $db->prepare("
                SELECT u.id, u.name, u.email, u.phone, u.role,
                       COUNT(DISTINCT d.id) as device_count,
                       MAX(l.created_at) as last_location,
                       MAX(se.created_at) as last_event
                FROM users u
                LEFT JOIN devices d ON u.id = d.user_id
                LEFT JOIN locations l ON u.id = l.user_id
                LEFT JOIN sensor_events se ON u.id = se.user_id
                WHERE u.role = 'USER'
                GROUP BY u.id
                ORDER BY GREATEST(COALESCE(l.created_at, '1970-01-01'), COALESCE(se.created_at, '1970-01-01')) DESC
                LIMIT 10
            ");
            $stmt->execute();
            $activeUsers = $stmt->fetchAll();
            ?>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Phone</th>
                            <th>Devices</th>
                            <th>Last Location</th>
                            <th>Last Event</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($activeUsers as $activeUser): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($activeUser['name']); ?></td>
                            <td><?php echo htmlspecialchars($activeUser['email']); ?></td>
                            <td><?php echo htmlspecialchars($activeUser['phone']); ?></td>
                            <td><?php echo $activeUser['device_count']; ?></td>
                            <td><?php echo $activeUser['last_location'] ? date('d M Y H:i', strtotime($activeUser['last_location'])) : 'Never'; ?></td>
                            <td><?php echo $activeUser['last_event'] ? date('d M Y H:i', strtotime($activeUser['last_event'])) : 'Never'; ?></td>
                            <td>
                                <a href="user_detail.php?id=<?php echo $activeUser['id']; ?>" class="btn btn-sm">View</a>
                                <a href="user_detail.php?id=<?php echo $activeUser['id']; ?>&tab=location" class="btn btn-sm">Location</a>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script src="script.js"></script>
</body>
</html>

