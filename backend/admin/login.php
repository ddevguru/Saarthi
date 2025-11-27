<?php
/**
 * SAARTHI Admin Panel - Login
 */

// Set HTML content type for admin panel
header("Content-Type: text/html; charset=UTF-8");

session_start();
require_once __DIR__ . '/../config/database.php';

// Don't include config.php here as it sets JSON headers
// We'll include only what we need
date_default_timezone_set('Asia/Kolkata');

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    
    if ($email && $password) {
        $db = (new Database())->getConnection();
        
        $stmt = $db->prepare("
            SELECT id, name, email, password_hash, role, is_active
            FROM users
            WHERE email = ? AND role = 'ADMIN'
        ");
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        
        if ($user && password_verify($password, $user['password_hash'])) {
            if ($user['is_active']) {
                $_SESSION['user_id'] = $user['id'];
                $_SESSION['user_name'] = $user['name'];
                $_SESSION['user_role'] = $user['role'];
                header('Location: index.php');
                exit;
            } else {
                $error = 'Account is inactive';
            }
        } else {
            $error = 'Invalid email or password';
        }
    } else {
        $error = 'Please fill all fields';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SAARTHI Admin Login</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .login-container {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .login-box {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            width: 100%;
            max-width: 400px;
        }
        .login-box h1 {
            text-align: center;
            margin-bottom: 30px;
            color: #333;
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #666;
        }
        .form-group input {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 1em;
        }
        .error {
            color: #ff6b6b;
            margin-bottom: 15px;
            padding: 10px;
            background: #ffe6e6;
            border-radius: 5px;
        }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            border: none;
            cursor: pointer;
            font-size: 1em;
            transition: background 0.3s;
        }
        .btn:hover {
            background: #5568d3;
        }
        .btn-primary {
            background: #667eea;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-box">
            <h1>SAARTHI Admin Login</h1>
            <?php if ($error): ?>
                <div class="error"><?php echo htmlspecialchars($error); ?></div>
            <?php endif; ?>
            <form method="POST">
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" name="email" required>
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <input type="password" name="password" required>
                </div>
                <button type="submit" class="btn btn-primary" style="width: 100%;">Login</button>
            </form>
        </div>
    </div>
</body>
</html>

