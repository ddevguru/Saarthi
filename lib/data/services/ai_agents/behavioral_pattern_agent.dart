/**
 * SAARTHI AI Agent - Behavioral Pattern Learning Agent
 * Learn user patterns and adapt to individual needs
 * For Mumbai Hackathon - Health IoT Project
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';

class BehavioralPatternAgent {
  final String _apiBaseUrl = AppConstants.apiBaseUrl;

  /// Learn user behavior patterns
  Future<UserPatterns> learnUserPatterns(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/learnUserPatterns.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'learning_period': '30_days',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return UserPatterns.fromJson(data['data']);
        }
      }
      
      return UserPatterns.empty();
    } catch (e) {
      print('Pattern learning error: $e');
      return UserPatterns.empty();
    }
  }

  /// Get personalized recommendations based on patterns
  Future<List<PersonalizedRecommendation>> getPersonalizedRecommendations(
    String userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/getPersonalizedRecommendations.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data']['recommendations'] as List)
              .map((r) => PersonalizedRecommendation.fromJson(r))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Personalized recommendations error: $e');
      return [];
    }
  }

  /// Detect unusual behavior (anomaly in patterns)
  Future<BehaviorAnomaly> detectBehaviorAnomaly(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/detectBehaviorAnomaly.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return BehaviorAnomaly.fromJson(data['data']);
        }
      }
      
      return BehaviorAnomaly.empty();
    } catch (e) {
      print('Behavior anomaly detection error: $e');
      return BehaviorAnomaly.empty();
    }
  }
}

class UserPatterns {
  final Map<String, dynamic> activityPatterns;
  final Map<String, dynamic> locationPatterns;
  final Map<String, dynamic> timePatterns;
  final double patternConfidence;
  final List<String> identifiedHabits;

  UserPatterns({
    required this.activityPatterns,
    required this.locationPatterns,
    required this.timePatterns,
    required this.patternConfidence,
    required this.identifiedHabits,
  });

  factory UserPatterns.fromJson(Map<String, dynamic> json) {
    return UserPatterns(
      activityPatterns: json['activity_patterns'] ?? {},
      locationPatterns: json['location_patterns'] ?? {},
      timePatterns: json['time_patterns'] ?? {},
      patternConfidence: (json['pattern_confidence'] ?? 0.0).toDouble(),
      identifiedHabits: (json['identified_habits'] as List? ?? [])
          .map((h) => h.toString())
          .toList(),
    );
  }

  factory UserPatterns.empty() {
    return UserPatterns(
      activityPatterns: {},
      locationPatterns: {},
      timePatterns: {},
      patternConfidence: 0.0,
      identifiedHabits: [],
    );
  }
}

class PersonalizedRecommendation {
  final String type; // safety, navigation, health, etc.
  final String title;
  final String description;
  final int priority; // 1-5
  final String action;

  PersonalizedRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.action,
  });

  factory PersonalizedRecommendation.fromJson(Map<String, dynamic> json) {
    return PersonalizedRecommendation(
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 3,
      action: json['action'] ?? '',
    );
  }
}

class BehaviorAnomaly {
  final bool hasAnomaly;
  final String anomalyType;
  final String description;
  final double severity;
  final DateTime detectedAt;

  BehaviorAnomaly({
    required this.hasAnomaly,
    required this.anomalyType,
    required this.description,
    required this.severity,
    required this.detectedAt,
  });

  factory BehaviorAnomaly.fromJson(Map<String, dynamic> json) {
    return BehaviorAnomaly(
      hasAnomaly: json['has_anomaly'] ?? false,
      anomalyType: json['anomaly_type'] ?? 'unknown',
      description: json['description'] ?? '',
      severity: (json['severity'] ?? 0.0).toDouble(),
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'])
          : DateTime.now(),
    );
  }

  factory BehaviorAnomaly.empty() {
    return BehaviorAnomaly(
      hasAnomaly: false,
      anomalyType: 'unknown',
      description: '',
      severity: 0.0,
      detectedAt: DateTime.now(),
    );
  }
}

