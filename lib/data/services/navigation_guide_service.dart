/**
 * SAARTHI Flutter App - Navigation Guide Service
 * Agentic AI for smart route guidance in Hindi and English
 */

import 'package:geolocator/geolocator.dart';
import 'google_maps_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class NavigationGuideService {
  final GoogleMapsService _mapsService = GoogleMapsService();
  RouteResult? _currentRoute;
  int _currentStepIndex = 0;
  String _language = 'en';

  /// Initialize navigation
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(AppConstants.prefLanguage) ?? 'en';
  }

  /// Start navigation to destination
  Future<RouteResult?> startNavigation({
    required Position origin,
    required String destination,
  }) async {
    await initialize();
    
    _currentRoute = await _mapsService.getRoute(
      origin: origin,
      destination: destination,
      language: _language,
    );
    
    _currentStepIndex = 0;
    
    return _currentRoute;
  }

  /// Get next navigation instruction based on current position
  Future<String?> getNextInstruction(Position currentPosition) async {
    if (_currentRoute == null || _currentRoute!.steps.isEmpty) {
      return null;
    }

    // Find current step based on proximity
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        step.endLocation.latitude,
        step.endLocation.longitude,
      );

      // If within 50 meters of step end, move to next step
      if (distance < 50 && i < _currentRoute!.steps.length - 1) {
        _currentStepIndex = i + 1;
      }
    }

    if (_currentStepIndex < _currentRoute!.steps.length) {
      final step = _currentRoute!.steps[_currentStepIndex];
      return _formatInstruction(step, _currentStepIndex);
    }

    return _language == 'hi' 
        ? 'आप अपने गंतव्य पर पहुंच गए हैं।'
        : 'You have reached your destination.';
  }

  /// Format instruction in Hindi or English
  String _formatInstruction(RouteStep step, int stepIndex) {
    final distance = step.distance;
    final stepInstruction = step.instruction;
    
    if (_language == 'hi') {
      return _formatInstructionHindi(step, distance, stepInstruction);
    } else {
      return _formatInstructionEnglish(step, distance, stepInstruction);
    }
  }

  String _formatInstructionHindi(RouteStep step, String distance, String stepInstruction) {
    switch (step.maneuver) {
      case 'turn-left':
        return '$distance बाद बाएं मुड़ें। $stepInstruction';
      case 'turn-right':
        return '$distance बाद दाएं मुड़ें। $stepInstruction';
      case 'u-turn':
        return '$distance बाद यू-टर्न लें। $stepInstruction';
      default:
        return '$distance तक सीधे चलते रहें। $stepInstruction';
    }
  }

  String _formatInstructionEnglish(RouteStep step, String distance, String stepInstruction) {
    switch (step.maneuver) {
      case 'turn-left':
        return 'In $distance, turn left. $stepInstruction';
      case 'turn-right':
        return 'In $distance, turn right. $stepInstruction';
      case 'u-turn':
        return 'In $distance, take a U-turn. $stepInstruction';
      default:
        return 'Continue straight for $distance. $stepInstruction';
    }
  }

  /// Get current route summary
  String? getRouteSummary() {
    if (_currentRoute == null) return null;
    
    if (_language == 'hi') {
      return 'कुल दूरी: ${_currentRoute!.distance}, समय: ${_currentRoute!.duration}';
    } else {
      return 'Total distance: ${_currentRoute!.distance}, Time: ${_currentRoute!.duration}';
    }
  }

  /// Check if approaching turn
  bool isApproachingTurn(Position currentPosition, {double thresholdMeters = 100}) {
    if (_currentRoute == null || _currentStepIndex >= _currentRoute!.steps.length) {
      return false;
    }

    final nextStep = _currentRoute!.steps[_currentStepIndex];
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      nextStep.endLocation.latitude,
      nextStep.endLocation.longitude,
    );

    return distance <= thresholdMeters && 
           (nextStep.maneuver == 'turn-left' || 
            nextStep.maneuver == 'turn-right' || 
            nextStep.maneuver == 'u-turn');
  }

  /// Get remaining distance
  String? getRemainingDistance() {
    if (_currentRoute == null) return null;
    
    double totalDistance = 0;
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      // Parse distance (e.g., "500 m" or "1.2 km")
      final distStr = step.distance.toLowerCase();
      if (distStr.contains('km')) {
        totalDistance += double.parse(distStr.replaceAll('km', '').trim()) * 1000;
      } else if (distStr.contains('m')) {
        totalDistance += double.parse(distStr.replaceAll('m', '').trim());
      }
    }
    
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${totalDistance.toStringAsFixed(0)} m';
    }
  }

  void reset() {
    _currentRoute = null;
    _currentStepIndex = 0;
  }
}

