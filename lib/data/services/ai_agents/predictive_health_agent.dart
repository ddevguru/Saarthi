/**
 * SAARTHI AI Agent - Predictive Health Analytics Agent
 * Pattern recognition, risk prediction, and proactive health monitoring
 * For Mumbai Hackathon - Health IoT Project
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';

class PredictiveHealthAgent {
  final String _apiBaseUrl = AppConstants.apiBaseUrl;

  /// Predict potential risks based on historical patterns
  Future<RiskPrediction> predictRisk(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/predictRisk.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'prediction_window': '1_hour', // 1_hour, 6_hours, 24_hours
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return RiskPrediction.fromJson(data['data']);
        }
      }
      
      return RiskPrediction.empty();
    } catch (e) {
      print('Risk prediction error: $e');
      return RiskPrediction.empty();
    }
  }

  /// Analyze event patterns to detect anomalies
  Future<AnomalyDetection> detectAnomalies(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/detectAnomalies.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'time_window': '24_hours',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return AnomalyDetection.fromJson(data['data']);
        }
      }
      
      return AnomalyDetection.empty();
    } catch (e) {
      print('Anomaly detection error: $e');
      return AnomalyDetection.empty();
    }
  }

  /// Predict optimal routes based on safety patterns
  Future<RouteSafetyAnalysis> analyzeRouteSafety({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/analyzeRouteSafety.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start_lat': startLat,
          'start_lng': startLng,
          'end_lat': endLat,
          'end_lng': endLng,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return RouteSafetyAnalysis.fromJson(data['data']);
        }
      }
      
      return RouteSafetyAnalysis.empty();
    } catch (e) {
      print('Route safety analysis error: $e');
      return RouteSafetyAnalysis.empty();
    }
  }

  /// Get health insights based on activity patterns
  Future<HealthInsights> getHealthInsights(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/ai/getHealthInsights.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'period': '7_days',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return HealthInsights.fromJson(data['data']);
        }
      }
      
      return HealthInsights.empty();
    } catch (e) {
      print('Health insights error: $e');
      return HealthInsights.empty();
    }
  }
}

class RiskPrediction {
  final double riskScore; // 0.0 to 1.0
  final String riskLevel; // LOW, MEDIUM, HIGH, CRITICAL
  final List<String> riskFactors;
  final List<String> recommendations;
  final DateTime predictedTime;

  RiskPrediction({
    required this.riskScore,
    required this.riskLevel,
    required this.riskFactors,
    required this.recommendations,
    required this.predictedTime,
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    return RiskPrediction(
      riskScore: (json['risk_score'] ?? 0.0).toDouble(),
      riskLevel: json['risk_level'] ?? 'LOW',
      riskFactors: (json['risk_factors'] as List? ?? [])
          .map((f) => f.toString())
          .toList(),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((r) => r.toString())
          .toList(),
      predictedTime: json['predicted_time'] != null
          ? DateTime.parse(json['predicted_time'])
          : DateTime.now(),
    );
  }

  factory RiskPrediction.empty() {
    return RiskPrediction(
      riskScore: 0.0,
      riskLevel: 'LOW',
      riskFactors: [],
      recommendations: [],
      predictedTime: DateTime.now(),
    );
  }
}

class AnomalyDetection {
  final bool hasAnomalies;
  final List<Anomaly> anomalies;
  final String summary;

  AnomalyDetection({
    required this.hasAnomalies,
    required this.anomalies,
    required this.summary,
  });

  factory AnomalyDetection.fromJson(Map<String, dynamic> json) {
    return AnomalyDetection(
      hasAnomalies: json['has_anomalies'] ?? false,
      anomalies: (json['anomalies'] as List? ?? [])
          .map((a) => Anomaly.fromJson(a))
          .toList(),
      summary: json['summary'] ?? 'No anomalies detected',
    );
  }

  factory AnomalyDetection.empty() {
    return AnomalyDetection(
      hasAnomalies: false,
      anomalies: [],
      summary: 'Anomaly detection unavailable',
    );
  }
}

class Anomaly {
  final String type; // unusual_pattern, spike, missing_data, etc.
  final String description;
  final double severity; // 0.0 to 1.0
  final DateTime detectedAt;

  Anomaly({
    required this.type,
    required this.description,
    required this.severity,
    required this.detectedAt,
  });

  factory Anomaly.fromJson(Map<String, dynamic> json) {
    return Anomaly(
      type: json['type'] ?? 'unknown',
      description: json['description'] ?? '',
      severity: (json['severity'] ?? 0.0).toDouble(),
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'])
          : DateTime.now(),
    );
  }
}

class RouteSafetyAnalysis {
  final double safetyScore; // 0.0 to 1.0
  final String safetyLevel; // SAFE, MODERATE, RISKY, DANGEROUS
  final List<RouteSegment> segments;
  final List<String> warnings;
  final String recommendedRoute;

  RouteSafetyAnalysis({
    required this.safetyScore,
    required this.safetyLevel,
    required this.segments,
    required this.warnings,
    required this.recommendedRoute,
  });

  factory RouteSafetyAnalysis.fromJson(Map<String, dynamic> json) {
    return RouteSafetyAnalysis(
      safetyScore: (json['safety_score'] ?? 0.0).toDouble(),
      safetyLevel: json['safety_level'] ?? 'MODERATE',
      segments: (json['segments'] as List? ?? [])
          .map((s) => RouteSegment.fromJson(s))
          .toList(),
      warnings: (json['warnings'] as List? ?? [])
          .map((w) => w.toString())
          .toList(),
      recommendedRoute: json['recommended_route'] ?? '',
    );
  }

  factory RouteSafetyAnalysis.empty() {
    return RouteSafetyAnalysis(
      safetyScore: 0.5,
      safetyLevel: 'MODERATE',
      segments: [],
      warnings: [],
      recommendedRoute: '',
    );
  }
}

class RouteSegment {
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final double safetyScore;
  final String description;

  RouteSegment({
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.safetyScore,
    required this.description,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      startLat: (json['start_lat'] ?? 0.0).toDouble(),
      startLng: (json['start_lng'] ?? 0.0).toDouble(),
      endLat: (json['end_lat'] ?? 0.0).toDouble(),
      endLng: (json['end_lng'] ?? 0.0).toDouble(),
      safetyScore: (json['safety_score'] ?? 0.5).toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class HealthInsights {
  final double activityScore;
  final int totalEvents;
  final int emergencyEvents;
  final double averageRiskLevel;
  final List<String> insights;
  final Map<String, dynamic> patterns;

  HealthInsights({
    required this.activityScore,
    required this.totalEvents,
    required this.emergencyEvents,
    required this.averageRiskLevel,
    required this.insights,
    required this.patterns,
  });

  factory HealthInsights.fromJson(Map<String, dynamic> json) {
    return HealthInsights(
      activityScore: (json['activity_score'] ?? 0.0).toDouble(),
      totalEvents: json['total_events'] ?? 0,
      emergencyEvents: json['emergency_events'] ?? 0,
      averageRiskLevel: (json['average_risk_level'] ?? 0.0).toDouble(),
      insights: (json['insights'] as List? ?? [])
          .map((i) => i.toString())
          .toList(),
      patterns: json['patterns'] ?? {},
    );
  }

  factory HealthInsights.empty() {
    return HealthInsights(
      activityScore: 0.0,
      totalEvents: 0,
      emergencyEvents: 0,
      averageRiskLevel: 0.0,
      insights: [],
      patterns: {},
    );
  }
}

