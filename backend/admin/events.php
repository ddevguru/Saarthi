<?php
/**
 * SAARTHI Admin Panel - Events List Page
 * Shows all sensor events
 */

header("Content-Type: text/html; charset=UTF-8");

session_start();
require_once __DIR__ . '/../config/database.php';
date_default_timezone_set('Asia/Kolkata');

if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'ADMIN') {
    header('Location: login.php');
    exit;
}

$db = (new Database())->getConnection();

// Pagination
$page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
$perPage = 50;
$offset = ($page - 1) * $perPage;

// Filters
$eventType = $_GET['event_type'] ?? '';
$severity = $_GET['severity'] ?? '';
$userId = $_GET['user_id'] ?? '';

// Build query
$where = [];
$params = [];

if ($eventType) {
    $where[] = "se.event_type = ?";
    $params[] = $eventType;
}
if ($severity) {
    $where[] = "se.severity = ?";
    $params[] = $severity;
}
if ($userId) {
    $where[] = "se.user_id = ?";
    $params[] = $userId;
}

$whereClause = !empty($where) ? "WHERE " . implode(" AND ", $where) : "";

// Get total count
$countStmt = $db->prepare("SELECT COUNT(*) as count FROM sensor_events se $whereClause");
$countStmt->execute($params);
$totalEvents = $countStmt->fetch()['count'];
$totalPages = ceil($totalEvents / $perPage);

