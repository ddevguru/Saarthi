
import 'api_client.dart';

class DeviceTokenService {
  final ApiClient _apiClient = ApiClient();

  /// Generate device token for ESP32
  Future<Map<String, dynamic>> generateDeviceToken(String deviceId) async {
    try {
      final response = await _apiClient.post(
        '/device/generateToken.php',
        {
          'device_id': deviceId,
        },
        requireAuth: true,
      );

      // Handle different response formats
      if (response['success'] == true) {
        // Check if data is nested
        if (response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          return {
            'success': true,
            'device_token': data['device_token'] as String,
            'device_id': data['device_id'] as String,
          };
        } 
        // Check if token is directly in response
        else if (response['device_token'] != null) {
          return {
            'success': true,
            'device_token': response['device_token'] as String,
            'device_id': response['device_id'] as String? ?? deviceId,
          };
        }
      }

      // Handle error response
      final errorMsg = response['message'] ?? 'Failed to generate device token';
      return {
        'success': false,
        'error': errorMsg.toString(),
      };
    } catch (e) {
      String errorMsg = e.toString();
      
      // Remove "Exception: " prefix if present
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      
      // Handle specific error cases
      if (errorMsg.contains('401') || errorMsg.contains('Unauthorized') || errorMsg.contains('Authentication required')) {
        errorMsg = 'Please login first to generate device token';
      } else if (errorMsg.contains('timeout') || errorMsg.contains('TimeoutException')) {
        errorMsg = 'Request timeout. Please check your internet connection and try again.';
      } else if (errorMsg.contains('SocketException') || errorMsg.contains('Failed host lookup') || errorMsg.contains('Cannot connect')) {
        errorMsg = 'Cannot connect to server. Please check your internet connection.';
      } else if (errorMsg.contains('Network error')) {
        // Extract actual error from network error message
        if (errorMsg.contains(':')) {
          final parts = errorMsg.split(':');
          if (parts.length > 1) {
            errorMsg = parts.sublist(1).join(':').trim();
          }
        }
        if (errorMsg == 'Network error') {
          errorMsg = 'Network error. Please check your internet connection.';
        }
      }
      
      return {
        'success': false,
        'error': errorMsg,
      };
    }
  }

  /// Get device token (if already generated)
  Future<String?> getDeviceToken(String deviceId) async {
    // Tokens are stored on backend, not in app
    // App generates token and ESP32 uses it
    return null;
  }
}

