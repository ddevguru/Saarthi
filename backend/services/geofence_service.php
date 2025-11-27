<?php
/**
 * SAARTHI Backend - Geofencing Service
 * Handles safe zone detection and alerts
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/whatsapp_service.php';

class GeofenceService {
    private $db;

    public function __construct($db) {
        $this->db = $db;
    }

    /**
     * Calculate distance between two coordinates (Haversine formula)
     * Returns distance in meters
     */
    private function calculateDistance($lat1, $lon1, $lat2, $lon2) {
        $earthRadius = 6371000; // meters
        
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        
        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);
        
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        
        return $earthRadius * $c;
    }

    /**
     * Check if user is within or outside safe zones
     * Triggers GEOFENCE_BREACH event if needed
     */
    public function checkGeofence($userId, $latitude, $longitude) {
        if (!$latitude || !$longitude) {
            return; // No location data
        }

        // Get all active safe zones for user
        $stmt = $this->db->prepare("
            SELECT id, name, center_lat, center_lon, radius_meters, is_restricted, 
                   active_start_time, active_end_time
            FROM safe_zones
            WHERE user_id = ? AND is_active = 1
        ");
        $stmt->execute([$userId]);
        $zones = $stmt->fetchAll();

        $currentTime = date('H:i:s');

        foreach ($zones as $zone) {
            // Check time window if set
            if ($zone['active_start_time'] && $zone['active_end_time']) {
                if ($currentTime < $zone['active_start_time'] || $currentTime > $zone['active_end_time']) {
                    continue; // Zone not active at this time
                }
            }

            $distance = $this->calculateDistance(
                $latitude, $longitude,
                $zone['center_lat'], $zone['center_lon']
            );

            $isInside = $distance <= $zone['radius_meters'];

            // Check for breach
            if ($zone['is_restricted']) {
                // Restricted zone: alert when entering
                if ($isInside) {
                    $this->triggerGeofenceBreach($userId, $zone, 'ENTERED_RESTRICTED', $latitude, $longitude);
                }
            } else {
                // Safe zone: alert when exiting
                if (!$isInside) {
                    $this->triggerGeofenceBreach($userId, $zone, 'EXITED_SAFE_ZONE', $latitude, $longitude);
                }
            }
        }
    }

    /**
     * Trigger geofence breach event and send alerts
     */
    private function triggerGeofenceBreach($userId, $zone, $breachType, $latitude, $longitude) {
        // Check if recent breach already logged (avoid spam)
        $stmt = $this->db->prepare("
            SELECT id FROM sensor_events
            WHERE user_id = ? 
            AND event_type = 'GEOFENCE_BREACH'
            AND created_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
        ");
        $stmt->execute([$userId]);
        if ($stmt->fetch()) {
            return; // Recent breach already logged
        }

        // Create event
        $stmt = $this->db->prepare("
            INSERT INTO sensor_events (user_id, event_type, sensor_payload, severity)
            VALUES (?, 'GEOFENCE_BREACH', ?, 'HIGH')
        ");
        $payload = json_encode([
            'zone_id' => $zone['id'],
            'zone_name' => $zone['name'],
            'breach_type' => $breachType,
            'latitude' => $latitude,
            'longitude' => $longitude
        ]);
        $stmt->execute([$userId, $payload]);
        $eventId = $this->db->lastInsertId();

        // Get user info
        $stmt = $this->db->prepare("SELECT name, phone FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();

        // Send WhatsApp to parents
        $whatsappService = new WhatsAppService($this->db);
        $message = "⚠️ Geofence Alert\n\n";
        $message .= "User: " . $user['name'] . "\n";
        $message .= "Zone: " . $zone['name'] . "\n";
        $message .= "Status: " . ($breachType === 'ENTERED_RESTRICTED' ? 'Entered Restricted Area' : 'Exited Safe Zone') . "\n";
        $message .= "Time: " . date('d M Y, h:i A') . "\n";
        $mapsUrl = "https://www.google.com/maps?q=" . $latitude . "," . $longitude;
        $message .= "Location: " . $mapsUrl;

        $stmt = $this->db->prepare("
            SELECT u.phone FROM users u
            INNER JOIN parent_child_links pcl ON u.id = pcl.parent_id
            WHERE pcl.child_id = ? AND pcl.status = 'ACTIVE'
        ");
        $stmt->execute([$userId]);
        $parents = $stmt->fetchAll();

        foreach ($parents as $parent) {
            $whatsappService->sendMessage($parent['phone'], $message, $userId, $eventId);
        }
    }
}

