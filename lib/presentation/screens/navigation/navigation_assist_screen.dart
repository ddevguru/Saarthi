/**
 * SAARTHI Flutter App - Navigation Assist Screen
 * Real-time navigation with Google Maps and voice guidance in Hindi/English
 */

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/voice_assistant_service.dart';
import '../../../data/services/navigation_guide_service.dart';
import '../../../data/services/google_maps_service.dart' as maps;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants.dart';

class NavigationAssistScreen extends StatefulWidget {
  const NavigationAssistScreen({super.key});

  @override
  State<NavigationAssistScreen> createState() => _NavigationAssistScreenState();
}

class _NavigationAssistScreenState extends State<NavigationAssistScreen> {
  final LocationService _locationService = LocationService();
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  final NavigationGuideService _navigationGuide = NavigationGuideService();
  
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isNavigating = false;
  String _destination = '';
  String _currentInstruction = '';
  String _language = 'en';
  bool _mapError = false;
  String? _mapErrorMessage;
  
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  maps.RouteResult? _currentRoute;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _getCurrentLocation();
    _voiceAssistant.initialize();
    _navigationGuide.initialize();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString(AppConstants.prefLanguage) ?? 'en';
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
        });
        
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _startNavigation(String destination) async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_language == 'hi' 
            ? 'स्थान प्राप्त नहीं हो सका' 
            : 'Could not get location')),
        );
        return;
      }
    }

    setState(() {
      _isNavigating = true;
      _destination = destination;
      _currentInstruction = _language == 'hi' ? 'रूट लोड हो रहा है...' : 'Loading route...';
    });
    
    // Get route from Google Maps
    final route = await _navigationGuide.startNavigation(
      origin: _currentPosition!,
      destination: destination,
    );

    if (route != null && mounted) {
      setState(() {
        _currentRoute = route;
        _currentInstruction = _navigationGuide.getRouteSummary() ?? '';
      });

      // Draw route on map
      _drawRoute(route);

      // Speak route summary
      final summary = _navigationGuide.getRouteSummary();
      if (summary != null) {
        await _voiceAssistant.speak(summary);
      }

      // Start location tracking for turn-by-turn guidance
      _locationService.startTracking();
      _locationService.getLocationStream().listen((position) {
        if (mounted && _isNavigating) {
          setState(() {
            _currentPosition = position;
          });
          _updateNavigationGuidance(position);
        }
      });
    } else {
      setState(() {
        _isNavigating = false;
        _currentInstruction = _language == 'hi' 
          ? 'रूट नहीं मिला। कृपया स्थान का नाम सही से लिखें या दूसरा स्थान आज़माएं।' 
          : 'Route not found. Please check the location name or try a different location.';
      });
      await _voiceAssistant.speak(_currentInstruction);
      
      // Show detailed error message - route not found, but stay in app
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _language == 'hi' 
                    ? 'रूट नहीं मिला' 
                    : 'Route not found',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _language == 'hi' 
                    ? 'कृपया स्थान का नाम सही से लिखें या दूसरा स्थान आज़माएं।\nउदाहरण: "Mumbai", "Andheri Station", "19.0760, 72.8777"' 
                    : 'Please check the location name or try a different location.\nExample: "Mumbai", "Andheri Station", "19.0760, 72.8777"',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: _language == 'hi' ? 'ठीक है' : 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _drawRoute(maps.RouteResult route) {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: route.polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      color: AppTheme.primaryColor,
      width: 5,
    );

    final startMarker = Marker(
      markerId: const MarkerId('start'),
      position: LatLng(
        route.polylinePoints.first.latitude,
        route.polylinePoints.first.longitude,
      ),
      infoWindow: InfoWindow(title: _language == 'hi' ? 'शुरुआत' : 'Start'),
    );

    final endMarker = Marker(
      markerId: const MarkerId('end'),
      position: LatLng(
        route.polylinePoints.last.latitude,
        route.polylinePoints.last.longitude,
      ),
      infoWindow: InfoWindow(title: _destination),
    );

    setState(() {
      _polylines = {polyline};
      _markers = {startMarker, endMarker};
    });

    // Fit camera to show entire route
    if (_mapController != null && route.polylinePoints.isNotEmpty) {
      final bounds = _calculateBounds(route.polylinePoints);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  LatLngBounds _calculateBounds(List<maps.RouteLatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _updateNavigationGuidance(Position position) async {
    final instruction = await _navigationGuide.getNextInstruction(position);
    
    if (instruction != null && mounted) {
      setState(() {
        _currentInstruction = instruction;
      });
      
      // Speak instruction
      await _voiceAssistant.speak(instruction);

      // Check if approaching turn
      if (_navigationGuide.isApproachingTurn(position)) {
        final remaining = _navigationGuide.getRemainingDistance();
        if (remaining != null) {
          final alert = _language == 'hi' 
            ? '$remaining में मुड़ें' 
            : 'Turn in $remaining';
          await _voiceAssistant.speak(alert);
        }
      }
    }

    // Update map camera
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _currentInstruction = '';
      _polylines.clear();
      _markers.clear();
      _currentRoute = null;
    });
    _locationService.stopTracking();
    _navigationGuide.reset();
    _voiceAssistant.speak(_language == 'hi' ? 'नेविगेशन बंद' : 'Navigation stopped');
  }

  Widget _buildMapWidget() {
    // Show loading if position not available
    if (_currentPosition == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show error message if map failed to load
    if (_mapError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _mapErrorMessage ?? (_language == 'hi' 
                ? 'मानचित्र लोड नहीं हो सका' 
                : 'Failed to load map'),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _mapError = false;
                  _mapErrorMessage = null;
                });
              },
              child: Text(_language == 'hi' ? 'पुनः प्रयास करें' : 'Retry'),
            ),
          ],
        ),
      );
    }

    // Try to create GoogleMap widget with error handling
    try {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 15,
        ),
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          setState(() {
            _mapError = false;
            _mapErrorMessage = null;
          });
          
          try {
            // Ensure map is properly initialized
            controller.setMapStyle(null); // Use default style
            
            // Animate to current position
            controller.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                15,
              ),
            );
            
            print('✓ Google Maps initialized successfully');
          } catch (e) {
            print('Error setting map style or animating camera: $e');
            // Don't set error state for style errors - map might still work
          }
        },
        onCameraMoveStarted: () {
          // Map is interactive - it's working
          if (_mapError) {
            setState(() {
              _mapError = false;
              _mapErrorMessage = null;
            });
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapType: MapType.normal,
        polylines: _polylines,
        markers: _markers,
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: true,
        rotateGesturesEnabled: true,
        compassEnabled: true,
        // Add error callback if available
        // Note: google_maps_flutter doesn't have onMapError callback
        // We'll detect errors through onMapCreated not being called
      );
    } catch (e) {
      print('Error creating GoogleMap widget: $e');
      // Return error widget
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $e',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _mapError = false;
                  _mapErrorMessage = null;
                });
              },
              child: Text(_language == 'hi' ? 'पुनः प्रयास करें' : 'Retry'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_language == 'hi' ? 'नेविगेशन सहायता' : 'Navigation Assist'),
      ),
      body: Column(
        children: [
          // Map View
          Expanded(
            flex: 2,
            child: _buildMapWidget(),
          ),
          
          // Navigation Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isNavigating) ...[
                  TextField(
                    decoration: InputDecoration(
                      labelText: _language == 'hi' ? 'गंतव्य दर्ज करें' : 'Enter Destination',
                      hintText: _language == 'hi' 
                        ? 'उदाहरण: होम, ऑफिस, मार्केट' 
                        : 'e.g., Home, Office, Market',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      _destination = value;
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _startNavigation(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_destination.isNotEmpty) {
                        _startNavigation(_destination);
                      }
                    },
                    icon: const Icon(Icons.navigation),
                    label: Text(_language == 'hi' ? 'नेविगेशन शुरू करें' : 'Start Navigation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ] else ...[
                  // Navigation Active
                  Card(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.navigation,
                            size: 48,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_language == 'hi' ? 'नेविगेशन कर रहे हैं' : 'Navigating to'}: $_destination',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_currentRoute != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _navigationGuide.getRouteSummary() ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (_currentInstruction.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _currentInstruction,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _stopNavigation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerColor,
                            ),
                            child: Text(_language == 'hi' ? 'नेविगेशन बंद करें' : 'Stop Navigation'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
