/**
 * SAARTHI Flutter App - Touch Sensor Service
 * Handles touch sensor events from ESP32-CAM device
 * Supports: Single tap, Double tap, Long press
 */

import 'dart:async';
import 'api_client.dart';
import '../../core/constants.dart';

class TouchSensorService {
  final ApiClient _apiClient = ApiClient();
  
  Function()? _onLongPress;
  Function()? _onSingleTap;
  Function()? _onDoubleTap;
  
  Timer? _pollTimer;
  bool _isInitialized = false;
  int _lastTouchState = 0;
  DateTime? _lastTouchTime;
  int _tapCount = 0;
  static const Duration _tapTimeout = Duration(milliseconds: 500);
  static const Duration _longPressDuration = Duration(milliseconds: 2000);
  DateTime? _touchStartTime;

  void initialize({
    Function()? onLongPress,
    Function()? onSingleTap,
    Function()? onDoubleTap,
  }) {
    _onLongPress = onLongPress;
    _onSingleTap = onSingleTap;
    _onDoubleTap = onDoubleTap;
    
    if (!_isInitialized) {
      _startPolling();
      _isInitialized = true;
    }
  }

  void _startPolling() {
    // Poll backend for touch sensor events every 100ms for very fast response
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _checkTouchSensor();
    });
  }

  String? _lastProcessedTouchType; // Track last processed touch type to avoid duplicates
  
  bool _isChecking = false; // Prevent concurrent checks
  
  Future<void> _checkTouchSensor() async {
    // Prevent concurrent calls
    if (_isChecking) return;
    _isChecking = true;
    
    try {
      // Check if user is authenticated first
      final token = await _apiClient.getToken();
      if (token == null || token.isEmpty) {
        // User not logged in, stop polling
        _isChecking = false;
        return;
      }
      
      // Get latest sensor data from backend
      final response = await _apiClient.get(
        AppConstants.latestSensorDataEndpoint,
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final touchState = data['touch'] as int? ?? 0;
        final touchType = data['touch_type'] as String?; // 'SINGLE', 'DOUBLE', 'LONG_PRESS'
        final sensorPayload = data['sensor_payload'] as Map<String, dynamic>?;
        
        // Also check sensor_payload for touch_type
        final payloadTouchType = sensorPayload?['touch_type'] as String?;
        final finalTouchType = touchType ?? payloadTouchType;
        
        // Handle touch type if provided by backend (only if it's new)
        if (finalTouchType != null && finalTouchType.isNotEmpty && finalTouchType != _lastProcessedTouchType) {
          print('New touch type detected: $finalTouchType (previous: $_lastProcessedTouchType)');
          _lastProcessedTouchType = finalTouchType;
          _handleTouchType(finalTouchType);
          // Reset after 1 second to allow same type again (faster response for single touch)
          Future.delayed(const Duration(seconds: 1), () {
            if (_lastProcessedTouchType == finalTouchType) {
              _lastProcessedTouchType = null;
              print('Reset touch type tracking');
            }
          });
          return;
        } else if (finalTouchType == null || finalTouchType.isEmpty) {
          // Reset if no touch type (touch released)
          if (_lastProcessedTouchType != null) {
            print('Touch released, resetting tracking');
            _lastProcessedTouchType = null;
          }
        }
        
        // Also check for immediate single touch detection from state change
        // This ensures single touch is detected even if backend hasn't processed touch_type yet
        if (touchState == 1 && _lastTouchState == 0) {
          // Touch started - mark time
          _touchStartTime = DateTime.now();
        } else if (touchState == 0 && _lastTouchState == 1 && _touchStartTime != null) {
          // Touch released - check if it was a quick single tap
          final pressDuration = DateTime.now().difference(_touchStartTime!);
          if (pressDuration < const Duration(milliseconds: 500) && pressDuration > const Duration(milliseconds: 50)) {
            // Quick tap detected - trigger single tap immediately
            print('Quick single tap detected from state change');
            _onSingleTap?.call();
            _touchStartTime = null;
            _lastTouchState = touchState;
            return;
          }
          _touchStartTime = null;
        }
        
        // Otherwise, detect from state changes
        if (touchState == 1 && _lastTouchState == 0) {
          // Touch started
          _touchStartTime = DateTime.now();
        } else if (touchState == 0 && _lastTouchState == 1) {
          // Touch released
          if (_touchStartTime != null) {
            final pressDuration = DateTime.now().difference(_touchStartTime!);
            
            if (pressDuration >= _longPressDuration) {
              // Long press detected
              _onLongPress?.call();
            } else {
              // Short press - check for single or double tap
              _handleTap();
            }
          }
          _touchStartTime = null;
        }
        
        _lastTouchState = touchState;
      }
    } catch (e) {
      // Only log if it's not an authentication error
      if (!e.toString().contains('Authentication required')) {
        print('Error checking touch sensor: $e');
      }
      // If authentication error, stop polling
      if (e.toString().contains('Authentication required')) {
        print('Authentication required - stopping touch sensor polling');
        _pollTimer?.cancel();
        _isInitialized = false;
      }
    } finally {
      _isChecking = false;
    }
  }

  void _handleTouchType(String touchType) {
    print('Touch type detected: $touchType');
    switch (touchType.toUpperCase()) {
      case 'LONG_PRESS':
        print('Triggering long press callback');
        _onLongPress?.call();
        break;
      case 'SINGLE':
      case 'SINGLE_TAP':
        print('Triggering single tap callback');
        _onSingleTap?.call();
        break;
      case 'DOUBLE':
      case 'DOUBLE_TAP':
        print('Triggering double tap callback');
        _onDoubleTap?.call();
        break;
      default:
        print('Unknown touch type: $touchType');
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    
    if (_lastTouchTime == null || now.difference(_lastTouchTime!) > _tapTimeout) {
      // First tap or timeout - reset counter
      _tapCount = 1;
      _lastTouchTime = now;
      
      // Wait for potential second tap
      Future.delayed(_tapTimeout, () {
        if (_tapCount == 1) {
          // Single tap
          _onSingleTap?.call();
        }
        _tapCount = 0;
      });
    } else {
      // Second tap within timeout
      _tapCount = 2;
      _lastTouchTime = now;
      
      // Double tap detected
      _onDoubleTap?.call();
      _tapCount = 0;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isInitialized = false;
  }
}

