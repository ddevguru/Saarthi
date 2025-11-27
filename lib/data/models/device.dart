/**
 * SAARTHI Flutter App - Device Model
 */

class Device {
  final int id;
  final String deviceId;
  final String? deviceName;
  final String status;
  final DateTime? lastSeen;
  final String? streamUrl;
  final String? ipAddress;

  Device({
    required this.id,
    required this.deviceId,
    this.deviceName,
    required this.status,
    this.lastSeen,
    this.streamUrl,
    this.ipAddress,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    // Handle id conversion (can be int or string from API)
    int deviceIdInt = 0;
    if (json['id'] != null) {
      deviceIdInt = json['id'] is int 
          ? json['id'] as int 
          : int.tryParse(json['id'].toString()) ?? 0;
    }
    
    // Handle last_seen timestamp
    DateTime? lastSeenDate;
    if (json['last_seen'] != null) {
      try {
        lastSeenDate = DateTime.parse(json['last_seen'].toString());
      } catch (e) {
        lastSeenDate = null;
      }
    }
    
    // Safely handle device_id - it's required but might be missing
    String deviceIdValue = '';
    if (json.containsKey('device_id')) {
      deviceIdValue = json['device_id']?.toString() ?? '';
    } else if (json.containsKey('deviceId')) {
      // Handle camelCase variant
      deviceIdValue = json['deviceId']?.toString() ?? '';
    }
    
    return Device(
      id: deviceIdInt,
      deviceId: deviceIdValue,
      deviceName: json['device_name']?.toString() ?? json['deviceName']?.toString(),
      status: json['status']?.toString() ?? 'OFFLINE',
      lastSeen: lastSeenDate,
      streamUrl: json['stream_url']?.toString() ?? json['streamUrl']?.toString(),
      ipAddress: json['ip_address']?.toString() ?? json['ipAddress']?.toString(),
    );
  }

  bool get isOnline => status == 'ONLINE';
}

