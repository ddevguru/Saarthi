/**
 * SAARTHI Flutter App - Touch Sensor Handler
 * Handles touch sensor events from ESP32 and triggers audio recording + WhatsApp
 */

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'whatsapp_service.dart';
import 'device_service.dart';

class TouchSensorHandler {
  final WhatsAppService _whatsappService = WhatsAppService();
  final DeviceService _deviceService = DeviceService();
  
  bool _isHandlingTouch = false;

  /// Handle touch sensor event from ESP32
  /// NOTE: Phone microphone recording is DISABLED
  /// ESP32-CAM handles all audio recording via external microphone automatically
  Future<void> handleTouchEvent({
    required String eventType,
    String? imageUrl,
    Map<String, dynamic>? sensorData,
  }) async {
    if (_isHandlingTouch) return; // Prevent multiple simultaneous handling
    
    _isHandlingTouch = true;
    
    try {
      // Phone microphone recording is DISABLED
      // ESP32-CAM automatically records audio via external microphone during events
      print('Touch event detected. ESP32-CAM will handle audio recording automatically.');
      
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
      message += '\nESP32-CAM is recording audio automatically. Image attached.';
      
      // Send to all emergency contacts (without phone audio - ESP32 handles it)
      for (final contact in contacts) {
        final phone = contact['phone']?.toString() ?? '';
        if (phone.isNotEmpty) {
          await _whatsappService.sendMessage(
            phoneNumber: phone,
            message: message,
            imagePath: imageUrl,
            audioPath: null, // No phone audio - ESP32 handles recording
          );
        }
      }
      
      // Also save event info to local device (without phone audio)
      await _saveToLocalDevice(null, imageUrl, eventType);
      
      print('Touch event handled successfully. ESP32-CAM will upload audio recording separately.');
    } catch (e) {
      print('Error handling touch event: $e');
    } finally {
      _isHandlingTouch = false;
    }
  }

  Future<void> _saveToLocalDevice(String? audioPath, String? imageUrl, String eventType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final infoFile = File('${directory.path}/touch_event_$timestamp.txt');
      
      await infoFile.writeAsString(
        'Event Type: $eventType\n'
        'Time: ${DateTime.now()}\n'
        'Audio: ${audioPath ?? "ESP32-CAM will record automatically"}\n'
        'Image: ${imageUrl ?? "N/A"}\n',
      );
    } catch (e) {
      print('Error saving to local device: $e');
    }
  }
}

