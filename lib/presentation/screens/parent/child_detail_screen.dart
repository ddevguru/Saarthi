/**
 * SAARTHI Flutter App - Child Detail Screen
 * Shows live map, stream, events, and controls for a specific child
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
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
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  final DeviceService _deviceService = DeviceService();
  final ApiClient _apiClient = ApiClient();
  Device? _device;
  bool _isLoadingDevice = true;
  String? _streamUrl;
  VideoPlayerController? _videoController;
  bool _isStreamInitialized = false;
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
            _currentLocation = LatLng(
              double.parse(loc['latitude'].toString()),
              double.parse(loc['longitude'].toString()),
            );
          });
          } else {
            _currentLocation = const LatLng(19.0760, 72.8777); // Default Mumbai
          }
        } else {
          _currentLocation = const LatLng(19.0760, 72.8777); // Default Mumbai
        }
        
        // Get device
        if (data['device'] != null) {
          setState(() {
            _device = Device.fromJson(data['device'] as Map<String, dynamic>);
            // Use stream_url from device if available, otherwise build from IP
            _streamUrl = _device?.streamUrl ?? _deviceService.buildStreamUrl(_device, _device?.ipAddress);
            
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
        _currentLocation = const LatLng(19.0760, 72.8777);
      }
    } catch (e) {
      print('Error loading child data: $e');
      // Handle error - use defaults
      _currentLocation = const LatLng(19.0760, 72.8777);
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
    final location = _currentLocation ?? const LatLng(19.0760, 72.8777);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: location,
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        // Update map camera position
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(location, 15),
        );
      },
      markers: {
        Marker(
          markerId: const MarkerId('child_location'),
          position: location,
          infoWindow: InfoWindow(title: widget.childName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapType: MapType.normal,
      compassEnabled: true,
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
    );
  }

  Widget _buildStreamTab() {
    if (_isLoadingDevice) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_device == null || _streamUrl == null) {
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
          
          // Live Stream Video Player
          // Show stream if device has stream URL (even if not strictly online, try to connect)
          if (_streamUrl != null && _streamUrl!.isNotEmpty && _videoController != null)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _videoController!.value.isInitialized
                        ? VideoPlayer(_videoController!)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
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
          else if (_streamUrl != null && _streamUrl!.isNotEmpty)
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
              // TODO: Navigate to event detail page
            },
          ),
        );
      },
    );
  }
}

