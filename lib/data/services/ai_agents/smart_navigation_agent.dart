/**
 * SAARTHI AI Agent - Smart Navigation Agent
 * Context-aware navigation assistance with real-time guidance
 * For Mumbai Hackathon - Health IoT Project
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';

class SmartNavigationAgent {
  final String _apiBaseUrl = AppConstants.apiBaseUrl;

  /// Get intelligent navigation guidance based on context
  Future<NavigationGuidance> getNavigationGuidance({
    required double currentLat,
    required double currentLng,
    required String destination,
    String? disabilityType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/getNavigationGuidance.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_lat': currentLat,
          'current_lng': currentLng,
          'destination': destination,
          'disability_type': disabilityType ?? 'NONE',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return NavigationGuidance.fromJson(data['data']);
        }
      }
      
      return NavigationGuidance.empty();
    } catch (e) {
      print('Navigation guidance error: $e');
      return NavigationGuidance.empty();
    }
  }

  /// Get real-time navigation instructions
  Future<List<NavigationInstruction>> getRealTimeInstructions({
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/getRealTimeInstructions.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_lat': currentLat,
          'current_lng': currentLng,
          'target_lat': targetLat,
          'target_lng': targetLng,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data']['instructions'] as List)
              .map((inst) => NavigationInstruction.fromJson(inst))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Real-time instructions error: $e');
      return [];
    }
  }

  /// Detect nearby points of interest (safe zones, landmarks)
  Future<List<PointOfInterest>> detectNearbyPOIs({
    required double lat,
    required double lng,
    double radius = 500.0, // meters
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/detectNearbyPOIs.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'radius': radius,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data']['pois'] as List)
              .map((poi) => PointOfInterest.fromJson(poi))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('POI detection error: $e');
      return [];
    }
  }
}

class NavigationGuidance {
  final String currentInstruction;
  final double distanceToNext;
  final String nextAction; // turn_left, turn_right, go_straight, etc.
  final List<NavigationStep> steps;
  final double estimatedTime;
  final String safetyLevel;

  NavigationGuidance({
    required this.currentInstruction,
    required this.distanceToNext,
    required this.nextAction,
    required this.steps,
    required this.estimatedTime,
    required this.safetyLevel,
  });

  factory NavigationGuidance.fromJson(Map<String, dynamic> json) {
    return NavigationGuidance(
      currentInstruction: json['current_instruction'] ?? 'Continue forward',
      distanceToNext: (json['distance_to_next'] ?? 0.0).toDouble(),
      nextAction: json['next_action'] ?? 'go_straight',
      steps: (json['steps'] as List? ?? [])
          .map((s) => NavigationStep.fromJson(s))
          .toList(),
      estimatedTime: (json['estimated_time'] ?? 0.0).toDouble(),
      safetyLevel: json['safety_level'] ?? 'MODERATE',
    );
  }

  factory NavigationGuidance.empty() {
    return NavigationGuidance(
      currentInstruction: 'Navigation unavailable',
      distanceToNext: 0.0,
      nextAction: 'go_straight',
      steps: [],
      estimatedTime: 0.0,
      safetyLevel: 'MODERATE',
    );
  }
}

class NavigationStep {
  final String instruction;
  final double distance;
  final String direction;
  final double lat;
  final double lng;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.direction,
    required this.lat,
    required this.lng,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      direction: json['direction'] ?? 'forward',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
    );
  }
}

class NavigationInstruction {
  final String instruction;
  final String type; // voice, haptic, visual
  final int priority; // 1-5, 5 being highest
  final DateTime timestamp;

  NavigationInstruction({
    required this.instruction,
    required this.type,
    required this.priority,
    required this.timestamp,
  });

  factory NavigationInstruction.fromJson(Map<String, dynamic> json) {
    return NavigationInstruction(
      instruction: json['instruction'] ?? '',
      type: json['type'] ?? 'voice',
      priority: json['priority'] ?? 3,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

class PointOfInterest {
  final String name;
  final String type; // safe_zone, landmark, building, etc.
  final double lat;
  final double lng;
  final double distance; // meters
  final String description;

  PointOfInterest({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.distance,
    required this.description,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      name: json['name'] ?? '',
      type: json['type'] ?? 'landmark',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      distance: (json['distance'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
    );
  }
}

