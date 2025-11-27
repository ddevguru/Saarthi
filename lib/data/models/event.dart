/**
 * SAARTHI Flutter App - Sensor Event Model
 */

class SensorEvent {
  final int id;
  final int userId;
  final String eventType;
  final String severity;
  final DateTime createdAt;
  final String? objectLabel;
  final double? objectConfidence;
  final String? imagePath;

  SensorEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.severity,
    required this.createdAt,
    this.objectLabel,
    this.objectConfidence,
    this.imagePath,
  });

  factory SensorEvent.fromJson(Map<String, dynamic> json) {
    return SensorEvent(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      eventType: json['event_type'] ?? '',
      severity: json['severity'] ?? 'MEDIUM',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      objectLabel: json['object_label'],
      objectConfidence: json['object_confidence'] != null
          ? double.tryParse(json['object_confidence'].toString())
          : null,
      imagePath: json['image_path'],
    );
  }

  String get displayName {
    switch (eventType) {
      case 'SOS_TOUCH':
        return 'SOS Alert';
      case 'OBSTACLE_ALERT':
        return 'Obstacle Detected';
      case 'LOUD_SOUND_ALERT':
        return 'Loud Sound';
      case 'GEOFENCE_BREACH':
        return 'Geofence Alert';
      case 'TRIP_DELAY':
        return 'Trip Delay';
      default:
        return eventType;
    }
  }
}

