/**
 * SAARTHI Flutter App - Google Maps Service
 * Handles Google Maps Directions API and route guidance
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class GoogleMapsService {
  // Note: API key should be valid and have Directions API, Geocoding API, and Places API enabled
  static const String _apiKey = 'AIzaSyCU8FMx2ffc-iLiflgzUwqhpEJ706q_U0w';
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
  
  // Check if API key is valid (basic check)
  bool get isApiKeyValid => _apiKey.isNotEmpty && _apiKey.length > 20;

  /// Get route from origin to destination
  Future<RouteResult?> getRoute({
    required Position origin,
    required String destination,
    String language = 'en',
  }) async {
    try {
      // Check API key validity
      if (!isApiKeyValid) {
        print('Warning: Google Maps API key may be invalid');
      }
      
      RouteLatLng? destLatLng;
      
      // Check if destination is already coordinates (lat,lng format)
      final coordMatch = RegExp(r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$').firstMatch(destination.trim());
      if (coordMatch != null) {
        // It's already coordinates
        destLatLng = RouteLatLng(
          double.parse(coordMatch.group(1)!),
          double.parse(coordMatch.group(2)!),
        );
        print('Using coordinates directly: ${destLatLng.latitude}, ${destLatLng.longitude}');
      } else {
        // Geocode destination address
        print('Geocoding destination: $destination');
        destLatLng = await _geocodeAddress(destination);
        if (destLatLng == null) {
          print('Failed to geocode destination with Geocoding API, trying Places API...');
          // Try alternative: use Places API for better results
          destLatLng = await _geocodeWithPlaces(destination);
          if (destLatLng == null) {
            print('Failed to geocode destination with both APIs: $destination');
            return null;
          }
        }
        print('Geocoded destination to: ${destLatLng.latitude}, ${destLatLng.longitude}');
      }

      // Try multiple modes: walking, driving, transit
      List<String> modes = ['walking', 'driving', 'transit'];
      RouteResult? routeResult;
      
      for (String mode in modes) {
        final url = Uri.parse('$_directionsBaseUrl?'
            'origin=${origin.latitude},${origin.longitude}'
            '&destination=${destLatLng.latitude},${destLatLng.longitude}'
            '&key=$_apiKey'
            '&language=$language'
            '&mode=$mode'
            '&alternatives=false');

        print('Requesting route from Google Maps API (mode: $mode)...');
        try {
          final response = await http.get(url).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            
            print('Google Maps API response status: ${data['status']} (mode: $mode)');
            
            if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
              final route = (data['routes'] as List).first as Map<String, dynamic>;
              final legs = (route['legs'] as List).first as Map<String, dynamic>;
              final steps = legs['steps'] as List;
              
              routeResult = RouteResult(
                distance: legs['distance']['text'] as String,
                duration: legs['duration']['text'] as String,
                startAddress: legs['start_address'] as String,
                endAddress: legs['end_address'] as String,
                polylinePoints: _decodePolyline(route['overview_polyline']['points'] as String),
                steps: steps.map((step) => RouteStep.fromJson(step as Map<String, dynamic>)).toList(),
              );
              print('Route found successfully with mode: $mode');
              break; // Found route, exit loop
            } else if (data['status'] == 'ZERO_RESULTS') {
              print('No route found with mode: $mode (ZERO_RESULTS), trying next mode...');
              continue; // Try next mode
            } else if (data['status'] == 'NOT_FOUND') {
              print('Origin or destination not found with mode: $mode (NOT_FOUND)');
              continue; // Try next mode
            } else if (data['status'] == 'REQUEST_DENIED') {
              print('Google Maps API request denied - check API key and billing: ${data['error_message'] ?? 'Unknown error'}');
              // Don't continue - API key issue
              return null;
            } else if (data['status'] == 'OVER_QUERY_LIMIT') {
              print('Google Maps API quota exceeded');
              // Don't continue - quota issue
              return null;
            } else {
              print('Google Maps API error with mode $mode: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
              continue; // Try next mode
            }
          } else {
            print('HTTP error with mode $mode: ${response.statusCode}');
            continue; // Try next mode
          }
        } catch (e) {
          print('Error with mode $mode: $e');
          continue; // Try next mode
        }
      }
      
      // Return the first successful route or null
      if (routeResult != null) {
        return routeResult;
      } else {
        print('No route found with any mode (walking, driving, transit)');
        return null;
      }
    } catch (e) {
      print('Error getting route: $e');
      return null;
    }
  }

  /// Geocode using Places API as fallback
  Future<RouteLatLng?> _geocodeWithPlaces(String address) async {
    try {
      final url = Uri.parse('$_placesBaseUrl?query=${Uri.encodeComponent(address)}&key=$_apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          final result = (data['results'] as List).first as Map<String, dynamic>;
          final location = result['geometry']['location'] as Map<String, dynamic>;
          return RouteLatLng(
            location['lat'] as double,
            location['lng'] as double,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error geocoding with Places API: $e');
      return null;
    }
  }

  /// Geocode address to coordinates
  Future<RouteLatLng?> _geocodeAddress(String address) async {
    try {
      final url = Uri.parse('$_geocodingBaseUrl?address=${Uri.encodeComponent(address)}&key=$_apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          final result = (data['results'] as List).first as Map<String, dynamic>;
          final location = result['geometry']['location'] as Map<String, dynamic>;
          return RouteLatLng(
            location['lat'] as double,
            location['lng'] as double,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  /// Decode polyline string to list of coordinates
  List<RouteLatLng> _decodePolyline(String encoded) {
    List<RouteLatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(RouteLatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
}

class RouteLatLng {
  final double latitude;
  final double longitude;

  RouteLatLng(this.latitude, this.longitude);
}

class RouteResult {
  final String distance;
  final String duration;
  final String startAddress;
  final String endAddress;
  final List<RouteLatLng> polylinePoints;
  final List<RouteStep> steps;

  RouteResult({
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.polylinePoints,
    required this.steps,
  });
}

class RouteStep {
  final String instruction;
  final String distance;
  final String duration;
  final RouteLatLng startLocation;
  final RouteLatLng endLocation;
  final String maneuver; // e.g., "turn-left", "turn-right", "straight"

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.maneuver,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'] as Map<String, dynamic>;
    final endLoc = json['end_location'] as Map<String, dynamic>;
    
    // Extract maneuver from HTML instructions
    String maneuver = 'straight';
    final htmlInstruction = json['html_instructions'] as String? ?? '';
    if (htmlInstruction.toLowerCase().contains('left')) {
      maneuver = 'turn-left';
    } else if (htmlInstruction.toLowerCase().contains('right')) {
      maneuver = 'turn-right';
    } else if (htmlInstruction.toLowerCase().contains('uturn') || htmlInstruction.toLowerCase().contains('u-turn')) {
      maneuver = 'u-turn';
    }
    
      return RouteStep(
      instruction: _stripHtmlTags(json['html_instructions'] as String? ?? ''),
      distance: (json['distance'] as Map<String, dynamic>)['text'] as String,
      duration: (json['duration'] as Map<String, dynamic>)['text'] as String,
      startLocation: RouteLatLng(startLoc['lat'] as double, startLoc['lng'] as double),
      endLocation: RouteLatLng(endLoc['lat'] as double, endLoc['lng'] as double),
      maneuver: maneuver,
    );
  }

  static String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

