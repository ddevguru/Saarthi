/**
 * SAARTHI Flutter App - Location Service
 * Handles GPS location tracking and updates
 */

import 'package:geolocator/geolocator.dart';
import 'api_client.dart';
import '../../core/constants.dart';

class LocationService {
  final ApiClient _apiClient = ApiClient();
  bool _isTracking = false;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    return await getCurrentLocation();
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateLocationToBackend({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    int? batteryLevel,
    String? deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        AppConstants.locationUpdateEndpoint,
        {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'speed': speed,
          'battery_level': batteryLevel,
          'device_id': deviceId,
        },
        requireAuth: true,
      );

      return response['success'] == true;
    } catch (e) {
      // Don't fail silently - log error but don't throw
      print('Error updating location: $e');
      return false;
    }
  }

  /// Start location tracking and return stream
  Stream<Position> startTracking() {
    _isTracking = true;
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  /// Stop location tracking
  void stopTracking() {
    _isTracking = false;
  }

  /// Get location stream
  Stream<Position> getLocationStream() {
    return startTracking();
  // Removed duplicate getLocationStream method and unbalanced closing brace.
    
    
  
  }

  bool get isTracking => _isTracking;
}

