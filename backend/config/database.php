<?php
/**
 * SAARTHI Backend - Database Configuration
 * Ultra-low-cost IoT Assistive System for India
 */

class Database {
    private $host = "103.120.179.212";
    private $db_name = "initstor_grocery";
    private $username = "sources";
    private $password = "Sources@123";
    private $conn = null;

    public function getConnection() {
        try {
            $this->conn = new PDO(
                "mysql:host=" . $this->host . ";dbname=" . $this->db_name . ";charset=utf8mb4",
                $this->username,
                $this->password,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
        } catch(PDOException $e) {
            error_log("Database connection error: " . $e->getMessage());
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Database connection failed"
            ]);
            exit;
        }
        return $this->conn;
    }
}

