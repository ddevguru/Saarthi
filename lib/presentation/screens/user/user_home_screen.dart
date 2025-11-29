// ignore_for_file: deprecated_member_use

/**
 * SAARTHI Flutter App - User Home Screen
 * Main screen for users with SOS button and device status
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/device_service.dart';
import '../../../data/services/voice_assistant_service.dart';
import '../../../data/services/smart_ai_service.dart';
// AudioRecordingService import removed - phone microphone recording is DISABLED
import '../../../data/services/touch_sensor_service.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/device.dart';
import '../../../core/constants.dart';
import '../../widgets/device_status_card.dart';
import '../../widgets/voice_assistant_button.dart';
import '../../widgets/smart_ai_card.dart';
import '../../widgets/glassmorphic_container.dart';
import '../../../core/neon_colors.dart';
import 'package:saarthi/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final LocationService _locationService = LocationService();
  final DeviceService _deviceService = DeviceService();
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService(); // Singleton
  final SmartAIService _smartAI = SmartAIService();
  // AudioRecordingService removed - phone microphone recording is DISABLED
  // ESP32-CAM handles all audio recording via external microphone
  final TouchSensorService _touchSensor = TouchSensorService();
  bool _isSharingLocation = false;
  Device? _device;
  bool _isLoadingDevice = true;
  String? _streamUrl;
  VideoPlayerController? _videoController;
  webview.WebViewController? _webViewController;
  bool _useWebViewFallback = false;
  bool _isStreamInitialized = false;
  
  // Obstacle alert debouncing - faster alerts
  DateTime? _lastObstacleAlertTime;
  static const Duration _obstacleAlertCooldown = Duration(milliseconds: 800); // Reduced to 800ms for very fast alerts
  double? _lastObstacleDistance;
  bool _isFirstConnection = true; // Prevent false alerts on first connection
  DateTime? _appStartTime; // Track app start time to prevent initial false alerts

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now(); // Track app start time
    _checkLocationPermission();
    _loadDeviceStatus();
    // Voice assistant will NOT auto-start - user must activate it manually
    _initializeTouchSensor();
  }

  void _initializeTouchSensor() {
    _touchSensor.initialize(
      onLongPress: _handleLongPress,
      onSingleTap: _handleSingleTap, // Single tap = Start voice assistant
      onDoubleTap: _handleDoubleTap, // Double tap = Emergency
    );
  }

  Future<void> _handleLongPress() async {
    print('Long press detected - triggering critical emergency');
    // Long press = Critical Emergency alert
    await _voiceAssistant.speak("Critical emergency! गंभीर आपातकाल!");
    
    // ESP32-CAM will automatically record audio from external microphone
    // No need to record from phone - ESP32 handles it
    
    // Capture photo via ESP32 (send command to backend)
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/device/triggerPhotoCapture.php',
        {
          'device_id': _device?.deviceId,
          'event_type': 'LONG_PRESS_EMERGENCY',
        },
        requireAuth: true,
      );
    } catch (e) {
      print('Error triggering photo capture: $e');
    }
    
    // Send emergency event to backend (ESP32 will record audio automatically)
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/device/emergencyAlert.php',
        {
          'event_type': 'LONG_PRESS_EMERGENCY',
          'device_id': _device?.deviceId,
        },
        requireAuth: true,
      );
    } catch (e) {
      print('Error sending emergency alert: $e');
    }
  }

  Future<void> _handleSingleTap() async {
    if (kDebugMode) {
      print('Single tap detected - triggering alert with photo and audio');
    }
    // Single tap = Alert with photo and audio capture
    await _voiceAssistant.speak("Alert triggered! Photo capturing! चेतावनी! फोटो कैप्चर हो रहा है!");
    
    // Trigger photo and audio capture via ESP32
    try {
      final apiClient = ApiClient();
      // Send sensor data to trigger ESP32 photo and audio capture
      await apiClient.post(
        '/device/postSensorData.php',
        {
          'device_id': _device?.deviceId,
          'touch': 1,
          'touch_type': 'SINGLE',
          'distance': -1,
          'mic': 0,
        },
        requireAuth: true,
      );
      print('Single tap alert sent - ESP32 will capture photo and audio');
    } catch (e) {
      print('Error sending single tap alert: $e');
    }
    
    // Also start voice assistant after alert
    if (!_voiceAssistant.isInitialized) {
      await _voiceAssistant.initialize();
    }
    _voiceAssistant.startListening(
      onResult: (command) {
        if (command.trim().isNotEmpty) {
          if (kDebugMode) {
            print('Voice command received: $command');
          }
        }
      },
    );
  }

  Future<void> _handleDoubleTap() async {
    print('Double tap detected - triggering emergency alert and photo capture');
    // Double tap = Emergency alert
    await _voiceAssistant.speak("Emergency alert! Photo capturing! आपातकालीन चेतावनी! फोटो कैप्चर हो रहा है!");
    
    // ESP32-CAM will automatically record audio from external microphone (1 minute)
    // No need to record from phone - ESP32 handles it
    
    // Capture photo via ESP32 (send command to backend)
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/device/triggerPhotoCapture.php',
        {
          'device_id': _device?.deviceId,
          'event_type': 'DOUBLE_TAP_EMERGENCY',
        },
        requireAuth: true,
      );
      print('Photo capture triggered: $response');
    } catch (e) {
      print('Error triggering photo capture: $e');
    }
    
    // Also trigger via sensor data endpoint to ensure ESP32 captures immediately
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/device/postSensorData.php',
        {
          'device_id': _device?.deviceId,
          'touch': 1,
          'touch_type': 'DOUBLE',
          'distance': -1,
          'mic': 0,
        },
        requireAuth: true,
      );
      print('Sensor data sent to trigger ESP32 photo capture');
    } catch (e) {
      print('Error sending sensor data: $e');
    }
    
    // Send emergency event to backend (ESP32 will record audio automatically for 1 minute)
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/device/emergencyAlert.php',
        {
          'event_type': 'DOUBLE_TAP_EMERGENCY',
          'device_id': _device?.deviceId,
        },
        requireAuth: true,
      );
    } catch (e) {
      print('Error sending emergency alert: $e');
    }
  }


  Future<void> _loadDeviceStatus() async {
    setState(() {
      _isLoadingDevice = true;
    });
    
    try {
      final devices = await _deviceService.getUserDevices();
      if (devices.isNotEmpty) {
        final wasOnline = _deviceService.checkDeviceOnline(_device);
        final newDevice = devices.first;
        final isNowOnline = _deviceService.checkDeviceOnline(newDevice);
        
        // Get stream URL before setState (async operation)
        final newStreamUrl = await _deviceService.buildStreamUrl(newDevice, newDevice.ipAddress);
        
        setState(() {
          _device = newDevice;
          // Use stream_url from device if available, otherwise build from IP
          // Priority: Manual URL > Device streamUrl > IP-based URL
          
          // Reset retry count if stream URL changed or device came back online
          if (_streamUrl != newStreamUrl || (!wasOnline && isNowOnline)) {
            _retryCount = 0;
            _isStreamInitialized = false;
            _videoController?.dispose();
            _videoController = null;
          }
          
          _streamUrl = newStreamUrl;
          
          print('Device stream URL: $_streamUrl');
          print('Device IP: ${_device?.ipAddress}');
          print('Device online: $isNowOnline');
          
          // Initialize video player if device is online and stream URL is available
          if (isNowOnline && _streamUrl != null && _streamUrl!.isNotEmpty && !_isStreamInitialized) {
            // Delay initialization slightly to ensure state is set
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _initializeVideoPlayer();
              }
            });
          }
        });
        
        // Start listening for sensor events
        _startSensorEventListening();
      } else {
        // Try to refresh from API
        await Future.delayed(const Duration(seconds: 1));
        final refreshedDevices = await _deviceService.getUserDevices();
        if (refreshedDevices.isNotEmpty) {
          final refreshedDevice = refreshedDevices.first;
          // Get stream URL before setState (async operation)
          final refreshedStreamUrl = await _deviceService.buildStreamUrl(refreshedDevice, refreshedDevice.ipAddress);
          
          setState(() {
            _device = refreshedDevice;
            // Use stream_url from device if available, otherwise build from IP
            // Priority: Manual URL > Device streamUrl > IP-based URL
            _streamUrl = refreshedStreamUrl;
            
            print('Refreshed device stream URL: $_streamUrl');
            
            // Initialize video player if device is online and stream URL is available
            if (_deviceService.checkDeviceOnline(_device) && _streamUrl != null && _streamUrl!.isNotEmpty) {
              // Delay initialization slightly to ensure state is set
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _initializeVideoPlayer();
                }
              });
            }
          });
        }
      }
    } catch (e) {
      print('Error loading device: $e');
    } finally {
      setState(() {
        _isLoadingDevice = false;
      });
    }
    
    // Refresh device status periodically (every 30 seconds)
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadDeviceStatus();
      }
    });
  }

  Future<void> _checkLocationPermission() async {
    final hasPermission = await _locationService.requestPermission();
    if (hasPermission && _isSharingLocation) {
      _startLocationSharing();
    }
  }

  void _startLocationSharing() {
    _locationService.startTracking();
    _locationService.getLocationStream().listen((position) async {
      // Update location immediately to backend
      final success = await _locationService.updateLocationToBackend(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
      );
      if (success) {
        print('Location saved: ${position.latitude}, ${position.longitude}');
      } else {
        print('Failed to save location');
      }
    });
  }

  void _stopLocationSharing() {
    _locationService.stopTracking();
  }

  Future<void> _triggerSOS() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: const Text('Are you sure you want to trigger an emergency alert?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS alert sent!'),
                  backgroundColor: AppTheme.dangerColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title: Text(
          l10n.home,
          style: NeonColors.neonText(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NeonColors.lightNeonPink,
          ),
        ),
        actions: [
          // Stream URL Settings button
          IconButton(
            icon: const Icon(Icons.video_settings, color: Color(0xFF4ECDC4)),
            tooltip: 'Stream URL Settings',
            onPressed: () => _showStreamUrlSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A1A), // Dark gray/black
              Color(0xFF2D2D2D), // Slightly lighter dark
              Color(0xFF1F1F1F), // Dark
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device Status Card with Glassmorphism
              _isLoadingDevice
                  ? GlassmorphicContainer(
                      padding: const EdgeInsets.all(24.0),
                      borderRadius: 20,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                        ),
                      ),
                    )
                  : _device == null
                      ? GlassmorphicContainer(
                          padding: const EdgeInsets.all(20.0),
                          borderRadius: 20,
                          gradientColors: [
                            const Color(0xFFFF6B9D).withOpacity(0.2),
                            const Color(0xFFFF6B9D).withOpacity(0.1),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFFFF6B9D),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No Device Found',
                                    style: NeonColors.neonText(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: NeonColors.lightNeonPink,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please register your ESP32-CAM device. Make sure the device is connected and registered with your account.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GlassmorphicContainer(
                          padding: const EdgeInsets.all(20.0),
                          borderRadius: 20,
                          child: DeviceStatusCard(
                            isConnected: _deviceService.checkDeviceOnline(_device),
                            lastEvent: null,
                            lastEventTime: _device?.lastSeen,
                          ),
                        ),
            const SizedBox(height: 24),
            
              // Live Stream Section with Glassmorphism
              if (_device != null && _streamUrl != null && _streamUrl!.isNotEmpty && _deviceService.checkDeviceOnline(_device))
                GlassmorphicContainer(
                  padding: const EdgeInsets.all(16.0),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Color(0xFF4ECDC4), // Cyan/Blue
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Live Stream',
                                style: NeonColors.neonText(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: NeonColors.lightNeonCyan,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Color(0xFF4ECDC4)),
                            onPressed: () {
                              setState(() {
                                _retryCount = 0;
                                _isStreamInitialized = false;
                                _videoController?.dispose();
                                _videoController = null;
                              });
                              _initializeVideoPlayer();
                            },
                            tooltip: 'Refresh Stream',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_streamUrl != null && _streamUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _useWebViewFallback
                                ? _buildWebViewStream()
                                : (_isStreamInitialized && _videoController != null && _videoController!.value.isInitialized
                                    ? VideoPlayer(_videoController!)
                                    : _buildStreamLoading()),
                          ),
                        )
                      else if (_retryCount >= _maxRetries)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NeonColors.lightNeonPink.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: NeonColors.lightNeonPink,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Stream Connection Failed',
                                style: NeonColors.neonText(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: NeonColors.lightNeonPink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _retryCount = 0;
                                    _isStreamInitialized = false;
                                  });
                                  _initializeVideoPlayer();
                                },
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NeonColors.lightNeonPink.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Connecting to stream...',
                                style: TextStyle(
                                  color: NeonColors.lightNeonCyan.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                              if (_retryCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Retry attempt $_retryCount/$_maxRetries',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_videoController != null && _isStreamInitialized)
                              IconButton(
                                icon: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
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
                              icon: const Icon(Icons.open_in_browser, color: Colors.white),
                              onPressed: () async {
                                if (_streamUrl != null) {
                                  try {
                                    // Clean URL before opening
                                    String cleanUrl = _streamUrl!.trim();
                                    final streamUri = Uri.parse(cleanUrl);
                                    String cleanHost = streamUri.host;
                                    // Remove trailing dots from host
                                    while (cleanHost.endsWith('.')) {
                                      cleanHost = cleanHost.substring(0, cleanHost.length - 1);
                                    }
                                    // Rebuild URL with clean host
                                    final cleanUri = streamUri.replace(host: cleanHost);
                                    cleanUrl = cleanUri.toString();
                                    
                                    final uri = Uri.parse(cleanUrl);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Cannot open stream URL: $cleanUrl'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error opening stream: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Stream URL not available'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }
                              },
                              tooltip: 'Open in Browser',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 24),
            
            // Smart AI Analysis Card
            SmartAICard(smartAI: _smartAI),
            const SizedBox(height: 24),
            
              // SOS Button with Glassmorphism
              GlassmorphicContainer(
                padding: const EdgeInsets.all(20.0),
                borderRadius: 20,
                gradientColors: [
                  const Color(0xFFCC0000).withOpacity(0.3),
                  const Color(0xFFCC0000).withOpacity(0.2),
                ],
                child: ElevatedButton(
                  onPressed: _triggerSOS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, size: 48, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        l10n.sosButton,
                        style: NeonColors.neonText(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: NeonColors.lightNeonPink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            
              // Location Sharing Toggle with Glassmorphism
              GlassmorphicContainer(
                padding: EdgeInsets.zero,
                borderRadius: 15,
                child: SwitchListTile(
                  title: Text(
                    l10n.shareLocation,
                    style: NeonColors.neonText(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: NeonColors.lightNeonCyan,
                    ),
                  ),
                  subtitle: Text(
                    _isSharingLocation 
                        ? 'Location is being shared' 
                        : 'Enable to share live location',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  value: _isSharingLocation,
                  activeColor: const Color(0xFF4ECDC4),
                  onChanged: (value) {
                    setState(() {
                      _isSharingLocation = value;
                      if (value) {
                        _startLocationSharing();
                      } else {
                        _stopLocationSharing();
                      }
                    });
                  },
                ),
              ),
            const SizedBox(height: 16),
            
              // Quick Actions with Glassmorphism
              Row(
                children: [
                  Expanded(
                    child: GlassmorphicContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: 15,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/navigation-assist');
                        },
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        label: Text(
                          l10n.navigation,
                          style: NeonColors.neonText(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: NeonColors.lightNeonCyan,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassmorphicContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: 15,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/quick-messages');
                        },
                        icon: const Icon(Icons.message, color: Colors.white),
                        label: Text(
                          l10n.quickMessages,
                          style: NeonColors.neonText(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: NeonColors.lightNeonPink,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: VoiceAssistantButton(
        voiceAssistant: _voiceAssistant,
      ),
    );
  }

  int _retryCount = 0;
  static const int _maxRetries = 5; // Increased retries
  
  void _initializeVideoPlayer() {
    if (_streamUrl == null || _streamUrl!.isEmpty) {
      if (kDebugMode) {
        print('Stream URL is null or empty');
      }
      return;
    }
    
    if (_isStreamInitialized && _videoController != null && _videoController!.value.isInitialized) {
      if (kDebugMode) {
        print('Video player already initialized');
      }
      return;
    }
    
    // Reset retry count if it exceeds max retries (allow manual retry)
    if (_retryCount >= _maxRetries) {
      if (kDebugMode) {
        print('Max retries reached for video player initialization - resetting for manual retry');
      }
      // Reset retry count to allow manual retry
      _retryCount = 0;
    }
    
    // Dispose old controller
    _videoController?.dispose();
    _videoController = null;
    
    // Clean and validate stream URL
    try {
      // Clean URL: remove trailing dots from host
      String cleanStreamUrl = _streamUrl!.trim();
      final streamUri = Uri.parse(cleanStreamUrl);
      
      // Clean the host to remove trailing dots
      String cleanHost = streamUri.host;
      while (cleanHost.endsWith('.')) {
        cleanHost = cleanHost.substring(0, cleanHost.length - 1);
      }
      
      // Rebuild URL with clean host
      final cleanUri = streamUri.replace(host: cleanHost);
      cleanStreamUrl = cleanUri.toString();
      
      // Update _streamUrl with cleaned version
      if (cleanStreamUrl != _streamUrl) {
        print('Cleaned stream URL: $_streamUrl -> $cleanStreamUrl');
        _streamUrl = cleanStreamUrl;
      }
      
      // Validate URL format
      if (cleanUri.scheme != 'http' && cleanUri.scheme != 'https') {
        if (kDebugMode) {
          print('Invalid stream URL scheme: ${cleanUri.scheme}');
        }
        return;
      }
      
      if (kDebugMode) {
        print('Initializing video player with URL: $cleanStreamUrl (attempt ${_retryCount + 1}/$_maxRetries)');
      }
      
      // For MJPEG streams from ESP32-CAM
      // Use httpHeaders to help with connection
      _videoController = VideoPlayerController.networkUrl(
        cleanUri,
        httpHeaders: {
          'Connection': 'keep-alive',
          'Cache-Control': 'no-cache',
        },
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: true,
        ),
      );
      
      // Set timeout for initialization (15 seconds - balanced for responsiveness)
      _videoController!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Video player initialization timeout after 15 seconds');
          throw TimeoutException('Video initialization timeout');
        },
      ).then((_) {
        if (mounted && _videoController != null && _videoController!.value.isInitialized) {
          setState(() {
            _isStreamInitialized = true;
            _retryCount = 0; // Reset retry count on success
          });
          _videoController!.play();
          _videoController!.setLooping(true);
          print('Video player initialized successfully - Stream is playing');
        }
      }).catchError((error) {
        print('Error initializing video player: $error');
        
        // Only increment retry count if not already at max
        if (_retryCount < _maxRetries) {
          _retryCount++;
        }
        
        if (mounted) {
          setState(() {
            _isStreamInitialized = false;
          });
        }
        
        // Retry after delay if retries remaining
        if (mounted && _retryCount < _maxRetries) {
          final delaySeconds = _retryCount; // Linear backoff: 1s, 2s, 3s, 4s (faster)
          print('Retrying video player initialization in $delaySeconds seconds (attempt $_retryCount/$_maxRetries)...');
          Future.delayed(Duration(seconds: delaySeconds), () {
            if (mounted && !_isStreamInitialized && _streamUrl != null && _streamUrl!.isNotEmpty) {
              _initializeVideoPlayer();
            }
          });
        } else {
          // Max retries reached - try WebView fallback immediately
          if (mounted && !_useWebViewFallback) {
            print('Video player failed after max retries, switching to WebView fallback immediately');
            setState(() {
              _useWebViewFallback = true;
              _retryCount = 0;
              _isStreamInitialized = false;
              _webViewController = null; // Reset WebView controller to force re-initialization
            });
            // WebView will be initialized automatically when _buildWebViewStream is called
          } else if (mounted) {
            // Both video player and WebView failed - show error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stream connection failed. Check device network or try opening in browser.'),
                backgroundColor: NeonColors.lightNeonPink.withOpacity(0.9),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _retryCount = 0;
                      _isStreamInitialized = false;
                      _useWebViewFallback = false;
                      _webViewController = null;
                    });
                    _initializeVideoPlayer();
                  },
                ),
              ),
            );
          }
        }
      });
    } catch (e) {
      print('Error parsing stream URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid stream URL format: $_streamUrl'),
            backgroundColor: NeonColors.lightNeonPink.withOpacity(0.9),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _isSensorPolling = false;
  
  void _startSensorEventListening() {
    // Prevent multiple instances
    if (_isSensorPolling) return;
    _isSensorPolling = true;
    
    // Poll for sensor events every 300ms for real-time alerts
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted || _device == null) {
        _isSensorPolling = false;
        return;
      }
      
      try {
        // Check authentication first
        final apiClient = ApiClient();
        final token = await apiClient.getToken();
        if (token == null || token.isEmpty) {
          _isSensorPolling = false;
          return;
        }
        
        final response = await apiClient.get(
          AppConstants.latestSensorDataEndpoint,
          requireAuth: true,
        );
        
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          final payload = data['sensor_payload'] as Map<String, dynamic>?;
          
          // Check for obstacle alert - Alert for 20cm range and 50-100cm range
          if (data['event_type'] == 'OBSTACLE_ALERT' && payload != null) {
            final distance = payload['distance'] as double?;
            
            // Skip alerts for first 5 seconds after app start to prevent false alerts
            if (_appStartTime != null) {
              final timeSinceStart = DateTime.now().difference(_appStartTime!);
              if (timeSinceStart.inSeconds < 5) {
                print('Skipping alert - app just started (${timeSinceStart.inSeconds}s ago)');
                return;
              }
            }
            
            // Skip first connection to prevent false alerts
            if (_isFirstConnection) {
              _isFirstConnection = false;
              // Wait a bit before processing alerts
              await Future.delayed(const Duration(seconds: 1));
              return;
            }
            
            // Alert logic: 20cm range = alert, 50-100cm = alert
            if (distance != null && distance > 0) {
              final shouldAlert = _shouldAlertObstacle(distance);
              
              if (shouldAlert) {
                _lastObstacleAlertTime = DateTime.now();
                _lastObstacleDistance = distance;
                
                // Different messages based on distance
                if (distance < 10) {
                  await _voiceAssistant.speak("Critical! Obstacle very close! बहुत करीब बाधा! सावधान!");
                } else if (distance >= 20 && distance <= 30) {
                  await _voiceAssistant.speak("Warning! Obstacle detected at 20cm! 20 सेमी पर बाधा का पता चला!");
                } else if (distance >= 50 && distance <= 100) {
                  await _voiceAssistant.speak("Obstacle detected ahead. बाधा का पता चला।");
                }
                
                // Trigger photo capture on ESP32 for obstacle detection
                try {
                  await apiClient.post(
                    '/device/triggerPhotoCapture.php',
                    {
                      'device_id': _device?.deviceId,
                      'event_type': 'OBSTACLE_ALERT',
                    },
                    requireAuth: true,
                  );
                  print('Photo capture triggered for obstacle at ${distance}cm');
                } catch (e) {
                  print('Error triggering photo capture: $e');
                }
                
                // Send alert to dashboard via API
                try {
                  await apiClient.post(
                    '/device/emergencyAlert.php',
                    {
                      'event_type': 'OBSTACLE_ALERT',
                      'device_id': _device?.deviceId,
                      'distance': distance,
                      'severity': distance < 10 ? 'CRITICAL' : (distance >= 20 && distance <= 30 ? 'HIGH' : 'MEDIUM'),
                    },
                    requireAuth: true,
                  );
                  print('Obstacle alert sent to dashboard: ${distance}cm');
                } catch (e) {
                  print('Error sending obstacle alert to dashboard: $e');
                }
                
                // Audio recording is handled by ESP32-CAM external microphone (1 minute recording)
                // No need to record from phone - ESP32 will record and upload automatically
                print('Obstacle detected - ESP32 will record 1 minute audio from external microphone');
              }
            }
          }
          
          // Audio recording is handled by ESP32-CAM external microphone
          // Backend flag is informational - ESP32 records automatically on obstacle/emergency
          if (payload != null && payload['trigger_audio_recording'] == true) {
            print('Audio recording will be handled by ESP32 external microphone');
          }
        }
      } catch (e) {
        // Only log if not authentication error
        if (!e.toString().contains('Authentication required')) {
          print('Error checking sensor events: $e');
        }
        // Stop polling on auth error
        if (e.toString().contains('Authentication required')) {
          _isSensorPolling = false;
          return;
        }
      } finally {
        _isSensorPolling = false;
      }
      
      // Continue polling only if mounted and authenticated - very fast polling for immediate alerts
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _startSensorEventListening();
        });
      }
    });
  }
  
  bool _shouldAlertObstacle(double distance) {
    // User requirement: Alert for 50-100cm range, NO alert for 10-30cm
    
    // Alert for 50-100cm range OR very close (<10cm)
    if ((distance >= 50 && distance <= 100) || distance < 10) {
      // If distance changed significantly (new obstacle), allow alert immediately
      if (_lastObstacleDistance != null) {
        final distanceChange = (distance - _lastObstacleDistance!).abs();
        // If distance changed by more than 15cm, it's a new obstacle - allow alert
        if (distanceChange > 15) {
          return true; // New obstacle detected - alert immediately
        }
      }
      
      // If obstacle moved away (distance increased significantly), allow new alert
      if (_lastObstacleDistance != null && distance > _lastObstacleDistance! + 20) {
        return true; // Obstacle moved away, new obstacle might be ahead
      }
      
      // Don't alert if recently alerted for same obstacle
      if (_lastObstacleAlertTime != null) {
        final timeSinceLastAlert = DateTime.now().difference(_lastObstacleAlertTime!);
        if (timeSinceLastAlert < _obstacleAlertCooldown) {
          // Check if it's the same obstacle (similar distance)
          if (_lastObstacleDistance != null) {
            final distanceChange = (distance - _lastObstacleDistance!).abs();
            if (distanceChange < 10) {
              return false; // Same obstacle, still in cooldown
            }
          }
        }
      }
      
      return true;
    }
    
    // NO alert for 10-30cm range (user requirement - too close, might be false positive)
    if (distance >= 10 && distance < 50) {
      return false;
    }
    
    // No alert for other ranges
    return false;
  }

  Widget _buildWebViewStream() {
    if (_streamUrl == null || _streamUrl!.isEmpty) {
      return _buildStreamLoading();
    }

    // Clean URL before using in WebView
    String cleanStreamUrl = _streamUrl!.trim();
    try {
      final streamUri = Uri.parse(cleanStreamUrl);
      String cleanHost = streamUri.host;
      // Remove trailing dots from host
      while (cleanHost.endsWith('.')) {
        cleanHost = cleanHost.substring(0, cleanHost.length - 1);
      }
      // Rebuild URL with clean host
      final cleanUri = streamUri.replace(host: cleanHost);
      cleanStreamUrl = cleanUri.toString();
      if (cleanStreamUrl != _streamUrl) {
        print('WebView: Cleaned stream URL: $_streamUrl -> $cleanStreamUrl');
        _streamUrl = cleanStreamUrl;
      }
    } catch (e) {
      print('Error cleaning stream URL for WebView: $e');
    }

    // Initialize WebView controller if not already done
    if (_webViewController == null) {
      _webViewController = webview.WebViewController()
        ..setJavaScriptMode(webview.JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          webview.NavigationDelegate(
            onPageStarted: (String url) {
              print('WebView loading stream: $url');
            },
            onPageFinished: (String url) {
              print('WebView finished loading: $url');
              if (mounted) {
                setState(() {
                  _isStreamInitialized = true;
                });
              }
            },
            onWebResourceError: (error) {
              print('WebView error: ${error.description}');
              print('Error Code: ${error.errorCode}');
              print('Error Type: ${error.errorType}');
              print('Stream URL: $cleanStreamUrl');
              
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
                      '4. Use browser to test: $_streamUrl\n\n'
                      'Stream URL: $_streamUrl';
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
                          _useWebViewFallback = false;
                          _retryCount = 0;
                        });
                        _initializeVideoPlayer();
                      },
                    ),
                  ),
                );
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(cleanStreamUrl));
    }

    return webview.WebViewWidget(controller: _webViewController!);
  }

  Widget _buildStreamLoading() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading stream...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to set manual stream URL
  Future<void> _showStreamUrlSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString(AppConstants.prefManualStreamUrl) ?? '';
    
    final TextEditingController urlController = TextEditingController(text: currentUrl);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Text(
          'Stream URL Settings',
          style: NeonColors.neonText(color: NeonColors.lightNeonCyan, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter stream URL manually (e.g., http://192.168.43.1:81/stream)\n\nLeave empty to use backend URL.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Stream URL',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'http://192.168.43.1:81/stream',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: NeonColors.lightNeonCyan),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: NeonColors.lightNeonCyan.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: NeonColors.lightNeonCyan, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Clear manual URL
              await prefs.remove(AppConstants.prefManualStreamUrl);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual stream URL cleared. Using backend URL.')),
                );
                // Reload stream URL
                _loadDeviceStatus();
              }
              Navigator.pop(context);
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              String url = urlController.text.trim();
              
              // Clean URL: Remove trailing dots and spaces
              if (url.isNotEmpty) {
                // Remove trailing dots
                while (url.endsWith('.')) {
                  url = url.substring(0, url.length - 1);
                }
                url = url.trim();
                
                // Validate URL format
                try {
                  final uri = Uri.parse(url);
                  if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
                    // Clean the host to remove trailing dots
                    String cleanHost = uri.host;
                    while (cleanHost.endsWith('.')) {
                      cleanHost = cleanHost.substring(0, cleanHost.length - 1);
                    }
                    
                    // Rebuild URL with clean host
                    final cleanUri = uri.replace(host: cleanHost);
                    final cleanUrl = cleanUri.toString();
                    
                    await prefs.setString(AppConstants.prefManualStreamUrl, cleanUrl);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Stream URL saved: $cleanUrl')),
                      );
                      // Reload stream URL
                      _loadDeviceStatus();
                    }
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid URL format. Use http:// or https://')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid URL: $e')),
                  );
                }
              } else {
                // Empty URL - clear manual setting
                await prefs.remove(AppConstants.prefManualStreamUrl);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Manual stream URL cleared. Using backend URL.')),
                  );
                  _loadDeviceStatus();
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonColors.lightNeonCyan,
            ),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _webViewController = null;
    _touchSensor.dispose();
    _voiceAssistant.dispose();
    _isSensorPolling = false;
    super.dispose();
  }
}

