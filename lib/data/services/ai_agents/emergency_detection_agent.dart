/**
 * SAARTHI AI Agent - Emergency Detection Agent
 * Advanced pattern recognition for emergency situations
 * For Mumbai Hackathon - Health IoT Project
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';

class EmergencyDetectionAgent {
  final String _apiBaseUrl = AppConstants.apiBaseUrl;

  /// Detect emergency situation from multiple sensor inputs
  Future<EmergencyAssessment> assessEmergency({
    required Map<String, dynamic> sensorData,
    String? imageUrl,
    String? audioUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/assessEmergency.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sensor_data': sensorData,
          'image_url': imageUrl,
          'audio_url': audioUrl,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return EmergencyAssessment.fromJson(data['data']);
        }
      }
      
      return EmergencyAssessment.empty();
    } catch (e) {
      print('Emergency assessment error: $e');
      return EmergencyAssessment.empty();
    }
  }

  /// Detect fall detection from sensor patterns
  Future<FallDetection> detectFall({
    required Map<String, dynamic> sensorData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/detectFall.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sensor_data': sensorData,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return FallDetection.fromJson(data['data']);
        }
      }
      
      return FallDetection.empty();
    } catch (e) {
      print('Fall detection error: $e');
      return FallDetection.empty();
    }
  }

  /// Analyze audio for distress signals
  Future<DistressAnalysis> analyzeDistress(String audioUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/analyzeDistress.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio_url': audioUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return DistressAnalysis.fromJson(data['data']);
        }
      }
      
      return DistressAnalysis.empty();
    } catch (e) {
      print('Distress analysis error: $e');
      return DistressAnalysis.empty();
    }
  }
}

class EmergencyAssessment {
  final bool isEmergency;
  final double emergencyScore; // 0.0 to 1.0
  final String emergencyType; // fall, distress, obstacle, medical, etc.
  final double confidence;
  final List<String> indicators;
  final String recommendedAction;

  EmergencyAssessment({
    required this.isEmergency,
    required this.emergencyScore,
    required this.emergencyType,
    required this.confidence,
    required this.indicators,
    required this.recommendedAction,
  });

  factory EmergencyAssessment.fromJson(Map<String, dynamic> json) {
    return EmergencyAssessment(
      isEmergency: json['is_emergency'] ?? false,
      emergencyScore: (json['emergency_score'] ?? 0.0).toDouble(),
      emergencyType: json['emergency_type'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      indicators: (json['indicators'] as List? ?? [])
          .map((i) => i.toString())
          .toList(),
      recommendedAction: json['recommended_action'] ?? 'Monitor situation',
    );
  }

  factory EmergencyAssessment.empty() {
    return EmergencyAssessment(
      isEmergency: false,
      emergencyScore: 0.0,
      emergencyType: 'unknown',
      confidence: 0.0,
      indicators: [],
      recommendedAction: 'No action needed',
    );
  }
}

class FallDetection {
  final bool hasFallen;
  final double confidence;
  final DateTime? fallTime;
  final String fallType; // forward, backward, sideways
  final double impactForce;

  FallDetection({
    required this.hasFallen,
    required this.confidence,
    this.fallTime,
    required this.fallType,
    required this.impactForce,
  });

  factory FallDetection.fromJson(Map<String, dynamic> json) {
    return FallDetection(
      hasFallen: json['has_fallen'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      fallTime: json['fall_time'] != null
          ? DateTime.parse(json['fall_time'])
          : null,
      fallType: json['fall_type'] ?? 'unknown',
      impactForce: (json['impact_force'] ?? 0.0).toDouble(),
    );
  }

  factory FallDetection.empty() {
    return FallDetection(
      hasFallen: false,
      confidence: 0.0,
      fallTime: null,
      fallType: 'unknown',
      impactForce: 0.0,
    );
  }
}

class DistressAnalysis {
  final bool hasDistress;
  final double distressLevel; // 0.0 to 1.0
  final List<String> detectedSounds; // scream, cry, help, etc.
  final double confidence;
  final String analysis;

  DistressAnalysis({
    required this.hasDistress,
    required this.distressLevel,
    required this.detectedSounds,
    required this.confidence,
    required this.analysis,
  });

  factory DistressAnalysis.fromJson(Map<String, dynamic> json) {
    return DistressAnalysis(
      hasDistress: json['has_distress'] ?? false,
      distressLevel: (json['distress_level'] ?? 0.0).toDouble(),
      detectedSounds: (json['detected_sounds'] as List? ?? [])
          .map((s) => s.toString())
          .toList(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      analysis: json['analysis'] ?? 'No distress detected',
    );
  }

  factory DistressAnalysis.empty() {
    return DistressAnalysis(
      hasDistress: false,
      distressLevel: 0.0,
      detectedSounds: [],
      confidence: 0.0,
      analysis: 'Analysis unavailable',
    );
  }
}

