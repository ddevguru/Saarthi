/**
 * SAARTHI Flutter App - Child Detail Screen
 * Shows live map, stream, events, and controls for a specific child
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps_flutter;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../data/services/device_service.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/device.dart';
import '../../../core/constants.dart';
import 'package:saarthi/l10n/app_localizations.dart';

class ChildDetailScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildDetailScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  google_maps_flutter.GoogleMapController? _mapController;
  google_maps_flutter.LatLng? _currentLocation;
  bool _useFlutterMap = true; // Use Flutter Map (OpenStreetMap) instead of Google Maps
  bool _googleMapsError = false; // Track if Google Maps failed to initialize
  webview.WebViewController? _webViewController;
  final DeviceService _deviceService = DeviceService();
  final ApiClient _apiClient = ApiClient();
  Device? _device;
  bool _isLoadingDevice = true;
  String? _streamUrl;
  VideoPlayerController? _videoController;
  List<Map<String, dynamic>> _recentEvents = [];
  
  @override
  void dispose() {
    _videoController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadChildData();
  }

  Future<void> _loadChildData() async {
    setState(() {
      _isLoadingDevice = true;
    });
    
    try {
      // Load child dashboard data from API
      final response = await _apiClient.get(
        '${AppConstants.childDashboardEndpoint}?child_id=${widget.childId}',
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        
        // Get location
        if (data['latest_location'] != null) {
          final loc = data['latest_location'] as Map<String, dynamic>;
          if (loc['latitude'] != null && loc['longitude'] != null) {
          setState(() {
            _currentLocation = google_maps_flutter.LatLng(
              double.parse(loc['latitude'].toString()),
              double.parse(loc['longitude'].toString()),
            );
          });
          } else {
            _currentLocation = const google_maps_flutter.LatLng(19.0760, 72.8777); // Default Mumbai
          }
        } else {
          _currentLocation = const google_maps_flutter.LatLng(19.0760, 72.8777); // Default Mumbai
        }
        
        // Get device
        if (data['device'] != null) {
          final device = Device.fromJson(data['device'] as Map<String, dynamic>);
          // Use stream_url from device if available, otherwise build from IP
          // Priority: Manual URL > Device streamUrl > IP-based URL
          final streamUrl = await _deviceService.buildStreamUrl(device, device.ipAddress);
          
          setState(() {
            _device = device;
            _streamUrl = streamUrl;
            
            print('Parent app - Device: ${_device?.deviceId}');
            print('Parent app - Device Status: ${_device?.status}');
            print('Parent app - Device stream URL: $_streamUrl');
            print('Parent app - Device IP: ${_device?.ipAddress}');
            print('Parent app - Device Last Seen: ${_device?.lastSeen}');
            
            // Initialize video player if stream URL available (try even if status is not strictly ONLINE)
            // Check if device was seen recently (within last 5 minutes) or has a valid stream URL
            bool shouldConnect = false;
            if (_streamUrl != null && _streamUrl!.isNotEmpty) {
              if (_device!.isOnline) {
                shouldConnect = true;
              } else if (_device!.lastSeen != null) {
                final timeSinceLastSeen = DateTime.now().difference(_device!.lastSeen!);
                // Try to connect if device was seen in last 5 minutes
                if (timeSinceLastSeen.inMinutes < 5) {
                  shouldConnect = true;
                  print('Parent app - Device seen recently, attempting connection');
                }
              }
            }
            
            if (shouldConnect) {
              print('Parent app - Initializing video player for child device');
              _initializeVideoPlayer();
            } else {
              print('Parent app - Not connecting: streamUrl=$_streamUrl, isOnline=${_device!.isOnline}, lastSeen=${_device!.lastSeen}');
            }
          });
        } else {
          print('Parent app - No device found for child');
        }
        
        // Get recent events with photos and audio
        if (data['recent_events'] != null) {
          setState(() {
            _recentEvents = List<Map<String, dynamic>>.from(data['recent_events'] ?? []);
          });
        }
      } else {
      // Fallback to default location
      _currentLocation = const google_maps_flutter.LatLng(19.0760, 72.8777);
      }
    } catch (e) {
      print('Error loading child data: $e');
      // Handle error - use defaults
      _currentLocation = const google_maps_flutter.LatLng(19.0760, 72.8777);
    } finally {
      setState(() {
        _isLoadingDevice = false;
      });
      
      // Refresh location periodically
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          _loadChildData();
        }
      });
    }
  }

  Future<void> _openStreamInBrowser() async {
    if (_streamUrl != null) {
      try {
        final uri = Uri.parse(_streamUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot open stream: $_streamUrl')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening stream: $e')),
          );
        }
      }
    }
  }

  void _initializeVideoPlayer() {
    if (_streamUrl != null) {
      _videoController?.dispose();
      
      final streamUri = Uri.parse(_streamUrl!);
      
      _videoController = VideoPlayerController.networkUrl(
        streamUri,
        httpHeaders: {
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: true,
        ),
      );
      
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
          print('Parent app: Video player initialized successfully');
        }
      }).catchError((error) {
        print('Parent app: Error initializing video player: $error');
        // Retry after delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _initializeVideoPlayer();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.childName),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.map), text: l10n.liveMap),
              Tab(icon: const Icon(Icons.videocam), text: l10n.liveStream),
              Tab(icon: const Icon(Icons.event), text: l10n.events),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Live Map Tab
            _buildMapTab(),
            // Live Stream Tab
            _buildStreamTab(),
            // Events Tab
            _buildEventsTab(),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'safe_zones',
              onPressed: () {
                Navigator.pushNamed(context, '/safe-zones', arguments: widget.childId);
              },
              child: const Icon(Icons.location_on),
              tooltip: l10n.safeZones,
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'trips',
              onPressed: () {
                Navigator.pushNamed(context, '/trip-control', arguments: widget.childId);
              },
              child: const Icon(Icons.directions),
              tooltip: l10n.trips,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    if (_isLoadingDevice) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Use default location if current location is null
    final defaultLocation = const google_maps_flutter.LatLng(19.0760, 72.8777);
    final location = _currentLocation ?? defaultLocation;
    final latlngLocation = latlng.LatLng(location.latitude, location.longitude);

    // Use Flutter Map (OpenStreetMap) instead of Google Maps
    if (_useFlutterMap) {
      return FlutterMap(
        options: MapOptions(
          initialCenter: latlngLocation,
          initialZoom: 15.0,
          minZoom: 5.0,
          maxZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.saarthi',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: latlngLocation,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.childName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_googleMapsError) {
      // If Google Maps failed, use Flutter Map
      return FlutterMap(
        options: MapOptions(
          initialCenter: latlngLocation,
          initialZoom: 15.0,
          minZoom: 5.0,
          maxZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.saarthi',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: latlngLocation,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.childName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Try Google Maps with error handling
      return Builder(
        builder: (context) {
          try {
            return google_maps_flutter.GoogleMap(
              initialCameraPosition: google_maps_flutter.CameraPosition(
                target: location,
                zoom: 15,
              ),
              onMapCreated: (google_maps_flutter.GoogleMapController controller) {
                _mapController = controller;
                try {
                  controller.animateCamera(
                    google_maps_flutter.CameraUpdate.newLatLngZoom(location, 15),
                  );
                } catch (e) {
                  print('Error animating camera: $e');
                }
              },
              markers: {
                google_maps_flutter.Marker(
                  markerId: const google_maps_flutter.MarkerId('child_location'),
                  position: location,
                  infoWindow: google_maps_flutter.InfoWindow(title: widget.childName),
                  icon: google_maps_flutter.BitmapDescriptor.defaultMarkerWithHue(google_maps_flutter.BitmapDescriptor.hueRed),
                ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: google_maps_flutter.MapType.normal,
              compassEnabled: true,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
            );
          } catch (e) {
            print('Google Maps SDK Error: $e');
            // Switch to Flutter Map on error
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _googleMapsError = true;
                  _useFlutterMap = true;
                });
              }
            });
            // Return Flutter Map as fallback
            return FlutterMap(
              options: MapOptions(
                initialCenter: latlngLocation,
                initialZoom: 15.0,
                minZoom: 5.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.saarthi',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latlngLocation,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Icon(Icons.location_on, color: Colors.red, size: 40),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.childName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
        },
      );
    }
  }

  Widget _buildStreamTab() {
    if (_isLoadingDevice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_device == null || _streamUrl == null || _streamUrl!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Device Connected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Device needs to be connected and online to view live stream',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _loadChildData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final isOnline = _deviceService.isDeviceOnline(_device!.lastSeen);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Device Status
          Card(
            color: isOnline ? AppTheme.secondaryColor.withValues(alpha: 0.1) : Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.check_circle : Icons.error,
                    color: isOnline ? AppTheme.secondaryColor : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Status: ${isOnline ? "Online" : "Offline"}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_device!.lastSeen != null)
                          Text(
                            'Last seen: ${_formatTime(_device!.lastSeen!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Live Stream - Use WebView for MJPEG stream
          if (_streamUrl != null && _streamUrl!.isNotEmpty)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildWebViewStream(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            setState(() {
                              _webViewController = null;
                            });
                            _buildWebViewStream();
                          },
                          tooltip: 'Refresh Stream',
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_browser),
                          onPressed: _openStreamInBrowser,
                          tooltip: 'Open in Browser',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading stream...'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openStreamInBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open in Browser'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Instructions
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Note',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The live stream will open in your browser. Make sure the ESP32-CAM device is on the same network and the stream is accessible.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebViewStream() {
    if (_streamUrl == null || _streamUrl!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('No stream URL available'),
          ],
        ),
      );
    }

    // Check if URL is local network IP (might not be reachable from parent's phone)
    final streamUri = Uri.parse(_streamUrl!);
    final host = streamUri.host;
    final isLocalIP = host.startsWith('10.') || 
                      host.startsWith('192.168.') || 
                      host.startsWith('172.') ||
                      host == 'localhost' ||
                      host == '127.0.0.1';
    
    if (isLocalIP) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Local Network Stream',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Stream URL: $_streamUrl\n\nThis is a local network address. Make sure:\n1. You are on the same WiFi network as the device\n2. Router allows device-to-device communication\n3. Try opening the URL in a browser first',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _webViewController = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _openStreamInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open in Browser'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Initialize WebView controller if not already done
    if (_webViewController == null) {
      _webViewController = webview.WebViewController()
        ..setJavaScriptMode(webview.JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          webview.NavigationDelegate(
            onPageStarted: (String url) {
              print('Parent app - WebView loading stream: $url');
            },
            onPageFinished: (String url) {
              print('Parent app - WebView finished loading: $url');
            },
            onWebResourceError: (error) {
              print('Parent app - WebView error: ${error.description}');
              print('Error Code: ${error.errorCode}');
              print('Error Type: ${error.errorType}');
              print('Stream URL: $_streamUrl');
              
              // Check if it's a local network address issue
              final isLocalIP = _streamUrl != null && (
                _streamUrl!.contains('10.') ||
                _streamUrl!.contains('192.168.') ||
                _streamUrl!.contains('172.') ||
                _streamUrl!.contains('localhost') ||
                _streamUrl!.contains('127.0.0.1')
              );
              
              if (mounted) {
                String errorMessage = 'Stream connection error: ${error.description}';
                String helpText = '';
                
                if (isLocalIP && (error.description.contains('UNREACHABLE') || 
                                 error.description.contains('ERR_ADDRESS') ||
                                 error.errorCode == -2)) {
                  errorMessage = 'Local network stream not accessible';
                  helpText = '\n\nPossible solutions:\n'
                      '1. Check if device and phone are on same WiFi\n'
                      '2. Try restarting WiFi on both devices\n'
                      '3. Check router firewall settings\n'
                      '4. Use browser to test: $_streamUrl';
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage + helpText),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () {
                        setState(() {
                          _webViewController = null;
                        });
                      },
                    ),
                  ),
                );
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(_streamUrl!));
    }

    return webview.WebViewWidget(controller: _webViewController!);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildEventsTab() {
    if (_recentEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No recent events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentEvents.length,
      itemBuilder: (context, index) {
        final event = _recentEvents[index];
        final eventType = event['event_type'] as String? ?? 'UNKNOWN';
        final severity = event['severity'] as String? ?? 'MEDIUM';
        final createdAt = event['created_at'] as String?;
        final imagePath = event['image_path'] as String?;
        final audioPath = event['audio_path'] as String?;
        
        Color severityColor = AppTheme.warningColor;
        if (severity == 'HIGH' || severity == 'CRITICAL') {
          severityColor = AppTheme.dangerColor;
        } else if (severity == 'LOW') {
          severityColor = AppTheme.secondaryColor;
        }

        String timeText = 'Unknown time';
        if (createdAt != null) {
          try {
            final eventTime = DateTime.parse(createdAt);
            final now = DateTime.now();
            final difference = now.difference(eventTime);
            
            if (difference.inMinutes < 1) {
              timeText = 'Just now';
            } else if (difference.inHours < 1) {
              timeText = '${difference.inMinutes} minutes ago';
            } else if (difference.inDays < 1) {
              timeText = '${difference.inHours} hours ago';
            } else {
              timeText = '${difference.inDays} days ago';
            }
          } catch (e) {
            timeText = createdAt;
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: severityColor,
              child: const Icon(Icons.warning, color: Colors.white),
            ),
            title: Text(eventType),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeText),
                if (imagePath != null || audioPath != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (imagePath != null)
                        Chip(
                          label: const Text('Photo'),
                          avatar: const Icon(Icons.image, size: 16),
                          backgroundColor: Colors.blue[100],
                        ),
                      if (audioPath != null)
                        Chip(
                          label: const Text('Audio'),
                          avatar: const Icon(Icons.audiotrack, size: 16),
                          backgroundColor: Colors.green[100],
                        ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: severityColor),
            onTap: () {
              // Show event details dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(eventType),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Time: $timeText'),
                      Text('Severity: $severity'),
                      if (imagePath != null) ...[
                        const SizedBox(height: 8),
                        Text('Photo: Available', style: TextStyle(color: Colors.blue)),
                      ],
                      if (audioPath != null) ...[
                        const SizedBox(height: 8),
                        Text('Audio: Available', style: TextStyle(color: Colors.green)),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

