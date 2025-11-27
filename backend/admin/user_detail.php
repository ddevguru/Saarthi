<?php
/**
 * SAARTHI Admin Panel - User Detail Page
 * Shows user details, live location, events, and devices
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
$userId = $_GET['id'] ?? null;
$tab = $_GET['tab'] ?? 'details';

if (!$userId) {
    header('Location: users.php');
    exit;
}

// Get user details
$stmt = $db->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$userId]);
$user = $stmt->fetch();

if (!$user) {
    header('Location: users.php');
    exit;
}

// Get user devices
$stmt = $db->prepare("SELECT * FROM devices WHERE user_id = ? ORDER BY last_seen DESC");
$stmt->execute([$userId]);
$devices = $stmt->fetchAll();

// Get latest location
$stmt = $db->prepare("
    SELECT * FROM locations 
    WHERE user_id = ? 
    ORDER BY created_at DESC 
    LIMIT 1
");
$stmt->execute([$userId]);
$latestLocation = $stmt->fetch();

// Get recent locations (last 50)
$stmt = $db->prepare("
    SELECT * FROM locations 
    WHERE user_id = ? 
    ORDER BY created_at DESC 
    LIMIT 50
");
$stmt->execute([$userId]);
$locations = $stmt->fetchAll();

// Get recent events
$stmt = $db->prepare("
    SELECT se.*, d.device_id 
    SELECT se.id, se.event_type, se.severity, se.created_at, se.image_path, se.audio_path, se.sensor_payload
    FROM sensor_events se
    LEFT JOIN devices d ON se.device_id = d.id
    WHERE se.user_id = ?
    ORDER BY se.created_at DESC
    LIMIT 100
");
$stmt->execute([$userId]);
$events = $stmt->fetchAll();

// Get emergency contacts (check if is_active column exists)
try {
    $stmt = $db->prepare("SELECT * FROM emergency_contacts WHERE user_id = ?");
    $stmt->execute([$userId]);
    $emergencyContacts = $stmt->fetchAll();
} catch (PDOException $e) {
    // If table doesn't exist or column missing, use empty array
    $emergencyContacts = [];
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($user['name']); ?> - SAARTHI Admin</title>
    <link rel="stylesheet" href="styles.css">
    <script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyCU8FMx2ffc-iLiflgzUwqhpEJ706q_U0w"></script>
    <style>
        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            border-bottom: 2px solid #eee;
        }
        .tab {
            padding: 12px 24px;
            background: #f8f9fa;
            border: none;
            cursor: pointer;
            border-radius: 5px 5px 0 0;
            font-size: 1em;
            transition: all 0.3s;
        }
        .tab.active {
            background: #667eea;
            color: white;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        .detail-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .detail-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .detail-card h3 {
            margin-bottom: 10px;
            color: #333;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .detail-card p {
            font-size: 1.2em;
            font-weight: bold;
            color: #667eea;
            margin: 0;
        }
        #map {
            width: 100%;
            height: 500px;
            border-radius: 8px;
            margin-top: 20px;
        }
        .location-list {
            max-height: 500px;
            overflow-y: auto;
        }
        .location-item {
            padding: 15px;
            border-bottom: 1px solid #eee;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .location-item:hover {
            background: #f8f9fa;
        }
        .location-coords {
            font-family: monospace;
            color: #666;
            font-size: 0.9em;
        }
        .device-card {
            background: white;
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 15px;
        }
        .device-status {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: bold;
        }
        .status-online { background: #d4edda; color: #155724; }
        .status-offline { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <nav class="navbar">
        <div class="nav-container">
            <div class="nav-brand">
                <h1>SAARTHI Admin</h1>
            </div>
            <div class="nav-menu">
                <a href="index.php" class="nav-link">Dashboard</a>
                <a href="users.php" class="nav-link">Users</a>
                <a href="devices.php" class="nav-link">Devices</a>
                <a href="events.php" class="nav-link">Events</a>
                <a href="reports.php" class="nav-link">Reports</a>
                <a href="logout.php" class="nav-link">Logout</a>
            </div>
        </div>
    </nav>
    <div class="container">
        <header>
            <h1><?php echo htmlspecialchars($user['name']); ?> - User Details</h1>
            <div class="user-info">
                <a href="users.php" class="btn btn-secondary">← Back to Users</a>
                <a href="index.php" class="btn btn-secondary">Dashboard</a>
            </div>
        </header>

        <div class="section">
            <div class="tabs">
                <button class="tab <?php echo $tab === 'details' ? 'active' : ''; ?>" onclick="showTab('details')">Details</button>
                <button class="tab <?php echo $tab === 'location' ? 'active' : ''; ?>" onclick="showTab('location')">Live Location</button>
                <button class="tab <?php echo $tab === 'devices' ? 'active' : ''; ?>" onclick="showTab('devices')">Devices</button>
                <button class="tab <?php echo $tab === 'events' ? 'active' : ''; ?>" onclick="showTab('events')">Events</button>
                <button class="tab <?php echo $tab === 'contacts' ? 'active' : ''; ?>" onclick="showTab('contacts')">Emergency Contacts</button>
            </div>

            <!-- Details Tab -->
            <div id="details" class="tab-content <?php echo $tab === 'details' ? 'active' : ''; ?>">
                <div class="detail-grid">
                    <div class="detail-card">
                        <h3>Name</h3>
                        <p><?php echo htmlspecialchars($user['name']); ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Email</h3>
                        <p><?php echo htmlspecialchars($user['email']); ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Phone</h3>
                        <p><?php echo htmlspecialchars($user['phone']); ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Role</h3>
                        <p><?php echo $user['role']; ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Status</h3>
                        <p><?php echo $user['is_active'] ? 'Active' : 'Inactive'; ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Disability Type</h3>
                        <p><?php echo $user['disability_type'] ?? 'NONE'; ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Language</h3>
                        <p><?php echo strtoupper($user['language_preference'] ?? 'en'); ?></p>
                    </div>
                    <div class="detail-card">
                        <h3>Joined</h3>
                        <p><?php echo date('d M Y', strtotime($user['created_at'])); ?></p>
                    </div>
                </div>
            </div>

            <!-- Location Tab -->
            <div id="location" class="tab-content <?php echo $tab === 'location' ? 'active' : ''; ?>">
                <?php if ($latestLocation && isset($latestLocation['latitude']) && isset($latestLocation['longitude'])): ?>
                    <div id="map"></div>
                    <script>
                        function initMap() {
                            const location = {
                                lat: <?php echo floatval($latestLocation['latitude']); ?>,
                                lng: <?php echo floatval($latestLocation['longitude']); ?>
                            };
                            
                            const map = new google.maps.Map(document.getElementById('map'), {
                                zoom: 15,
                                center: location
                            });
                            
                            // Current location marker
                            new google.maps.Marker({
                                position: location,
                                map: map,
                                title: '<?php echo htmlspecialchars($user['name']); ?> - Current Location',
                                icon: {
                                    url: 'http://maps.google.com/mapfiles/ms/icons/red-dot.png'
                                }
                            });
                            
                            // Add path for location history
                            <?php if (count($locations) > 1): ?>
                            const path = [
                                <?php 
                                $pathPoints = array_slice(array_reverse($locations), 0, 20); // Last 20 locations
                                $pathCount = 0;
                                foreach ($pathPoints as $loc): 
                                    if (isset($loc['latitude']) && isset($loc['longitude']) && is_numeric($loc['latitude']) && is_numeric($loc['longitude'])):
                                        if ($pathCount > 0) echo ',';
                                ?>
                                {lat: <?php echo floatval($loc['latitude']); ?>, lng: <?php echo floatval($loc['longitude']); ?>}
                                <?php 
                                        $pathCount++;
                                    endif;
                                endforeach; 
                                ?>
                            ];
                            
                            new google.maps.Polyline({
                                path: path,
                                geodesic: true,
                                strokeColor: '#667eea',
                                strokeOpacity: 0.5,
                                strokeWeight: 3
                            });
                            <?php endif; ?>
                        }
                        initMap();
                    </script>
                    
                    <div style="margin-top: 20px;">
                        <h3>Location History (Last 50)</h3>
                        <div class="location-list">
                            <?php foreach ($locations as $loc): ?>
                            <?php if (isset($loc['latitude']) && isset($loc['longitude']) && is_numeric($loc['latitude']) && is_numeric($loc['longitude'])): ?>
                            <div class="location-item">
                                <div>
                                    <strong><?php echo date('d M Y H:i:s', strtotime($loc['created_at'])); ?></strong>
                                    <div class="location-coords">
                                        Lat: <?php echo $loc['latitude']; ?>, Lng: <?php echo $loc['longitude']; ?>
                                        <?php if (isset($loc['accuracy']) && $loc['accuracy']): ?>
                                        (Accuracy: <?php echo round($loc['accuracy']); ?>m)
                                        <?php endif; ?>
                                    </div>
                                </div>
                                <a href="https://www.google.com/maps?q=<?php echo $loc['latitude']; ?>,<?php echo $loc['longitude']; ?>" 
                                   target="_blank" class="btn btn-sm">View on Maps</a>
                            </div>
                            <?php endif; ?>
                            <?php endforeach; ?>
                        </div>
                    </div>
                <?php else: ?>
                    <p style="text-align: center; padding: 40px; color: #666;">
                        No location data available for this user.
                    </p>
                <?php endif; ?>
            </div>

            <!-- Devices Tab -->
            <div id="devices" class="tab-content <?php echo $tab === 'devices' ? 'active' : ''; ?>">
                <?php if (count($devices) > 0): ?>
                    <?php foreach ($devices as $device): ?>
                    <div class="device-card">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                            <div>
                                <h3 style="margin: 0;"><?php echo htmlspecialchars($device['device_name'] ?? $device['device_id']); ?></h3>
                                <p style="margin: 5px 0; color: #666; font-size: 0.9em;"><?php echo htmlspecialchars($device['device_id']); ?></p>
                            </div>
                            <span class="device-status status-<?php echo strtolower($device['status']); ?>">
                                <?php echo $device['status']; ?>
                            </span>
                        </div>
                        <div class="user-info">
                            <div class="info-item">
                                <span class="info-label">IP Address</span>
                                <span class="info-value"><?php echo htmlspecialchars($device['ip_address'] ?? 'N/A'); ?></span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Last Seen</span>
                                <span class="info-value">
                                    <?php echo $device['last_seen'] ? date('d M Y H:i:s', strtotime($device['last_seen'])) : 'Never'; ?>
                                </span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Stream URL</span>
                                <span class="info-value">
                                    <?php if ($device['stream_url']): ?>
                                        <a href="<?php echo htmlspecialchars($device['stream_url']); ?>" target="_blank">View Stream</a>
                                    <?php else: ?>
                                        N/A
                                    <?php endif; ?>
                                </span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Firmware</span>
                                <span class="info-value"><?php echo htmlspecialchars($device['firmware_version'] ?? 'N/A'); ?></span>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p style="text-align: center; padding: 40px; color: #666;">
                        No devices registered for this user.
                    </p>
                <?php endif; ?>
            </div>

            <!-- Events Tab -->
            <div id="events" class="tab-content <?php echo $tab === 'events' ? 'active' : ''; ?>">
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Time</th>
                                <th>Device</th>
                                <th>Event Type</th>
                                <th>Severity</th>
                                <th>Media</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($events as $event): ?>
                            <tr class="severity-<?php echo strtolower($event['severity']); ?>">
                                <td><?php echo date('d M Y H:i:s', strtotime($event['created_at'])); ?></td>
                                <td><?php echo htmlspecialchars($event['device_id'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars($event['event_type']); ?></td>
                                <td><span class="badge badge-<?php echo strtolower($event['severity']); ?>"><?php echo $event['severity']; ?></span></td>
                                <td>
                                    <?php if (!empty($event['image_path'])): ?>
                                        <span style="color: #2196F3;" title="Photo available">📷</span>
                                    <?php endif; ?>
                                    <?php if (!empty($event['audio_path'])): ?>
                                        <span style="color: #4CAF50;" title="Audio available">🎵</span>
                                    <?php endif; ?>
                                    <?php if (empty($event['image_path']) && empty($event['audio_path'])): ?>
                                        <span style="color: #999;">—</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <a href="event_detail.php?id=<?php echo $event['id']; ?>" class="btn btn-sm">View</a>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Emergency Contacts Tab -->
            <div id="contacts" class="tab-content <?php echo $tab === 'contacts' ? 'active' : ''; ?>">
                <?php if (count($emergencyContacts) > 0): ?>
                    <div class="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Phone</th>
                                    <th>Relationship</th>
                                    <th>Primary</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($emergencyContacts as $contact): ?>
                                <tr>
                                    <td><?php echo htmlspecialchars($contact['name']); ?></td>
                                    <td><?php echo htmlspecialchars($contact['phone']); ?></td>
                                    <td><?php echo htmlspecialchars($contact['relationship'] ?? 'N/A'); ?></td>
                                    <td><?php echo $contact['is_primary'] ? 'Yes' : 'No'; ?></td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php else: ?>
                    <p style="text-align: center; padding: 40px; color: #666;">
                        No emergency contacts registered for this user.
                    </p>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <script>
        function showTab(tabName) {
            // Hide all tabs
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            document.querySelectorAll('.tab').forEach(tab => {
                tab.classList.remove('active');
            });
            
            // Show selected tab
            document.getElementById(tabName).classList.add('active');
            event.target.classList.add('active');
            
            // Update URL
            const url = new URL(window.location);
            url.searchParams.set('tab', tabName);
            window.history.pushState({}, '', url);
        }
        
        // Initialize tab on page load
        document.addEventListener('DOMContentLoaded', function() {
            const tab = '<?php echo $tab; ?>';
            if (tab) {
                showTab(tab);
            }
        });
    </script>
    <footer style="text-align: center; padding: 20px; color: #666; margin-top: 40px;">
        <p>&copy; <?php echo date('Y'); ?> SAARTHI Admin Panel. All rights reserved.</p>
    </footer>
</body>
</html>

