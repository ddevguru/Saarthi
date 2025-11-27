<?php
/**
 * SAARTHI Backend - WhatsApp Service
 * Handles WhatsApp message sending via CallMeBot or similar gateway
 */

class WhatsAppService {
    private $db;

    public function __construct($db) {
        $this->db = $db;
    }

    /**
     * Send WhatsApp message
     * @param string $phoneNumber Phone number with country code (e.g., +919876543210)
     * @param string $message Message text
     * @param int $userId User ID for logging
     * @param int|null $eventId Event ID if triggered by event
     */
    public function sendMessage($phoneNumber, $message, $userId, $eventId = null) {
        // Clean phone number (remove + and spaces, keep only digits)
        $phoneNumber = preg_replace('/[^0-9]/', '', $phoneNumber);
        
        // Remove leading 0 if present (India phone numbers)
        if (strlen($phoneNumber) == 11 && substr($phoneNumber, 0, 1) == '0') {
            $phoneNumber = substr($phoneNumber, 1);
        }
        
        // Ensure country code (add 91 for India if not present)
        if (strlen($phoneNumber) == 10) {
            $phoneNumber = '91' . $phoneNumber;
        }
        
        // Try multiple WhatsApp API methods
        $status = 'FAILED';
        $responseData = '';
        
        // Method 1: CallMeBot API (if API key is valid)
        if (!empty(WHATSAPP_API_KEY) && WHATSAPP_API_KEY != '683bfe5fc5a1d') {
            $url = WHATSAPP_API_URL . '?' . http_build_query([
                'phone' => '+' . $phoneNumber,
                'text' => urlencode($message),
                'apikey' => WHATSAPP_API_KEY
            ]);

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 10);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0');
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $error = curl_error($ch);
            curl_close($ch);
            
            // Check if successful
            if ($httpCode == 200 && !$error && !strpos($response, 'Forbidden') && !strpos($response, '403')) {
                $status = 'SENT';
                $responseData = $response;
            } else {
                $responseData = $response ?: $error;
            }
        }
        
        // Method 2: Alternative WhatsApp API (Twilio, Green-API, etc.)
        // If CallMeBot fails, you can add alternative services here
        if ($status === 'FAILED' && !empty(WHATSAPP_INSTANCE_ID)) {
            // Example: Green-API format
            // $url = "https://api.green-api.com/waInstance" . WHATSAPP_INSTANCE_ID . "/sendMessage/" . WHATSAPP_API_KEY;
            // Use POST with JSON body: {"chatId": "+919876543210@c.us", "message": "Hello"}
        }
        
        // If still failed, log for manual sending
        if ($status === 'FAILED') {
            error_log("WhatsApp message failed for $phoneNumber: $responseData");
        }

        // Log notification
        $stmt = $this->db->prepare("
            INSERT INTO notification_logs (user_id, event_id, target_phone, channel, message, status, response_data, sent_at)
            VALUES (?, ?, ?, 'WHATSAPP', ?, ?, ?, NOW())
        ");
        $stmt->execute([
            $userId,
            $eventId,
            '+' . $phoneNumber,
            $message,
            $status,
            $responseData
        ]);

        return $status === 'SENT';
    }

    /**
     * Send alert with location link
     */
    public function sendAlert($phoneNumber, $userName, $eventType, $latitude = null, $longitude = null, $userId = null, $eventId = null) {
        $message = "🚨 SAARTHI Safety Alert\n\n";
        $message .= "User: " . $userName . "\n";
        $message .= "Event: " . $eventType . "\n";
        $message .= "Time: " . date('d M Y, h:i A') . "\n";
        
        if ($latitude && $longitude) {
            $mapsUrl = "https://www.google.com/maps?q=" . $latitude . "," . $longitude;
            $message .= "📍 Location: " . $mapsUrl . "\n";
        }
        
        $message .= "\nPlease check the SAARTHI app for details.";
        
        return $this->sendMessage($phoneNumber, $message, $userId, $eventId);
    }
}

