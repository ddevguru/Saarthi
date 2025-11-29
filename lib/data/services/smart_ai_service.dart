/**
 * SAARTHI Flutter App - Smart AI Service
 * Agentic AI features: Context-aware, proactive, intelligent responses
 * Integrated with multiple AI agents for Mumbai Hackathon
 */

import 'device_service.dart';
import 'ai_agents/image_analysis_agent.dart';
import 'ai_agents/predictive_health_agent.dart';
import 'ai_agents/smart_navigation_agent.dart';
import 'ai_agents/emergency_detection_agent.dart';
import 'ai_agents/behavioral_pattern_agent.dart';

class SmartAIService {
  final DeviceService _deviceService = DeviceService();
  
  // AI Agents
  final ImageAnalysisAgent _imageAgent = ImageAnalysisAgent();
  final PredictiveHealthAgent _healthAgent = PredictiveHealthAgent();
  final SmartNavigationAgent _navigationAgent = SmartNavigationAgent();
  final EmergencyDetectionAgent _emergencyAgent = EmergencyDetectionAgent();
  final BehavioralPatternAgent _patternAgent = BehavioralPatternAgent();
  
  // Context tracking
  Map<String, dynamic> _userContext = {};
  List<Map<String, dynamic>> _recentInteractions = [];
  DateTime? _lastProactiveAlert;
  
  /// Analyze current situation and provide intelligent insights
  Future<Map<String, dynamic>> analyzeSituation() async {
    final devices = await _deviceService.getUserDevices();
    final device = devices.isNotEmpty ? devices.first : null;
    
    final analysis = <String, dynamic>{
      'risk_level': 'LOW',
      'recommendations': <String>[],
      'alerts': <String>[],
      'context': <String, dynamic>{},
    };
    
    // Device status analysis
    if (device == null) {
      analysis['risk_level'] = 'MEDIUM';
      analysis['alerts'].add('No device connected. Safety monitoring is limited.');
      analysis['recommendations'].add('Please connect your ESP32-CAM device for full protection.');
    } else {
      final isOnline = _deviceService.isDeviceOnline(device.lastSeen);
      if (!isOnline) {
        analysis['risk_level'] = 'MEDIUM';
        analysis['alerts'].add('Device is offline. Last seen ${_formatTimeAgo(device.lastSeen)}.');
        analysis['recommendations'].add('Check device connection and WiFi signal.');
      }
    }
    
    // Time-based context
    final hour = DateTime.now().hour;
    if (hour >= 21 || hour < 6) {
      analysis['context']['time_of_day'] = 'night';
      analysis['recommendations'].add('It\'s nighttime. Stay in well-lit areas.');
      if (analysis['risk_level'] == 'LOW') {
        analysis['risk_level'] = 'MEDIUM';
      }
    } else if (hour >= 18) {
      analysis['context']['time_of_day'] = 'evening';
      analysis['recommendations'].add('Evening hours. Be extra cautious while navigating.');
    }
    
    // Location context (if available)
    // TODO: Get current location and analyze
    
    return analysis;
  }

  /// Proactive alert generation based on patterns
  Future<List<String>> generateProactiveAlerts() async {
    final alerts = <String>[];
    
    // Check if we should alert (not too frequent)
    if (_lastProactiveAlert != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastProactiveAlert!);
      if (timeSinceLastAlert < const Duration(minutes: 10)) {
        return alerts; // Don't spam alerts
      }
    }
    
    final devices = await _deviceService.getUserDevices();
    if (devices.isEmpty) {
      alerts.add('Device not connected. Connect your device for safety monitoring.');
      _lastProactiveAlert = DateTime.now();
      return alerts;
    }
    
    final device = devices.first;
    final isOnline = _deviceService.isDeviceOnline(device.lastSeen);
    
    if (!isOnline) {
      final offlineDuration = DateTime.now().difference(device.lastSeen ?? DateTime.now());
      if (offlineDuration > const Duration(minutes: 10)) {
        alerts.add('Your device has been offline for ${offlineDuration.inMinutes} minutes. Please check the connection.');
        _lastProactiveAlert = DateTime.now();
      }
    }
    
