<?php
/**
 * SAARTHI Backend - Authentication Middleware
 * Validates JWT tokens and user sessions
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/config.php';

class AuthMiddleware {
    private $db;

    public function __construct() {
        $database = new Database();
        $this->db = $database->getConnection();
    }

    /**
     * Validate JWT token from Authorization header
     */
    public function validateToken() {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? null;

        if (!$authHeader) {
            sendResponse(false, "Authorization token required", null, 401);
        }

        // Extract token (Bearer <token>)
        $token = str_replace('Bearer ', '', $authHeader);

        if (empty($token)) {
            sendResponse(false, "Invalid authorization token", null, 401);
        }

        // Verify token in database
        $stmt = $this->db->prepare("
            SELECT at.*, u.id as user_id, u.role, u.is_active
            FROM auth_tokens at
            INNER JOIN users u ON at.user_id = u.id
            WHERE at.token = ? 
            AND at.is_revoked = 0 
            AND at.expires_at > NOW()
        ");
        $stmt->execute([$token]);

        $tokenData = $stmt->fetch();

        if (!$tokenData) {
            sendResponse(false, "Invalid or expired token", null, 401);
        }

        if (!$tokenData['is_active']) {
            sendResponse(false, "User account is inactive", null, 403);
        }

        // Return user data
        return [
            'user_id' => $tokenData['user_id'],
            'role' => $tokenData['role'],
            'token_id' => $tokenData['id']
        ];
    }

    /**
     * Check if user has required role
     */
    public function requireRole($allowedRoles) {
        $user = $this->validateToken();
        if (!in_array($user['role'], $allowedRoles)) {
            sendResponse(false, "Insufficient permissions", null, 403);
        }
        return $user;
    }

    /**
     * Generate simple token (for basic auth, can be enhanced with JWT library)
     */
    public static function generateToken($userId) {
        $token = bin2hex(random_bytes(32));
        $expiresAt = date('Y-m-d H:i:s', time() + JWT_EXPIRY);
        
        $database = new Database();
        $db = $database->getConnection();
        
        $stmt = $db->prepare("
            INSERT INTO auth_tokens (user_id, token, token_type, expires_at, ip_address)
            VALUES (?, ?, 'ACCESS', ?, ?)
        ");
        $stmt->execute([
            $userId,
            $token,
            $expiresAt,
            $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
        
        return $token;
    }
}

