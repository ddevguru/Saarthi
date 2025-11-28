/**
 * SAARTHI Flutter App - Audio Recording Service
 * Records audio and saves to device storage
 * Note: Audio recording is only supported on Android/iOS
 */

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants.dart';
import 'api_client.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final ApiClient _apiClient = ApiClient();
  String? _currentRecordingPath;
  bool _isRecording = false;
  int? _currentEventId; // Store event ID for uploading

  /// Check if recording is supported on current platform
  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || 
           defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Start audio recording
  /// NOTE: DISABLED - Phone microphone recording is NOT used
  /// All audio recording is handled by ESP32-CAM external microphone
  /// This function is kept for compatibility but does not record from phone
  Future<String?> startRecording() async {
    // DISABLED: Phone microphone recording is not used
    // ESP32-CAM handles all audio recording via external microphone
    print('Phone microphone recording is DISABLED. ESP32-CAM will handle audio recording.');
    return null;
    
    /* DISABLED CODE - Phone recording not used
    if (_isRecording) {
      return _currentRecordingPath;
    }

    if (!isSupported) {
      print('Audio recording not supported on this platform');
      return null;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'saarthi_recording_$timestamp.m4a';
      final filePath = '${directory.path}/$fileName';

      if (await _recorder.hasPermission()) {
        // Use external microphone if available (for ESP32-CAM external mic)
        // The record package automatically uses the default microphone input
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            autoGain: true,
            echoCancel: false,
            noiseSuppress: false,
          ),
          path: filePath,
        );

        _isRecording = true;
        _currentRecordingPath = filePath;
        print('Audio recording started: $filePath');
        return filePath;
      } else {
        throw Exception('Microphone permission not granted');
      }
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
    */
  }

  /// Stop audio recording and upload to backend
  Future<String?> stopRecording({int? eventId}) async {
    if (!_isRecording) {
      return _currentRecordingPath;
    }

    if (!isSupported) {
      _isRecording = false;
      return _currentRecordingPath;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _currentRecordingPath = path;
      print('Audio recording stopped: $path');
      
      // Upload to backend if path exists
      if (path != null && path.isNotEmpty) {
        _uploadAudioToBackend(path, eventId ?? _currentEventId);
      }
      
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }
  
  /// Upload audio file to backend
  Future<void> _uploadAudioToBackend(String filePath, int? eventId) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Audio file does not exist: $filePath');
        return;
      }
      
      final token = await _apiClient.getToken();
      if (token == null || token.isEmpty) {
        print('No authentication token for audio upload');
        return;
      }
      
      final uri = Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.uploadAudioEndpoint}');
      
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      request.files.add(
        await http.MultipartFile.fromPath('audio', filePath),
      );
      
      if (eventId != null) {
        request.fields['event_id'] = eventId.toString();
      }
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          print('Audio uploaded successfully: ${data['data']?['audio_path']}');
        } else {
          print('Audio upload failed: ${data['message']}');
        }
      } else {
        print('Audio upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading audio: $e');
    }
  }
  
  /// Set event ID for current recording
  void setEventId(int? eventId) {
    _currentEventId = eventId;
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Delete recording file
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting recording: $e');
      return false;
    }
  }
}
