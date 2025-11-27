/**
 * SAARTHI Flutter App - Location Model
 */

class Location {
  final int id;
  final int userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final int? batteryLevel;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.batteryLevel,
    required this.createdAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: json['accuracy'] != null
          ? double.tryParse(json['accuracy'].toString())
          : null,
      speed: json['speed'] != null
          ? double.tryParse(json['speed'].toString())
          : null,
      batteryLevel: json['battery_level'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  String get googleMapsUrl {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }
}

