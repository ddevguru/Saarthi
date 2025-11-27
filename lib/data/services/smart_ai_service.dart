/**
 * SAARTHI Flutter App - Smart AI Service
 * Agentic AI features: Context-aware, proactive, intelligent responses
 */

import '../models/device.dart';
import '../models/event.dart';
import '../models/location.dart';
import 'device_service.dart';
import 'api_client.dart';
import '../../core/constants.dart';
import 'dart:math';

class SmartAIService {
  final DeviceService _deviceService = DeviceService();
  final ApiClient _apiClient = ApiClient();
  
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
}