    // Time-based proactive suggestions
    final hour = DateTime.now().hour;
    if (hour == 20 && _lastProactiveAlert == null) {
      alerts.add('It\'s getting late. Make sure you\'re heading to a safe location.');
      _lastProactiveAlert = DateTime.now();
    }
    
    return alerts;
  }

  /// Intelligent response based on user query and context
  Future<String> getIntelligentResponse(String query) async {
    final lowerQuery = query.toLowerCase();
    final context = await analyzeSituation();
    
    // Context-aware responses
    if (lowerQuery.contains('safe') || lowerQuery.contains('risk')) {
      final riskLevel = context['risk_level'] as String;
      if (riskLevel == 'LOW') {
        return 'You\'re in a safe situation. Your device is online and monitoring your surroundings.';
      } else if (riskLevel == 'MEDIUM') {
        return 'There are some concerns. ${context['alerts'].join(' ')} Please take necessary precautions.';
      } else {
        return 'High risk situation detected! ${context['alerts'].join(' ')} Please seek help immediately.';
      }
    }
    
    if (lowerQuery.contains('recommend') || lowerQuery.contains('suggest')) {
      final recommendations = context['recommendations'] as List<String>;
      if (recommendations.isNotEmpty) {
        return 'Based on your current situation: ${recommendations.join(' Also, ')}';
      }
      return 'Everything looks good! Continue with your activities safely.';
    }
    
    // Default intelligent response
    return _generateContextualResponse(context);
  }

  String _generateContextualResponse(Map<String, dynamic> context) {
    final riskLevel = context['risk_level'] as String;
    final recommendations = context['recommendations'] as List<String>;
    
    if (riskLevel == 'LOW' && recommendations.isEmpty) {
      return 'All systems are operational. You\'re safe and your device is monitoring your surroundings.';
    }
    
    String response = 'Current status: ';
    if (riskLevel == 'LOW') {
      response += 'Low risk. ';
    } else if (riskLevel == 'MEDIUM') {
      response += 'Moderate risk. ';
    } else {
      response += 'High risk. ';
    }
    
    if (recommendations.isNotEmpty) {
      response += 'Recommendations: ${recommendations.first}';
    }
    
    return response;
  }

  /// Predict potential issues based on patterns
  Future<List<String>> predictPotentialIssues() async {
    final predictions = <String>[];
    
    // Analyze device patterns
    final devices = await _deviceService.getUserDevices();
    if (devices.isNotEmpty) {
      final device = devices.first;
      final isOnline = _deviceService.isDeviceOnline(device.lastSeen);
      
      if (!isOnline && device.lastSeen != null) {
        final offlineTime = DateTime.now().difference(device.lastSeen!);
        if (offlineTime > const Duration(minutes: 30)) {
          predictions.add('Device may have connectivity issues. Check WiFi signal strength.');
        }
      }
    }
    
    // Time-based predictions
    final hour = DateTime.now().hour;
    if (hour >= 22) {
      predictions.add('Late night travel detected. Ensure you\'re in a safe location.');
    }
    
    return predictions;
  }

  /// Learn from user interactions (simple pattern learning)
  void recordInteraction(String query, String response, String? action) {
    _recentInteractions.add({
      'query': query,
      'response': response,
      'action': action,
      'timestamp': DateTime.now(),
    });
    
    // Keep only last 50 interactions
    if (_recentInteractions.length > 50) {
      _recentInteractions.removeAt(0);
    }
    
    // Update context based on interactions
    _updateContextFromInteractions();
  }

  void _updateContextFromInteractions() {
    // Simple pattern detection
    final recentQueries = _recentInteractions
        .where((i) => DateTime.now().difference(i['timestamp'] as DateTime) < const Duration(hours: 1))
        .map((i) => i['query'] as String)
        .toList();
    
    // Detect common patterns
    if (recentQueries.any((q) => q.toLowerCase().contains('device'))) {
      _userContext['frequent_device_queries'] = true;
    }
    
    if (recentQueries.any((q) => q.toLowerCase().contains('location'))) {
      _userContext['frequent_location_queries'] = true;
    }
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return "recently";
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes} minutes ago";
    if (diff.inDays < 1) return "${diff.inHours} hours ago";
    return "${diff.inDays} days ago";
  }

  /// Get AI-powered comprehensive analysis
  Future<Map<String, dynamic>> getComprehensiveAnalysis(String userId) async {
    final analysis = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'risk_assessment': {},
      'recommendations': <String>[],
      'alerts': <String>[],
      'ai_insights': <String, dynamic>{},
    };

    try {
      // Get risk prediction
      final riskPrediction = await _healthAgent.predictRisk(userId);
      analysis['risk_assessment'] = {
        'risk_score': riskPrediction.riskScore,
        'risk_level': riskPrediction.riskLevel,
        'risk_factors': riskPrediction.riskFactors,
      };
      analysis['recommendations'].addAll(riskPrediction.recommendations);

      // Get health insights
      final healthInsights = await _healthAgent.getHealthInsights(userId);
      analysis['ai_insights']['health'] = {
        'activity_score': healthInsights.activityScore,
        'total_events': healthInsights.totalEvents,
        'emergency_events': healthInsights.emergencyEvents,
        'insights': healthInsights.insights,
      };

      // Get personalized recommendations
      final personalizedRecs = await _patternAgent.getPersonalizedRecommendations(userId);
      analysis['recommendations'].addAll(
        personalizedRecs.map((r) => r.description).toList(),
      );

      // Check for anomalies
      final anomalies = await _healthAgent.detectAnomalies(userId);
      if (anomalies.hasAnomalies) {
        analysis['alerts'].addAll(
          anomalies.anomalies.map((a) => a.description).toList(),
        );
      }

      // Check behavior anomalies
      final behaviorAnomaly = await _patternAgent.detectBehaviorAnomaly(userId);
      if (behaviorAnomaly.hasAnomaly) {
        analysis['alerts'].add(behaviorAnomaly.description);
      }
    } catch (e) {
      print('Comprehensive analysis error: $e');
    }

    return analysis;
  }

  /// Analyze image with AI
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageUrl) async {
    try {
      final result = await _imageAgent.analyzeImage(imageUrl);
      return {
        'objects_detected': result.objects.length,
        'obstacle_info': {
          'has_obstacle': result.obstacleInfo.hasObstacle,
          'type': result.obstacleInfo.obstacleType,
          'distance': result.obstacleInfo.distance,
          'recommendation': result.obstacleInfo.recommendation,
        },
        'scene_type': result.scene.sceneType,
        'summary': result.summary,
        'confidence': result.confidence,
      };
    } catch (e) {
      print('Image AI analysis error: $e');
      return {'error': 'Image analysis unavailable'};
    }
  }

  /// Get smart navigation guidance
  Future<Map<String, dynamic>> getSmartNavigation({
    required double currentLat,
    required double currentLng,
    required String destination,
    String? disabilityType,
  }) async {
    try {
      final guidance = await _navigationAgent.getNavigationGuidance(
        currentLat: currentLat,
        currentLng: currentLng,
        destination: destination,
        disabilityType: disabilityType,
      );

      return {
        'current_instruction': guidance.currentInstruction,
        'next_action': guidance.nextAction,
        'distance_to_next': guidance.distanceToNext,
        'estimated_time': guidance.estimatedTime,
        'safety_level': guidance.safetyLevel,
        'steps': guidance.steps.length,
      };
    } catch (e) {
      print('Smart navigation error: $e');
      return {'error': 'Navigation unavailable'};
    }
  }

  /// Assess emergency with AI
  Future<Map<String, dynamic>> assessEmergencyWithAI({
    required Map<String, dynamic> sensorData,
    String? imageUrl,
    String? audioUrl,
  }) async {
    try {
      final assessment = await _emergencyAgent.assessEmergency(
        sensorData: sensorData,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
      );

      return {
        'is_emergency': assessment.isEmergency,
        'emergency_score': assessment.emergencyScore,
        'emergency_type': assessment.emergencyType,
        'confidence': assessment.confidence,
        'indicators': assessment.indicators,
        'recommended_action': assessment.recommendedAction,
      };
    } catch (e) {
      print('Emergency AI assessment error: $e');
      return {'error': 'Emergency assessment unavailable'};
    }
  }

  /// Get real-time health monitoring insights
  Future<Map<String, dynamic>> getRealTimeHealthMonitoring(String userId) async {
    try {
      final healthInsights = await _healthAgent.getHealthInsights(userId);
      final riskPrediction = await _healthAgent.predictRisk(userId);
      
      return {
        'health_score': healthInsights.activityScore,
        'risk_level': riskPrediction.riskLevel,
        'recommendations': riskPrediction.recommendations,
        'alerts': healthInsights.emergencyEvents > 0 
            ? ['${healthInsights.emergencyEvents} emergency events detected recently']
            : [],
      };
    } catch (e) {
      print('Real-time health monitoring error: $e');
      return {'error': 'Health monitoring unavailable'};
    }
  }

  /// Get route safety analysis
  Future<Map<String, dynamic>> analyzeRouteSafety({
    required String userId,
    required String origin,
    required String destination,
  }) async {
    try {
      // Geocode origin and destination to get coordinates
      // For now, use default coordinates - backend will handle geocoding
      final safety = await _healthAgent.analyzeRouteSafety(
        startLat: 0.0, // Will be geocoded in backend
        startLng: 0.0,
        endLat: 0.0,
        endLng: 0.0,
      );

      return {
        'safety_score': safety.safetyScore,
        'risk_factors': safety.warnings,
        'recommendations': safety.warnings,
        'alternative_routes': [],
      };
    } catch (e) {
      print('Route safety analysis error: $e');
      return {'error': 'Route safety analysis unavailable'};
    }
  }

  /// Detect nearby points of interest for accessibility
  Future<Map<String, dynamic>> getAccessiblePOIs({
    required String userId,
    required double lat,
    required double lng,
    String? disabilityType,
  }) async {
    try {
      final pois = await _navigationAgent.detectNearbyPOIs(
        lat: lat,
        lng: lng,
      );

      return {
        'pois': pois.map((p) => {
          'name': p.name,
          'type': p.type,
          'distance': p.distance,
        }).toList(),
        'accessible_count': pois.length,
        'recommendations': [],
      };
    } catch (e) {
      print('POI detection error: $e');
      return {'error': 'POI detection unavailable'};
    }
  }

  /// Get personalized daily insights
  Future<Map<String, dynamic>> getDailyInsights(String userId) async {
    try {
      final healthInsights = await _healthAgent.getHealthInsights(userId);
      final personalizedRecs = await _patternAgent.getPersonalizedRecommendations(userId);

      return {
        'daily_activity_score': healthInsights.activityScore,
        'personalized_tips': personalizedRecs.map((r) => r.description).toList(),
        'health_trend': healthInsights.insights,
      };
    } catch (e) {
      print('Daily insights error: $e');
      return {'error': 'Daily insights unavailable'};
    }
  }

  /// Enhanced situation analysis with all AI agents
  Future<Map<String, dynamic>> getEnhancedSituationAnalysis(String userId) async {
    final analysis = await analyzeSituation();
    
    try {
      // Add image analysis if device has stream URL (can get latest snapshot)
      final devices = await _deviceService.getUserDevices();
      if (devices.isNotEmpty && devices.first.streamUrl != null) {
        // Use stream URL to get snapshot for analysis
        try {
          final imageAnalysis = await _imageAgent.analyzeImage(devices.first.streamUrl!);
          analysis['image_analysis'] = {
            'objects_detected': imageAnalysis.objects.length,
            'scene_type': imageAnalysis.scene.sceneType,
            'has_obstacle': imageAnalysis.obstacleInfo.hasObstacle,
          };
        } catch (e) {
          print('Image analysis error: $e');
        }
      }

      // Add health insights
      final healthInsights = await _healthAgent.getHealthInsights(userId);
      analysis['health_insights'] = {
        'activity_score': healthInsights.activityScore,
        'total_events': healthInsights.totalEvents,
        'emergency_events': healthInsights.emergencyEvents,
      };

      // Add behavioral patterns
      final behaviorPattern = await _patternAgent.getPersonalizedRecommendations(userId);
      analysis['behavioral_insights'] = behaviorPattern.map((r) => r.description).toList();
    } catch (e) {
      print('Enhanced analysis error: $e');
    }

    return analysis;
  }
}

