/**
 * SAARTHI Flutter App - Touch Sensor Handler
 * Handles touch sensor events from ESP32 and triggers audio recording + WhatsApp
 */

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'audio_recording_service.dart';
import 'whatsapp_service.dart';
import 'device_service.dart';
import 'api_client.dart';
import '../../core/constants.dart';

class TouchSensorHandler {
  final AudioRecordingService _audioRecorder = AudioRecordingService();
  final WhatsAppService _whatsappService = WhatsAppService();
  final DeviceService _deviceService = DeviceService();
  final ApiClient _apiClient = ApiClient();
  
  bool _isHandlingTouch = false;

  /// Handle touch sensor event from ESP32
  Future<void> handleTouchEvent({
    required String eventType,
    String? imageUrl,
    Map<String, dynamic>? sensorData,
  }) async {
    if (_isHandlingTouch) return; // Prevent multiple simultaneous recordings
    
    _isHandlingTouch = true;
    
    try {
      // Start audio recording
      final recordingPath = await _audioRecorder.startRecording();
      if (recordingPath == null) {
        print('Failed to start audio recording');
        _isHandlingTouch = false;
        return;
      }
      
      print('Audio recording started: $recordingPath');
      
      // Record for 10 seconds (or until stopped)
      await Future.delayed(const Duration(seconds: 10));
      
      // Stop recording
      final audioPath = await _audioRecorder.stopRecording();
      
      if (audioPath != null) {
        print('Audio recording saved: $audioPath');
        
        // Get device info for context
        final devices = await _deviceService.getUserDevices();
        final device = devices.isNotEmpty ? devices.first : null;
        
        // Get emergency contacts
        final contacts = await _whatsappService.getEmergencyContacts();
        
        // Prepare message
        String message = '🚨 SAARTHI Alert\n\n';
        message += 'Event Type: $eventType\n';
        if (sensorData != null) {
          message += 'Sensor Data: ${sensorData.toString()}\n';
        }
        if (device != null) {
          message += 'Device: ${device.deviceId}\n';
        }
        message += 'Time: ${DateTime.now().toString()}\n';
        message += '\nAudio recording and image attached.';
        
        // Send to all emergency contacts
        for (final contact in contacts) {
          final phone = contact['phone']?.toString() ?? '';
          if (phone.isNotEmpty) {
            await _whatsappService.sendMessage(
              phoneNumber: phone,
              message: message,
              imagePath: imageUrl,
              audioPath: audioPath,
            );
          }
        }
        
        // Also save to local device
        await _saveToLocalDevice(audioPath, imageUrl, eventType);
        
        print('Touch event handled successfully');
      }
    } catch (e) {
      print('Error handling touch event: $e');
    } finally {
      _isHandlingTouch = false;
    }
  }

  Future<void> _saveToLocalDevice(String audioPath, String? imageUrl, String eventType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final infoFile = File('${directory.path}/touch_event_$timestamp.txt');
      
      await infoFile.writeAsString(
        'Event Type: $eventType\n'
        'Time: ${DateTime.now()}\n'
        'Audio: $audioPath\n'
        'Image: ${imageUrl ?? "N/A"}\n',
      );
    } catch (e) {
      print('Error saving to local device: $e');
    }
  }
}