// Get events
$stmt = $db->prepare("
    SELECT se.*, u.name as user_name, u.email as user_email,
           d.device_id, d.device_name
    FROM sensor_events se
    LEFT JOIN users u ON se.user_id = u.id
    LEFT JOIN devices d ON se.device_id = d.id
    $whereClause
    ORDER BY se.created_at DESC
    LIMIT ? OFFSET ?
");
$params[] = $perPage;
$params[] = $offset;
$stmt->execute($params);
$events = $stmt->fetchAll();

// Get unique event types for filter
$typeStmt = $db->prepare("SELECT DISTINCT event_type FROM sensor_events ORDER BY event_type");
$typeStmt->execute();
$eventTypes = $typeStmt->fetchAll(PDO::FETCH_COLUMN);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Events - SAARTHI Admin</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .filters {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
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
        .filter-group select,
        .filter-group input {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 0.9em;
        }
        .events-table {
            background: white;
            border-radius: 8px;
            overflow: hidden;
        }
        .events-table table {
            width: 100%;
            border-collapse: collapse;
        }
        .events-table th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        .events-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }
        .events-table tr:hover {
            background: #f8f9fa;
        }
        .pagination {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-top: 20px;
        }
        .pagination a,
        .pagination span {
            padding: 8px 15px;
            background: white;
            border: 1px solid #ddd;
            border-radius: 5px;
            text-decoration: none;
            color: #667eea;
        }
        .pagination .active {
            background: #667eea;
            color: white;
            border-color: #667eea;
        }
    </style>
</head>
<body>
    <?php include 'header.php'; ?>
    
    <div class="container">
        <h1>Sensor Events</h1>
        
        <!-- Filters -->
        <form method="GET" class="filters">
            <div class="filter-group">
                <label>Event Type</label>
                <select name="event_type">
                    <option value="">All Types</option>
                    <?php foreach ($eventTypes as $type): ?>
                    <option value="<?php echo htmlspecialchars($type); ?>" <?php echo $eventType === $type ? 'selected' : ''; ?>>
                        <?php echo htmlspecialchars($type); ?>
                    </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="filter-group">
                <label>Severity</label>
                <select name="severity">
                    <option value="">All Severities</option>
                    <option value="CRITICAL" <?php echo $severity === 'CRITICAL' ? 'selected' : ''; ?>>Critical</option>
                    <option value="HIGH" <?php echo $severity === 'HIGH' ? 'selected' : ''; ?>>High</option>
                    <option value="MEDIUM" <?php echo $severity === 'MEDIUM' ? 'selected' : ''; ?>>Medium</option>
                    <option value="LOW" <?php echo $severity === 'LOW' ? 'selected' : ''; ?>>Low</option>
                </select>
            </div>
            <div class="filter-group">
                <label>User ID</label>
                <input type="number" name="user_id" value="<?php echo htmlspecialchars($userId); ?>" placeholder="User ID">
            </div>
            <div class="filter-group">
                <button type="submit" class="btn btn-primary">Filter</button>
            </div>
            <?php if ($eventType || $severity || $userId): ?>
            <div class="filter-group">
                <a href="events.php" class="btn">Clear Filters</a>
            </div>
            <?php endif; ?>
        </form>

        <!-- Events Table -->
        <div class="events-table">
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Event Type</th>
                        <th>User</th>
                        <th>Device</th>
                        <th>Severity</th>
                        <th>Created At</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($events)): ?>
                    <tr>
                        <td colspan="7" style="text-align: center; padding: 40px; color: #666;">
                            No events found.
                        </td>
                    </tr>
                    <?php else: ?>
                    <?php foreach ($events as $event): ?>
                    <tr>
                        <td><?php echo $event['id']; ?></td>
                        <td><?php echo htmlspecialchars($event['event_type']); ?></td>
                        <td>
                            <?php if ($event['user_name']): ?>
                            <a href="user_detail.php?id=<?php echo $event['user_id']; ?>">
                                <?php echo htmlspecialchars($event['user_name']); ?>
                            </a>
                            <?php else: ?>
                            User #<?php echo $event['user_id']; ?>
                            <?php endif; ?>
                        </td>
                        <td><?php echo htmlspecialchars($event['device_id'] ?? 'N/A'); ?></td>
                        <td>
                            <span class="badge badge-<?php echo strtolower($event['severity'] ?? 'low'); ?>">
                                <?php echo strtoupper($event['severity'] ?? 'LOW'); ?>
                            </span>
                        </td>
                        <td><?php echo date('d M Y H:i:s', strtotime($event['created_at'])); ?></td>
                        <td>
                            <a href="event_detail.php?id=<?php echo $event['id']; ?>" class="btn btn-sm">View</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

        <!-- Pagination -->
        <?php if ($totalPages > 1): ?>
        <div class="pagination">
            <?php if ($page > 1): ?>
            <a href="?page=<?php echo $page - 1; ?><?php echo $eventType ? '&event_type=' . urlencode($eventType) : ''; ?><?php echo $severity ? '&severity=' . urlencode($severity) : ''; ?><?php echo $userId ? '&user_id=' . urlencode($userId) : ''; ?>">← Previous</a>
            <?php endif; ?>
            
            <?php for ($i = max(1, $page - 2); $i <= min($totalPages, $page + 2); $i++): ?>
            <?php if ($i == $page): ?>
            <span class="active"><?php echo $i; ?></span>
            <?php else: ?>
            <a href="?page=<?php echo $i; ?><?php echo $eventType ? '&event_type=' . urlencode($eventType) : ''; ?><?php echo $severity ? '&severity=' . urlencode($severity) : ''; ?><?php echo $userId ? '&user_id=' . urlencode($userId) : ''; ?>"><?php echo $i; ?></a>
            <?php endif; ?>
            <?php endfor; ?>
            
            <?php if ($page < $totalPages): ?>
            <a href="?page=<?php echo $page + 1; ?><?php echo $eventType ? '&event_type=' . urlencode($eventType) : ''; ?><?php echo $severity ? '&severity=' . urlencode($severity) : ''; ?><?php echo $userId ? '&user_id=' . urlencode($userId) : ''; ?>">Next →</a>
            <?php endif; ?>
        </div>
        <?php endif; ?>
    </div>

    <?php include 'footer.php'; ?>
</body>
</html>

