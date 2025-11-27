/**
 * SAARTHI Flutter App - Authentication Service
 */

import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/device.dart';
import 'api_client.dart';
import '../../core/constants.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiClient.post(
      AppConstants.loginEndpoint,
      {
        'email': email,
        'password': password,
      },
      requireAuth: false,
    );

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      
      await _apiClient.setToken(token);
      
      final prefs = await SharedPreferences.getInstance();
      // Convert id to int (handles both string and int from API)
      final userId = data['user']['id'] is int 
          ? data['user']['id'] as int 
          : int.parse(data['user']['id'].toString());
      await prefs.setInt(AppConstants.prefUserId, userId);
      await prefs.setString(AppConstants.prefUserRole, data['user']['role'] as String);
      
      // Parse devices if available
      List<Device> devices = [];
      if (data['devices'] != null && data['devices'] is List) {
        try {
          devices = (data['devices'] as List)
              .where((d) => d != null && d is Map<String, dynamic>)
              .map((deviceJson) {
                try {
                  // Ensure device_id exists in the JSON
                  final deviceMap = deviceJson as Map<String, dynamic>;
                  if (!deviceMap.containsKey('device_id') || deviceMap['device_id'] == null) {
                    deviceMap['device_id'] = '';
                  }
                  return Device.fromJson(deviceMap);
                } catch (e) {
                  print('Error parsing device: $e');
                  return null;
                }
              })
              .whereType<Device>()
              .toList();
        } catch (e) {
          print('Error parsing devices list: $e');
          devices = [];
        }
        
        // Store devices in SharedPreferences
        if (devices.isNotEmpty && devices.first.deviceId.isNotEmpty) {
          await prefs.setString(AppConstants.prefDeviceId, devices.first.deviceId);
          
          // Store devices as formatted string for easy parsing
          final deviceStrings = (data['devices'] as List)
              .where((d) => d != null && d is Map<String, dynamic>)
              .map((d) {
                final deviceMap = d as Map<String, dynamic>;
                return '${deviceMap['id'] ?? ''}|${deviceMap['device_id'] ?? ''}|${deviceMap['device_name'] ?? ''}|${deviceMap['status'] ?? 'OFFLINE'}|${deviceMap['last_seen'] ?? ''}|${deviceMap['ip_address'] ?? ''}|${deviceMap['stream_url'] ?? ''}';
              })
              .toList();
          
          await prefs.setString('user_devices', deviceStrings.join('|||'));
        } else {
          // Clear old device data if no devices or empty device_id
          await prefs.remove('user_devices');
          await prefs.remove(AppConstants.prefDeviceId);
        }
      }
      
      return {
        'success': true,
        'user': User.fromJson(data['user']),
        'token': token,
        'devices': devices,
      };
    }
    
    throw Exception(response['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    String languagePreference = 'en',
    String disabilityType = 'NONE',
  }) async {
    final response = await _apiClient.post(
      AppConstants.registerEndpoint,
      {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
        'language_preference': languagePreference,
        'disability_type': disabilityType,
      },
      requireAuth: false,
    );

    if (response['success'] == true) {
      return {'success': true, 'message': response['message']};
    }
    
    throw Exception(response['message'] ?? 'Registration failed');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefToken);
    await prefs.remove(AppConstants.prefUserId);
    await prefs.remove(AppConstants.prefUserRole);
    await _apiClient.setToken(null);
  }

  Future<bool> isLoggedIn() async {
    final token = await _apiClient.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefUserRole);
  }
}

