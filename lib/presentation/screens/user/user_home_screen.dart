/**
 * SAARTHI Flutter App - User Home Screen
 * Main screen for users with SOS button and device status
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  bool _isStreamInitialized = false;
  
  // Obstacle alert debouncing
  DateTime? _lastObstacleAlertTime;
  static const Duration _obstacleAlertCooldown = Duration(seconds: 10);
  double? _lastObstacleDistance;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadDeviceStatus();
    _initializeVoiceAssistant();
    _initializeTouchSensor();
  }

  void _initializeTouchSensor() {
    _touchSensor.initialize(
      onLongPress: _handleLongPress,
      onSingleTap: _handleSingleTap,
      onDoubleTap: _handleDoubleTap,
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
    print('Single tap detected - triggering emergency alert');
    // Single tap = Emergency alert (not voice assistant)
    await _voiceAssistant.speak("Emergency alert! आपातकालीन चेतावनी!");
    
    // ESP32-CAM will automatically record audio from external microphone
    // No need to record from phone - ESP32 handles it
    
    // Capture photo via ESP32 (send command to backend)
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/device/triggerPhotoCapture.php',
        {
          'device_id': _device?.deviceId,
          'event_type': 'SINGLE_TAP_EMERGENCY',
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
          'event_type': 'SINGLE_TAP_EMERGENCY',
          'device_id': _device?.deviceId,
        },
        requireAuth: true,
      );
    } catch (e) {
      print('Error sending emergency alert: $e');
    }
  }

  Future<void> _handleDoubleTap() async {
    // Play music (placeholder - can integrate with audio player)
    await _voiceAssistant.speak("Playing music. संगीत चल रहा है।");
    // TODO: Integrate with music player
  }

  Future<void> _initializeVoiceAssistant() async {
    await _voiceAssistant.initialize();
    // Check for proactive alerts periodically
    _voiceAssistant.checkProactiveAlerts();
  }

  Future<void> _loadDeviceStatus() async {
    setState(() {
      _isLoadingDevice = true;
    });
    
    try {
      final devices = await _deviceService.getUserDevices();
      if (devices.isNotEmpty) {
        setState(() {
          _device = devices.first;
          // Use stream_url from device if available, otherwise build from IP
          _streamUrl = _device?.streamUrl ?? _deviceService.buildStreamUrl(_device, _device?.ipAddress);
          
          print('Device stream URL: $_streamUrl');
          print('Device IP: ${_device?.ipAddress}');
          print('Device online: ${_deviceService.checkDeviceOnline(_device)}');
          
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
        
        // Start listening for sensor events
        _startSensorEventListening();
      } else {
        // Try to refresh from API
        await Future.delayed(const Duration(seconds: 1));
        final refreshedDevices = await _deviceService.getUserDevices();
        if (refreshedDevices.isNotEmpty) {
          setState(() {
            _device = refreshedDevices.first;
            // Use stream_url from device if available, otherwise build from IP
            _streamUrl = _device?.streamUrl ?? _deviceService.buildStreamUrl(_device, _device?.ipAddress);
            
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
    _locationService.getLocationStream().listen((position) {
      _locationService.updateLocationToBackend(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
      );
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
              // TODO: Send SOS to backend
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
        title: ShaderMask(
          shaderCallback: NeonColors.lightNeonGradientShader,
          child: Text(
            l10n.home,
            style: NeonColors.neonText(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: NeonColors.lightNeonPink,
            ),
          ),
        ),
        actions: [
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
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
                      const SizedBox(height: 12),
                      if (_isStreamInitialized && _videoController != null && _videoController!.value.isInitialized)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: VideoPlayer(_videoController!),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
                            ),
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
                                  final uri = Uri.parse(_streamUrl!);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                      color: Colors.white70,
                      fontSize: 12,
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
  static const int _maxRetries = 3;
  
  void _initializeVideoPlayer() {
    if (_streamUrl == null || _streamUrl!.isEmpty) {
      print('Stream URL is null or empty');
      return;
    }
    
    if (_isStreamInitialized) {
      print('Video player already initialized');
      return;
    }
    
    if (_retryCount >= _maxRetries) {
      print('Max retries reached for video player initialization');
      return;
    }
    
    _videoController?.dispose();
    
    // Validate and parse stream URL
    try {
      final streamUri = Uri.parse(_streamUrl!);
      
      // Validate URL format
      if (streamUri.scheme != 'http' && streamUri.scheme != 'https') {
        print('Invalid stream URL scheme: ${streamUri.scheme}');
        return;
      }
      
      print('Initializing video player with URL: $_streamUrl (attempt ${_retryCount + 1}/$_maxRetries)');
      
      // For MJPEG streams from ESP32-CAM
      _videoController = VideoPlayerController.networkUrl(
        streamUri,
        httpHeaders: {
          'Connection': 'keep-alive',
          'Cache-Control': 'no-cache',
          'Accept': 'multipart/x-mixed-replace; boundary=--jpgboundary, image/jpeg, */*',
          'User-Agent': 'Saarthi-App/1.0',
        },
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: true,
          mixWithOthers: false,
        ),
      );
      
      // Set timeout for initialization (15 seconds)
      _videoController!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Video player initialization timeout after 15 seconds');
          throw TimeoutException('Video initialization timeout');
        },
      ).then((_) {
        if (mounted && _videoController != null) {
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
        _retryCount++;
        
        if (mounted) {
          setState(() {
            _isStreamInitialized = false;
          });
        }
        
        // Retry after delay if retries remaining
        if (mounted && _retryCount < _maxRetries) {
          print('Retrying video player initialization in 3 seconds (attempt $_retryCount/$_maxRetries)...');
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !_isStreamInitialized && _streamUrl != null && _streamUrl!.isNotEmpty) {
              _initializeVideoPlayer();
            }
          });
        } else {
          // Max retries reached - show error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stream connection failed. Please check device connection and IP address.'),
                backgroundColor: NeonColors.neonPink.withOpacity(0.8),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    _retryCount = 0;
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
            backgroundColor: NeonColors.neonPink.withOpacity(0.8),
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
    
    // Poll for sensor events every 3 seconds (reduced frequency)
    Future.delayed(const Duration(seconds: 3), () async {
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
                
                // Audio recording is handled by ESP32-CAM external microphone
                // No need to record from phone - ESP32 will record and upload automatically
                print('Obstacle detected - ESP32 will record audio from external microphone');
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
      
      // Continue polling only if mounted and authenticated
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          _startSensorEventListening();
        });
      }
    });
  }
  
  bool _shouldAlertObstacle(double distance) {
    // User requirement: Alert for 20cm range AND 50-100cm range
    
    // Alert for 20-30cm range OR 50-100cm range OR very close (<10cm)
    if ((distance >= 20 && distance <= 30) || 
        (distance >= 50 && distance <= 100) || 
        distance < 10) {
      // Don't alert if recently alerted (10 second cooldown)
      if (_lastObstacleAlertTime != null) {
        final timeSinceLastAlert = DateTime.now().difference(_lastObstacleAlertTime!);
        if (timeSinceLastAlert < _obstacleAlertCooldown) {
          return false;
        }
      }
      
      // Alert if distance changed significantly (new obstacle)
      if (_lastObstacleDistance != null) {
        final distanceChange = (distance - _lastObstacleDistance!).abs();
        // Only alert if moved significantly (at least 10cm change)
        if (distanceChange < 10) {
          return false; // Same obstacle
        }
      }
      
      return true;
    }
    
    // NO alert for 10-20cm range (too close, might be false positive)
    if (distance >= 10 && distance < 20) {
      return false;
    }
    
    // No alert for other ranges
    return false;
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _touchSensor.dispose();
    _voiceAssistant.dispose();
    _isSensorPolling = false;
    super.dispose();
  }
}

