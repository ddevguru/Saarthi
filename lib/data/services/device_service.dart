/**
 * SAARTHI Flutter App - Device Service
 * Handles device data fetching and status checking
 */

import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import 'api_client.dart';

class DeviceService {
  final ApiClient _apiClient = ApiClient();

  /// Get user's devices from SharedPreferences (stored during login)
  Future<List<Device>> getUserDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesString = prefs.getString('user_devices');
      
      if (devicesString != null && devicesString.isNotEmpty) {
        final deviceStrings = devicesString.split('|||');
        final devices = <Device>[];
        
        for (final deviceStr in deviceStrings) {
          if (deviceStr.isEmpty) continue;
          final parts = deviceStr.split('|');
          if (parts.length >= 4) {
            try {
              DateTime? lastSeen;
              if (parts.length > 4 && parts[4].isNotEmpty) {
                try {
                  lastSeen = DateTime.parse(parts[4]);
                } catch (e) {
                  lastSeen = null;
                }
              }
              
              String? streamUrl;
              String? ipAddress;
              // Use stream_url if available, otherwise build from ip_address
              if (parts.length > 6 && parts[6].isNotEmpty) {
                streamUrl = parts[6];
              } else if (parts.length > 5 && parts[5].isNotEmpty) {
                ipAddress = parts[5];
                streamUrl = 'http://${parts[5]}:81/stream';
              }
              
              final device = Device(
                id: int.tryParse(parts[0]) ?? 0,
                deviceId: parts[1],
                deviceName: parts[2].isEmpty ? null : parts[2],
                status: parts[3],
                lastSeen: lastSeen,
                streamUrl: streamUrl,
                ipAddress: ipAddress,
              );
              devices.add(device);
            } catch (e) {
              // Skip invalid device data
            }
          }
        }
        
        return devices;
      }
      
      // If not in SharedPreferences, try to fetch from API
      return await _fetchDevicesFromAPI();
    } catch (e) {
      // Try API as fallback
      return await _fetchDevicesFromAPI();
    }
  }

  /// Fetch devices from API
  Future<List<Device>> _fetchDevicesFromAPI() async {
    try {
      final response = await _apiClient.get(
        '/device/getUserDevices.php',
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final devicesData = response['data']['devices'] as List;
        final devices = devicesData
            .map((json) => Device.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Save to SharedPreferences for offline access
        await _saveDevicesToPrefs(devices);
        
        return devices;
      }
      return [];
    } catch (e) {
      print('Error fetching devices from API: $e');
      return [];
    }
  }

  Future<void> _saveDevicesToPrefs(List<Device> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceStrings = devices.map((d) {
        return '${d.id}|${d.deviceId}|${d.deviceName ?? ""}|${d.status}|${d.lastSeen?.toIso8601String() ?? ""}|${d.ipAddress ?? ""}|${d.streamUrl ?? ""}';
      }).join('|||');
      await prefs.setString('user_devices', deviceStrings);
    } catch (e) {
      print('Error saving devices to prefs: $e');
    }
  }

  /// Get device by user ID from API
  Future<Device?> getDeviceByUserId(int userId) async {
    try {
      final devices = await getUserDevices();
      // Find device for this user (devices from login are already filtered by user)
      return devices.isNotEmpty ? devices.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Check if device is online based on last_seen timestamp
  bool isDeviceOnline(DateTime? lastSeen, {Duration threshold = const Duration(minutes: 10)}) {
    if (lastSeen == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    return difference < threshold;
  }
  
  /// Check if device is online based on status string
  bool isDeviceOnlineByStatus(String? status) {
    return status != null && (status.toUpperCase() == 'ONLINE' || status.toUpperCase() == 'CONNECTED');
  }
  
  /// Check device online status (combines both methods)
  bool checkDeviceOnline(Device? device) {
    if (device == null) return false;
    
    // First check status field
    if (isDeviceOnlineByStatus(device.status)) {
      return true;
    }
    
    // Then check last_seen timestamp
    return isDeviceOnline(device.lastSeen);
  }

  /// Build stream URL from device IP or use stored stream_url
  String? buildStreamUrl(Device? device, String? ipAddress) {
    if (device?.streamUrl != null && device!.streamUrl!.isNotEmpty) {
      return device.streamUrl;
    }
    
    if (ipAddress != null && ipAddress.isNotEmpty) {
      return 'http://$ipAddress:81/stream';
    }
    
    return null;
  }
}

