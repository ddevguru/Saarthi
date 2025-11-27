<?php
/**
 * SAARTHI Admin Panel - Event Detail Page
 * Shows detailed information about a sensor event
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
$eventId = $_GET['id'] ?? null;

if (!$eventId) {
    header('Location: events.php');
    exit;
}

// Get event details
$stmt = $db->prepare("
    SELECT se.*, u.name as user_name, u.email as user_email, u.phone as user_phone,
           d.device_id, d.device_name, d.ip_address
    FROM sensor_events se
    LEFT JOIN users u ON se.user_id = u.id
    LEFT JOIN devices d ON se.device_id = d.id
    WHERE se.id = ?
");
$stmt->execute([$eventId]);
$event = $stmt->fetch();

if (!$event) {
    header('Location: events.php');
    exit;
}

// Parse sensor payload if it's JSON
$sensorPayload = [];
if ($event['sensor_payload']) {
    $sensorPayload = json_decode($event['sensor_payload'], true) ?: [];
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Event #<?php echo $eventId; ?> - SAARTHI Admin</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .event-detail {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .event-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .event-header h1 {
            margin: 0 0 10px 0;
        }
        .event-header .event-meta {
            opacity: 0.9;
            font-size: 0.9em;
        }
        .detail-section {
            background: white;
            padding: 25px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .detail-section h2 {
            margin-top: 0;
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .info-item {
            display: flex;
            flex-direction: column;
        }
        .info-label {
            font-size: 0.85em;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 5px;
        }
        .info-value {
            font-size: 1.1em;
            font-weight: bold;
            color: #333;
        }
        .badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: bold;
        }
        .badge-critical { background: #fee; color: #c00; }
        .badge-high { background: #ffe; color: #c60; }
        .badge-medium { background: #eef; color: #06c; }
        .badge-low { background: #efe; color: #060; }
        .payload-json {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            font-family: monospace;
            font-size: 0.9em;
            overflow-x: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin-top: 20px;
        }
        .btn:hover {
            background: #5568d3;
        }
    </style>
</head>
<body>
    <?php include 'header.php'; ?>
    
    <div class="event-detail">
        <div class="event-header">
            <h1>Event #<?php echo $eventId; ?></h1>
            <div class="event-meta">
                <?php echo date('d M Y, H:i:s', strtotime($event['created_at'])); ?> | 
                <?php echo htmlspecialchars($event['event_type']); ?>
            </div>
        </div>

        <!-- Event Information -->
        <div class="detail-section">
            <h2>Event Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Event Type</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['event_type']); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Severity</span>
                    <span class="info-value">
                        <span class="badge badge-<?php echo strtolower($event['severity'] ?? 'low'); ?>">
                            <?php echo strtoupper($event['severity'] ?? 'LOW'); ?>
                        </span>
                    </span>
                </div>
                <div class="info-item">
                    <span class="info-label">Created At</span>
                    <span class="info-value"><?php echo date('d M Y, H:i:s', strtotime($event['created_at'])); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Status</span>
                    <span class="info-value"><?php echo $event['is_resolved'] ? 'Resolved' : 'Active'; ?></span>
                </div>
            </div>
        </div>

        <!-- User Information -->
        <div class="detail-section">
            <h2>User Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Name</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['user_name'] ?? 'N/A'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Email</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['user_email'] ?? 'N/A'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Phone</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['user_phone'] ?? 'N/A'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">User ID</span>
                    <span class="info-value"><?php echo $event['user_id']; ?></span>
                </div>
            </div>
            <a href="user_detail.php?id=<?php echo $event['user_id']; ?>" class="btn">View User Details</a>
        </div>

        <!-- Device Information -->
        <?php if ($event['device_id']): ?>
        <div class="detail-section">
            <h2>Device Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Device ID</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['device_id']); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Device Name</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['device_name'] ?? 'N/A'); ?></span>
                </div>
                <div class="info-item">
                    <span class="info-label">IP Address</span>
                    <span class="info-value"><?php echo htmlspecialchars($event['ip_address'] ?? 'N/A'); ?></span>
                </div>
            </div>
        </div>
        <?php endif; ?>

        <!-- Sensor Payload -->
        <?php if (!empty($sensorPayload)): ?>
        <div class="detail-section">
            <h2>Sensor Data</h2>
            <div class="payload-json"><?php echo htmlspecialchars(json_encode($sensorPayload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)); ?></div>
        </div>
        <?php endif; ?>

        <!-- Image if available -->
        <?php if (!empty($event['image_path'])): ?>
        <div class="detail-section">
            <h2>Captured Image</h2>
            <img src="<?php echo htmlspecialchars($event['image_path']); ?>" 
                 alt="Event Image" 
                 style="max-width: 100%; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        </div>
        <?php endif; ?>

        <!-- Audio if available -->
        <?php if (!empty($event['audio_path'])): ?>
        <div class="detail-section">
            <h2>Recorded Audio</h2>
            <audio controls style="width: 100%; margin-top: 10px;">
                <source src="<?php echo htmlspecialchars($event['audio_path']); ?>" type="audio/mpeg">
                <source src="<?php echo htmlspecialchars($event['audio_path']); ?>" type="audio/m4a">
                Your browser does not support the audio element.
            </audio>
            <p style="margin-top: 10px; color: #666;">
                <a href="<?php echo htmlspecialchars($event['audio_path']); ?>" download>Download Audio</a>
            </p>
        </div>
        <?php endif; ?>

        <a href="events.php" class="btn">← Back to Events</a>
    </div>

    <?php include 'footer.php'; ?>
</body>
</html>

