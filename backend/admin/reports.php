<?php
/**
 * SAARTHI Admin Panel - Reports Page
 * Shows analytics and reports
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

// Date range filter
$startDate = $_GET['start_date'] ?? date('Y-m-d', strtotime('-30 days'));
$endDate = $_GET['end_date'] ?? date('Y-m-d');

// Event statistics
$stmt = $db->prepare("
    SELECT event_type, COUNT(*) as count, severity
    FROM sensor_events
    WHERE DATE(created_at) BETWEEN ? AND ?
    GROUP BY event_type, severity
    ORDER BY count DESC
");
$stmt->execute([$startDate, $endDate]);
$eventStats = $stmt->fetchAll();

// User activity
$stmt = $db->prepare("
    SELECT u.id, u.name, u.email, COUNT(se.id) as event_count,
           MAX(se.created_at) as last_event
    FROM users u
    LEFT JOIN sensor_events se ON u.id = se.user_id AND DATE(se.created_at) BETWEEN ? AND ?
    WHERE u.role = 'USER'
    GROUP BY u.id
    ORDER BY event_count DESC
    LIMIT 20
");
$stmt->execute([$startDate, $endDate]);
$userActivity = $stmt->fetchAll();

// Device activity
$stmt = $db->prepare("
    SELECT d.device_id, d.device_name, COUNT(se.id) as event_count,
           MAX(se.created_at) as last_event
    FROM devices d
    LEFT JOIN sensor_events se ON d.id = se.device_id AND DATE(se.created_at) BETWEEN ? AND ?
    GROUP BY d.id
    ORDER BY event_count DESC
    LIMIT 20
");
$stmt->execute([$startDate, $endDate]);
$deviceActivity = $stmt->fetchAll();

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reports - SAARTHI Admin</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .report-filters {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .report-filters form {
            display: flex;
            gap: 15px;
            align-items: end;
        }
        .filter-group {
            display: flex;
            flex-direction: column;
        }
        .filter-group label {
            font-size: 0.85em;
            color: #666;
            margin-bottom: 5px;
        }
        .filter-group input {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .report-section {
            background: white;
            padding: 25px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .report-section h2 {
            margin-top: 0;
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .stats-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .stats-table th {
            background: #f8f9fa;
            padding: 12px;
            text-align: left;
            font-weight: 600;
        }
        .stats-table td {
            padding: 10px 12px;
            border-bottom: 1px solid #eee;
        }
        .stats-table tr:hover {
            background: #f8f9fa;
        }
    </style>
</head>
<body>
    <?php include 'header.php'; ?>
    
    <div class="container">
        <h1>Reports & Analytics</h1>
        
        <!-- Date Range Filter -->
        <div class="report-filters">
            <form method="GET">
                <div class="filter-group">
                    <label>Start Date</label>
                    <input type="date" name="start_date" value="<?php echo htmlspecialchars($startDate); ?>">
                </div>
                <div class="filter-group">
                    <label>End Date</label>
                    <input type="date" name="end_date" value="<?php echo htmlspecialchars($endDate); ?>">
                </div>
                <div class="filter-group">
                    <button type="submit" class="btn btn-primary">Generate Report</button>
                </div>
            </form>
        </div>

        <!-- Event Statistics -->
        <div class="report-section">
            <h2>Event Statistics</h2>
            <table class="stats-table">
                <thead>
                    <tr>
                        <th>Event Type</th>
                        <th>Severity</th>
                        <th>Count</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($eventStats)): ?>
                    <tr>
                        <td colspan="3" style="text-align: center; padding: 20px; color: #666;">
                            No events in selected date range.
                        </td>
                    </tr>
                    <?php else: ?>
                    <?php foreach ($eventStats as $stat): ?>
                    <tr>
                        <td><?php echo htmlspecialchars($stat['event_type']); ?></td>
                        <td>
                            <span class="badge badge-<?php echo strtolower($stat['severity']); ?>">
                                <?php echo strtoupper($stat['severity']); ?>
                            </span>
                        </td>
                        <td><strong><?php echo $stat['count']; ?></strong></td>
                    </tr>
                    <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

        <!-- User Activity -->
        <div class="report-section">
            <h2>Top Active Users</h2>
            <table class="stats-table">
                <thead>
                    <tr>
                        <th>User</th>
                        <th>Email</th>
                        <th>Event Count</th>
                        <th>Last Event</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($userActivity as $user): ?>
                    <tr>
                        <td>
                            <a href="user_detail.php?id=<?php echo $user['id']; ?>">
                                <?php echo htmlspecialchars($user['name']); ?>
                            </a>
                        </td>
                        <td><?php echo htmlspecialchars($user['email']); ?></td>
                        <td><strong><?php echo $user['event_count']; ?></strong></td>
                        <td><?php echo $user['last_event'] ? date('d M Y H:i', strtotime($user['last_event'])) : 'Never'; ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <!-- Device Activity -->
        <div class="report-section">
            <h2>Top Active Devices</h2>
            <table class="stats-table">
                <thead>
                    <tr>
                        <th>Device ID</th>
                        <th>Device Name</th>
                        <th>Event Count</th>
                        <th>Last Event</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($deviceActivity as $device): ?>
                    <tr>
                        <td><?php echo htmlspecialchars($device['device_id']); ?></td>
                        <td><?php echo htmlspecialchars($device['device_name'] ?? 'N/A'); ?></td>
                        <td><strong><?php echo $device['event_count']; ?></strong></td>
                        <td><?php echo $device['last_event'] ? date('d M Y H:i', strtotime($device['last_event'])) : 'Never'; ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>

    <?php include 'footer.php'; ?>
</body>
</html>

