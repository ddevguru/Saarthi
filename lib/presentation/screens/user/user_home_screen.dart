/**
 * SAARTHI Flutter App - User Home Screen
 * Main screen for users with SOS button and device status
 */

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/device_service.dart';
import '../../../data/services/voice_assistant_service.dart';
import '../../../data/services/smart_ai_service.dart';
import '../../../data/services/audio_recording_service.dart';
import '../../../data/services/touch_sensor_service.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/device.dart';
import '../../../core/constants.dart';
import '../../widgets/device_status_card.dart';
import '../../widgets/voice_assistant_button.dart';
import '../../widgets/smart_ai_card.dart';
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
  final AudioRecordingService _audioRecorder = AudioRecordingService();
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
    await _voiceAssistant.speak("Critical emergency! गंभीर आपातकाल! Recording started. रिकॉर्डिंग शुरू हो गई है।");
    
    // Start audio recording
    await _audioRecorder.startRecording();
    
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
    
    // Send emergency event to backend
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/device/emergencyAlert.php',
        {
          'event_type': 'LONG_PRESS_EMERGENCY',
          'device_id': _device?.deviceId,
        },
        requireAuth: true,
      );
      
      // Get event ID from response for linking audio
      if (response['data'] != null && response['data']['event_id'] != null) {
        final eventId = response['data']['event_id'] as int;
        _audioRecorder.setEventId(eventId);
      }
    } catch (e) {
      print('Error sending emergency alert: $e');
    }
    
    // Stop recording after 10 seconds and upload
    Future.delayed(const Duration(seconds: 10), () async {
      if (_audioRecorder.isRecording) {
        await _audioRecorder.stopRecording();
      }
    });
  }

  Future<void> _handleSingleTap() async {
    print('Single tap detected - triggering emergency alert');
    // Single tap = Emergency alert (not voice assistant)
    await _voiceAssistant.speak("Emergency alert! आपातकालीन चेतावनी! Recording started. रिकॉर्डिंग शुरू हो गई है।");
    
    // Start audio recording
    await _audioRecorder.startRecording();
    
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
    
    // Send emergency event to backend
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/device/emergencyAlert.php',
        {
          'event_type': 'SINGLE_TAP_EMERGENCY',
          'device_id': _device?.deviceId,
        },
        requireAuth: true,
      );
      
      // Get event ID from response for linking audio
      if (response['data'] != null && response['data']['event_id'] != null) {
        final eventId = response['data']['event_id'] as int;
        _audioRecorder.setEventId(eventId);
      }
    } catch (e) {
      print('Error sending emergency alert: $e');
    }
    
    // Stop recording after 10 seconds and upload
    Future.delayed(const Duration(seconds: 10), () async {
      if (_audioRecorder.isRecording) {
        await _audioRecorder.stopRecording();
      }
    });
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
            _initializeVideoPlayer();
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
              _initializeVideoPlayer();
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
      appBar: AppBar(
        title: Text(l10n.home),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device Status Card
            _isLoadingDevice
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : _device == null
                    ? Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No Device Found',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please register your ESP32-CAM device. Make sure the device is connected and registered with your account.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    : DeviceStatusCard(
                        isConnected: _deviceService.checkDeviceOnline(_device),
                        lastEvent: null, // TODO: Get from API
                        lastEventTime: _device?.lastSeen,
                      ),
            const SizedBox(height: 24),
            
            // Live Stream Section
            if (_device != null && _streamUrl != null && _streamUrl!.isNotEmpty && _deviceService.checkDeviceOnline(_device))
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam, color: AppTheme.secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Live Stream',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    if (_isStreamInitialized && _videoController != null && _videoController!.value.isInitialized)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: VideoPlayer(_videoController!),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
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
            
            // SOS Button
            ElevatedButton(
              onPressed: _triggerSOS,
              style: AppTheme.sosButtonStyle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    l10n.sosButton,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Location Sharing Toggle
            Card(
              child: SwitchListTile(
                title: Text(l10n.shareLocation),
                subtitle: Text(_isSharingLocation 
                    ? 'Location is being shared' 
                    : 'Enable to share live location'),
                value: _isSharingLocation,
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
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/navigation-assist');
                    },
                    icon: const Icon(Icons.navigation),
                    label: Text(l10n.navigation),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/quick-messages');
                    },
                    icon: const Icon(Icons.message),
                    label: Text(l10n.quickMessages),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    if (_streamUrl != null && !_isStreamInitialized && _retryCount < _maxRetries) {
      _videoController?.dispose();
      
      // Handle HTTP streams - allow cleartext for local network
      final streamUri = Uri.parse(_streamUrl!);
      print('Initializing video player with URL: $_streamUrl (attempt ${_retryCount + 1}/$_maxRetries)');
      
      // For MJPEG streams from ESP32-CAM
      _videoController = VideoPlayerController.networkUrl(
        streamUri,
        httpHeaders: {
          'Connection': 'keep-alive',
          'Cache-Control': 'no-cache',
          'Accept': '*/*',
        },
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: true,
        ),
      );
      
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isStreamInitialized = true;
            _retryCount = 0; // Reset retry count on success
          });
          _videoController!.play();
          _videoController!.setLooping(true);
          print('Video player initialized successfully');
        }
      }).catchError((error) {
        print('Error initializing video player: $error');
        _retryCount++;
        
        // Retry after delay if retries remaining
        if (mounted && _retryCount < _maxRetries) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && !_isStreamInitialized && _streamUrl != null) {
              print('Retrying video player initialization (attempt $_retryCount)...');
              _initializeVideoPlayer();
            }
          });
        } else {
          // Max retries reached - show error to user
          if (mounted) {
            setState(() {
              _isStreamInitialized = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stream connection failed. Please check device connection.'),
                action: SnackBarAction(
                  label: 'Retry',
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
          
          // Check for obstacle alert - Alert for 50-100cm range
          if (data['event_type'] == 'OBSTACLE_ALERT' && payload != null) {
            final distance = payload['distance'] as double?;
            
            // Alert logic: 50-100cm = alert, 10-30cm = no alert
            if (distance != null && distance > 0) {
              final shouldAlert = _shouldAlertObstacle(distance);
              
              if (shouldAlert) {
                _lastObstacleAlertTime = DateTime.now();
                _lastObstacleDistance = distance;
                
                // Different messages based on distance
                if (distance < 10) {
                  await _voiceAssistant.speak("Critical! Obstacle very close! बहुत करीब बाधा! सावधान!");
                } else if (distance >= 50 && distance <= 100) {
                  await _voiceAssistant.speak("Obstacle detected ahead. बाधा का पता चला।");
                }
                
                // Always start audio recording when obstacle is detected (ESP32 external mic)
                // Note: Recording uses ESP32's external microphone, not phone's mic
                if (!_audioRecorder.isRecording) {
                  // Get event ID from the event data
                  final eventId = data['id'] as int?;
                  if (eventId != null) {
                    _audioRecorder.setEventId(eventId);
                  }
                  
                  await _audioRecorder.startRecording();
                  print('Audio recording started for obstacle at ${distance}cm, event_id: $eventId');
                  // Stop recording after 10 seconds and upload
                  Future.delayed(const Duration(seconds: 10), () async {
                    if (_audioRecorder.isRecording) {
                      await _audioRecorder.stopRecording(eventId: eventId);
                      print('Audio recording stopped and uploaded after 10 seconds');
                    }
                  });
                }
              }
            }
          }
          
          // Check for trigger_audio_recording flag from backend
          // Note: Recording uses ESP32's external microphone, not phone's mic
          if (payload != null && payload['trigger_audio_recording'] == true) {
            if (!_audioRecorder.isRecording) {
              // Get event ID from the event data
              final eventId = data['id'] as int?;
              if (eventId != null) {
                _audioRecorder.setEventId(eventId);
              }
              
              await _audioRecorder.startRecording();
              print('Audio recording triggered by backend flag, event_id: $eventId');
              // Stop recording after 10 seconds and upload
              Future.delayed(const Duration(seconds: 10), () async {
                if (_audioRecorder.isRecording) {
                  await _audioRecorder.stopRecording(eventId: eventId);
                  print('Audio recording stopped and uploaded');
                }
              });
            }
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
    // User requirement: Alert for 50-100cm, NO alert for 10-30cm
    
    // Alert for 50-100cm range OR very close (<10cm)
    if ((distance >= 50 && distance <= 100) || distance < 10) {
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
    
    // NO alert for 10-30cm range (user requirement)
    if (distance >= 10 && distance <= 30) {
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

