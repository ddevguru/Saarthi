<?php
/**
 * SAARTHI Admin Panel - Users Management
 * List all users with details
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

// Get all users
$stmt = $db->prepare("
    SELECT u.*, 
           COUNT(DISTINCT d.id) as device_count,
           COUNT(DISTINCT se.id) as event_count,
           MAX(l.created_at) as last_location_time
    FROM users u
    LEFT JOIN devices d ON u.id = d.user_id
    LEFT JOIN sensor_events se ON u.id = se.user_id
    LEFT JOIN locations l ON u.id = l.user_id
    GROUP BY u.id
    ORDER BY u.created_at DESC
");
$stmt->execute();
$users = $stmt->fetchAll();

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Users - SAARTHI Admin</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .search-box {
            margin: 20px 0;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 5px;
        }
        .search-box input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 1em;
        }
        .user-card {
            background: white;
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 15px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .user-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        .user-name {
            font-size: 1.3em;
            font-weight: bold;
            color: #333;
        }
        .user-role {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: bold;
        }
        .role-user { background: #e3f2fd; color: #1976d2; }
        .role-parent { background: #f3e5f5; color: #7b1fa2; }
        .role-admin { background: #fff3e0; color: #e65100; }
        .user-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .info-item {
            display: flex;
            flex-direction: column;
        }
        .info-label {
            font-size: 0.85em;
            color: #666;
            margin-bottom: 5px;
        }
        .info-value {
            font-weight: 500;
            color: #333;
        }
        .action-buttons {
            margin-top: 15px;
            display: flex;
            gap: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Users Management</h1>
            <div class="user-info">
                <a href="index.php" class="btn btn-secondary">← Back to Dashboard</a>
                <a href="logout.php" class="btn btn-secondary">Logout</a>
            </div>
        </header>

        <div class="section">
            <div class="search-box">
                <input type="text" id="searchInput" placeholder="Search users by name, email, or phone..." onkeyup="filterUsers()">
            </div>
            
            <h2>All Users (<?php echo count($users); ?>)</h2>
            
            <div id="usersList">
                <?php foreach ($users as $user): ?>
                <div class="user-card" data-name="<?php echo strtolower(htmlspecialchars($user['name'])); ?>" 
                     data-email="<?php echo strtolower(htmlspecialchars($user['email'])); ?>"
                     data-phone="<?php echo htmlspecialchars($user['phone']); ?>">
                    <div class="user-header">
                        <div>
                            <div class="user-name"><?php echo htmlspecialchars($user['name']); ?></div>
                            <div style="margin-top: 5px; color: #666; font-size: 0.9em;">
                                <?php echo htmlspecialchars($user['email']); ?>
                            </div>
                        </div>
                        <span class="user-role role-<?php echo strtolower($user['role']); ?>">
                            <?php echo $user['role']; ?>
                        </span>
                    </div>
                    
                    <div class="user-info">
                        <div class="info-item">
                            <span class="info-label">Phone</span>
                            <span class="info-value"><?php echo htmlspecialchars($user['phone']); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Devices</span>
                            <span class="info-value"><?php echo $user['device_count']; ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Total Events</span>
                            <span class="info-value"><?php echo $user['event_count']; ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Status</span>
                            <span class="info-value">
                                <?php echo $user['is_active'] ? '<span style="color: green;">Active</span>' : '<span style="color: red;">Inactive</span>'; ?>
                            </span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">Joined</span>
                            <span class="info-value"><?php echo date('d M Y', strtotime($user['created_at'])); ?></span>
                        </div>
                        <?php if ($user['last_location_time']): ?>
                        <div class="info-item">
                            <span class="info-label">Last Location</span>
                            <span class="info-value"><?php echo date('d M Y H:i', strtotime($user['last_location_time'])); ?></span>
                        </div>
                        <?php endif; ?>
                    </div>
                    
                    <div class="action-buttons">
                        <a href="user_detail.php?id=<?php echo $user['id']; ?>" class="btn btn-primary">View Details</a>
                        <a href="user_detail.php?id=<?php echo $user['id']; ?>&tab=location" class="btn btn-primary">Live Location</a>
                        <a href="user_detail.php?id=<?php echo $user['id']; ?>&tab=events" class="btn btn-primary">View Events</a>
                    </div>
                </div>
                <?php endforeach; ?>
            </div>
        </div>
    </div>

    <script>
        function filterUsers() {
            const input = document.getElementById('searchInput');
            const filter = input.value.toLowerCase();
            const userCards = document.querySelectorAll('.user-card');
            
            userCards.forEach(card => {
                const name = card.getAttribute('data-name');
                const email = card.getAttribute('data-email');
                const phone = card.getAttribute('data-phone');
                
                if (name.includes(filter) || email.includes(filter) || phone.includes(filter)) {
                    card.style.display = 'block';
                } else {
                    card.style.display = 'none';
                }
            });
        }
    </script>
</body>
</html>

