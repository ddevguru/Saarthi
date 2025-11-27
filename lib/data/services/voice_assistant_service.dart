/**
 * SAARTHI Flutter App - Voice Assistant Service
 * Smart AI-powered voice assistant like Google Assistant
 */

import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'device_service.dart';
import 'smart_ai_service.dart';
import 'wake_word_service.dart';
import 'audio_recording_service.dart';
import 'phone_control_service.dart';

class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final DeviceService _deviceService = DeviceService();
  final SmartAIService _smartAI = SmartAIService();
  final WakeWordService _wakeWordService = WakeWordService();
  final AudioRecordingService _audioRecorder = AudioRecordingService();
  final PhoneControlService _phoneControl = PhoneControlService();
  
  bool _isListening = false;
  bool _isInitialized = false;
  Function(String)? _onCommandRecognized;
  
  // Context-aware responses
  DateTime? _lastInteraction;
  
  bool _isInitializing = false;
  
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    
    try {
      // Initialize TTS
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // Initialize STT
      _isInitialized = await _stt.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          // Handle timeout errors gracefully - they're not permanent failures
          if (error.errorMsg.contains('timeout') || 
              error.errorMsg.contains('error_speech_timeout')) {
            print('Speech recognition timeout (normal - user may not have spoken)');
            _isListening = false;
            // Don't treat timeout as permanent error
            return;
          }
          // Don't log client errors repeatedly
          if (!error.errorMsg.contains('error_client') && 
              !error.errorMsg.contains('error_busy')) {
            print('Speech recognition error: ${error.errorMsg}');
          }
          _isListening = false;
        },
      );
      
      // Initialize wake word service
      await _wakeWordService.initialize();
      
      // Start listening for wake word
      _startWakeWordListening();
    } finally {
      _isInitializing = false;
    }
  }

  void _startWakeWordListening() {
    _wakeWordService.startListening(
      onWakeWordDetected: () {
        print('Wake word detected - listening for command...');
        
        // Speak acknowledgment
        speak("Yes, I'm listening. How can I help you?").then((_) {
          // Start listening for command after acknowledgment
          Future.delayed(const Duration(milliseconds: 500), () {
            startListening(onResult: (command) {
              if (command.trim().isNotEmpty && 
                  !command.toLowerCase().contains('saarthi') &&
                  !command.toLowerCase().contains('hey')) {
                print('Processing command after wake word: $command');
                _processCommand(command);
              } else {
                print('Ignoring wake word as command: $command');
                // Restart listening
                Future.delayed(const Duration(seconds: 1), () {
                  _startWakeWordListening();
                });
              }
            });
          });
        });
      },
    );
    
    // Also start continuous listening mode for background operation
    _startContinuousListening();
  }
  
  bool _isContinuousListeningActive = false;
  Timer? _continuousListeningTimer;
  
  void _startContinuousListening() {
    // Prevent multiple instances
    if (_isContinuousListeningActive) return;
    _isContinuousListeningActive = true;
    
    // Cancel any existing timer
    _continuousListeningTimer?.cancel();
    
    // Keep listening in background - restart after each command
    _continuousListeningTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isInitialized) {
        timer.cancel();
        _isContinuousListeningActive = false;
        return;
      }
      
      if (!_isListening) {
        startListening(onResult: (command) {
          // Only process if command is not empty and not "ai_response"
          final trimmedCommand = command.trim().toLowerCase();
          if (trimmedCommand.isNotEmpty && 
              trimmedCommand != 'ai_response' && 
              trimmedCommand != 'error' &&
              !trimmedCommand.contains('error')) {
            _processCommand(command);
          } else {
            print('Ignoring invalid command: $command');
          }
        });
      }
    });
  }
  
  void _stopContinuousListening() {
    _continuousListeningTimer?.cancel();
    _isContinuousListeningActive = false;
  }

  /// Speak text with TTS (auto-detect language)
  Future<void> speak(String text) async {
    await initialize();
    
    // Auto-detect language (Hindi or English)
    final hasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    if (hasHindi) {
      await _tts.setLanguage("hi-IN");
    } else {
      await _tts.setLanguage("en-US");
    }
    
    await _tts.speak(text);
  }

  /// Start listening for voice commands
  Future<void> startListening({Function(String)? onResult}) async {
    try {
      if (!_isInitialized) {
        print('Voice assistant not initialized, initializing now...');
        await initialize();
      }
      
      if (_isListening) {
        print('Already listening, stopping previous session...');
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      _onCommandRecognized = onResult;
      _isListening = true;
      
      print('Starting speech recognition...');
      await _stt.listen(
        onResult: (result) {
          print('Speech recognition result: ${result.recognizedWords} (final: ${result.finalResult})');
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _isListening = false;
            final command = result.recognizedWords.trim();
            print('Processing command: $command');
            _processCommand(command);
            if (_onCommandRecognized != null) {
              _onCommandRecognized!(command);
            }
          }
        },
        listenFor: const Duration(seconds: 10), // Increased timeout
        pauseFor: const Duration(seconds: 3), // Increased pause time
        partialResults: false,
        cancelOnError: false, // Don't cancel on timeout errors
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      _isListening = false;
      // Retry after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isListening) {
          startListening(onResult: onResult);
        }
      });
    }
  }
  

  /// Stop listening
  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
    _stopContinuousListening();
  }
  
  /// Dispose and cleanup
  void dispose() {
    _stopContinuousListening();
    _stt.stop();
    _isListening = false;
    _isInitialized = false;
  }

  String? _lastProcessedCommand;
  DateTime? _lastCommandTime;
  
  /// Process voice command with AI-like understanding (Hindi + English)
  void _processCommand(String command) {
    if (command.isEmpty || command.trim().isEmpty) {
      print('Empty command received, ignoring...');
      return;
    }
    
    final lowerCommand = command.toLowerCase().trim();
    
    // Prevent processing same command repeatedly
    if (_lastProcessedCommand == lowerCommand) {
      final timeSinceLastCommand = _lastCommandTime != null 
          ? DateTime.now().difference(_lastCommandTime!) 
          : Duration.zero;
      if (timeSinceLastCommand < const Duration(seconds: 3)) {
        print('Ignoring duplicate command: $command');
        return;
      }
    }
    
    _lastProcessedCommand = lowerCommand;
    _lastCommandTime = DateTime.now();
    _lastInteraction = DateTime.now();
    
    print('Processing voice command: $command');
    
    // Hindi and English patterns for all commands
    // Greeting detection (Hindi + English)
    if (_matchesPattern(lowerCommand, ['hello', 'hi', 'hey', 'namaste', 'नमस्ते', 'नमस्कार'])) {
      _handleGreeting();
      return;
    }
    
    // Open app (Hindi + English) - Check this FIRST before other commands
    if (_matchesPattern(lowerCommand, ['open', 'launch', 'start', 'खोलें', 'एप', 'शुरू', 'चलाएं', 'खोलो'])) {
      _handleOpenAppCommand(command);
      return;
    }
    
    // Call someone (Hindi + English)
    if (_matchesPattern(lowerCommand, ['call', 'phone', 'dial', 'contact', 'कॉल', 'फोन', 'डायल', 'संपर्क', 'फोन करो'])) {
      _handleCallCommand(command);
      return;
    }
    
    // Send message/WhatsApp (Hindi + English)
    if (_matchesPattern(lowerCommand, ['message', 'whatsapp', 'send', 'text', 'मैसेज', 'संदेश', 'भेजें', 'भेजो'])) {
      _handleMessageCommand(command);
      return;
    }
    
    // Settings (Hindi + English)
    if (_matchesPattern(lowerCommand, ['settings', 'setting', 'सेटिंग', 'सेटिंग्स', 'सेटिंग खोलो'])) {
      _handleOpenSettings();
      return;
    }
    
    // Device status queries (Hindi + English)
    if (_matchesPattern(lowerCommand, ['device', 'status', 'connected', 'online', 'डिवाइस', 'स्थिति', 'कनेक्ट', 'कनेक्शन'])) {
      _handleDeviceStatus();
      return;
    }
    
    // Location queries (Hindi + English)
    if (_matchesPattern(lowerCommand, ['location', 'where', 'position', 'gps', 'स्थान', 'कहाँ', 'लोकेशन', 'मेरा स्थान'])) {
      _handleLocationQuery();
      return;
    }
    
    // SOS/Emergency (Hindi + English)
    if (_matchesPattern(lowerCommand, ['sos', 'help', 'emergency', 'danger', 'bachao', 'बचाओ', 'मदद', 'आपातकाल'])) {
      _handleEmergency();
      return;
    }
    
    // Navigation (Hindi + English)
    if (_matchesPattern(lowerCommand, ['navigate', 'direction', 'route', 'way', 'guide', 'नेविगेट', 'रास्ता', 'दिशा'])) {
      _handleNavigation();
      return;
    }
    
    // Record audio (Hindi + English)
    if (_matchesPattern(lowerCommand, ['record', 'audio', 'voice note', 'रिकॉर्ड', 'आवाज', 'रिकॉर्डिंग'])) {
      _handleRecordCommand();
      return;
    }
    
    // Events/Alerts (Hindi + English)
    if (_matchesPattern(lowerCommand, ['events', 'alerts', 'notifications', 'what happened', 'घटनाएं', 'अलर्ट'])) {
      _handleEventsQuery();
      return;
    }
    
    // Proactive suggestions (Hindi + English)
    if (_matchesPattern(lowerCommand, ['suggest', 'recommend', 'what should', 'kya kare', 'सुझाव', 'क्या करें'])) {
      _handleProactiveSuggestion();
      return;
    }
    
    // Smart AI response for unknown commands
    _handleSmartAIResponse(command);
  }

  bool _matchesPattern(String command, List<String> patterns) {
    return patterns.any((pattern) => command.contains(pattern));
  }

  Future<void> _handleGreeting() async {
    final hour = DateTime.now().hour;
    String greeting = hour < 12 
        ? "Good morning" 
        : hour < 18 
            ? "Good afternoon" 
            : "Good evening";
    
    await speak("$greeting! I'm SAARTHI, your smart assistant. How can I help you today?");
    _onCommandRecognized?.call("greeting");
  }

  Future<void> _handleDeviceStatus() async {
    final devices = await _deviceService.getUserDevices();
    if (devices.isEmpty) {
      await speak("No device is currently connected. Please connect your ESP32-CAM device.");
    } else {
      final device = devices.first;
      final isOnline = _deviceService.checkDeviceOnline(device);
      if (isOnline) {
        await speak("Your device is online and working properly. All systems are operational.");
      } else {
        await speak("Your device appears to be offline. Last seen ${_formatTimeAgo(device.lastSeen)}.");
      }
    }
    _onCommandRecognized?.call("device_status");
  }

  Future<void> _handleLocationQuery() async {
    // TODO: Get current location from location service
    await speak("I'm fetching your current location. Please wait a moment.");
    _onCommandRecognized?.call("location");
  }

  Future<void> _handleEmergency() async {
    await speak("Emergency detected! Sending SOS alert to your guardians now.");
    // TODO: Trigger SOS via API
    _onCommandRecognized?.call("sos");
  }

  Future<void> _handleNavigation() async {
    await speak("Starting navigation assist mode. I'll help you navigate safely.");
    _onCommandRecognized?.call("navigation");
    // TODO: Open navigation assist screen
  }

  Future<void> _handleCallCommand(String command) async {
    // Request permissions first
    if (!await _phoneControl.hasPermissions()) {
      await _phoneControl.requestPermissions();
    }
    
    // Extract phone number or contact name (Hindi + English)
    final phoneRegex = RegExp(r'\d{10,}');
    final phoneMatch = phoneRegex.firstMatch(command);
    
    if (phoneMatch != null) {
      final phone = phoneMatch.group(0)!;
      await speak(_getResponse('calling', phone));
      final success = await _phoneControl.makeCall(phone);
      if (!success!) {
        await speak(_getResponse('call_failed'));
      }
    } else {
      // Try to extract contact name (Hindi + English patterns) - handle multi-word names
      String? contactName;
      
      // Remove common prefixes
      String cleanedCommand = command.toLowerCase();
      cleanedCommand = cleanedCommand.replaceAll(RegExp(r'^(call|phone|कॉल|फोन)\s+'), '');
      cleanedCommand = cleanedCommand.replaceAll(RegExp(r'^(to|को)\s+'), '');
      
      // Extract name (can be multiple words)
      final nameMatch = RegExp(r'^([a-z\s\u0900-\u097F]+?)(?:\s+(?:on|at|पर|से))', caseSensitive: false).firstMatch(cleanedCommand);
      if (nameMatch != null) {
        contactName = nameMatch.group(1)?.trim();
      } else {
        // Try simple word extraction
        final simpleMatch = RegExp(r'^([a-z\s\u0900-\u097F]+)', caseSensitive: false).firstMatch(cleanedCommand);
        if (simpleMatch != null) {
          contactName = simpleMatch.group(1)?.trim();
        }
      }
      
      // If still no name, try original patterns
      if (contactName == null || contactName.isEmpty) {
        final namePatterns = [
          RegExp(r'call\s+(.+?)(?:\s|$)', caseSensitive: false),
          RegExp(r'phone\s+(.+?)(?:\s|$)', caseSensitive: false),
          RegExp(r'कॉल\s+(.+?)(?:\s|$)', caseSensitive: false),
          RegExp(r'फोन\s+(.+?)(?:\s|$)', caseSensitive: false),
        ];
        
        for (final pattern in namePatterns) {
          final match = pattern.firstMatch(command);
          if (match != null) {
            contactName = match.group(1)?.trim();
            break;
          }
        }
      }
      
      if (contactName != null && contactName.isNotEmpty) {
        await speak(_getResponse('finding_contact', contactName));
        print('Searching for contact: $contactName');
        final phoneNumber = await _phoneControl.getPhoneNumberFromContact(contactName);
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          print('Found phone number: $phoneNumber');
          await speak(_getResponse('calling', contactName));
          final success = await _phoneControl.makeCall(phoneNumber);
          if (success == null || !success) {
            await speak(_getResponse('call_failed'));
          }
        } else {
          print('Contact not found: $contactName');
          await speak(_getResponse('contact_not_found', contactName));
        }
      } else {
        await speak(_getResponse('call_help'));
      }
    }
    _onCommandRecognized?.call("call");
  }

  Future<void> _handleMessageCommand(String command) async {
    // Request permissions
    if (!await _phoneControl.hasPermissions()) {
      await _phoneControl.requestPermissions();
    }
    
    // Extract contact name or phone number
    final phoneRegex = RegExp(r'\d{10,}');
    final phoneMatch = phoneRegex.firstMatch(command);
    
    String? phoneNumber;
    String? contactName;
    
    if (phoneMatch != null) {
      phoneNumber = phoneMatch.group(0)!;
    } else {
      // Extract contact name - handle multi-word names
      String cleanedCommand = command.toLowerCase();
      cleanedCommand = cleanedCommand.replaceAll(RegExp(r'^(message|send|मैसेज|भेजें)\s+'), '');
      cleanedCommand = cleanedCommand.replaceAll(RegExp(r'^(to|को)\s+'), '');
      
      // Extract name (can be multiple words)
      final nameMatch = RegExp(r'^([a-z\s\u0900-\u097F]+?)(?:\s+(?:message|text|मैसेज|टेक्स्ट|:))', caseSensitive: false).firstMatch(cleanedCommand);
      if (nameMatch != null) {
        contactName = nameMatch.group(1)?.trim();
      } else {
        // Try simple extraction
        final simpleMatch = RegExp(r'^([a-z\s\u0900-\u097F]+?)(?:\s|$)', caseSensitive: false).firstMatch(cleanedCommand);
        if (simpleMatch != null) {
          contactName = simpleMatch.group(1)?.trim();
        }
      }
      
      // If still no name, try original patterns
      if (contactName == null || contactName.isEmpty) {
        final namePatterns = [
          RegExp(r'message\s+(.+?)(?:\s+(?:message|text|:))', caseSensitive: false),
          RegExp(r'send\s+to\s+(.+?)(?:\s+(?:message|text|:))', caseSensitive: false),
          RegExp(r'मैसेज\s+(.+?)(?:\s+(?:message|text|:))', caseSensitive: false),
          RegExp(r'भेजें\s+(.+?)(?:\s+(?:message|text|:))', caseSensitive: false),
        ];
        
        for (final pattern in namePatterns) {
          final match = pattern.firstMatch(command);
          if (match != null) {
            contactName = match.group(1)?.trim();
            break;
          }
        }
      }
      
      if (contactName != null && contactName.isNotEmpty) {
        print('Searching for contact: $contactName');
        phoneNumber = await _phoneControl.getPhoneNumberFromContact(contactName);
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          print('Found phone number: $phoneNumber');
        } else {
          print('Contact not found: $contactName');
        }
      }
    }
    
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await speak(_getResponse('sending_message', contactName ?? phoneNumber));
      // Extract message text if provided
      String message = _getResponse('default_message');
      
      // Try to extract message after contact name
      if (contactName != null) {
        final messageMatch = RegExp(r'$contactName\s+(.+?)(?:\s|$)', caseSensitive: false).firstMatch(command);
        if (messageMatch != null) {
          message = messageMatch.group(1)?.trim() ?? message;
        } else {
          // Try colon separator
          final colonMatch = RegExp(r':\s*(.+)', caseSensitive: false).firstMatch(command);
          if (colonMatch != null) {
            message = colonMatch.group(1)?.trim() ?? message;
          }
        }
      }
      
      print('Sending message to $phoneNumber: $message');
      final success = await _phoneControl.sendSMS(phoneNumber, message);
      if (success) {
        await speak(_getResponse('message_sent'));
      } else {
        await speak(_getResponse('message_failed'));
      }
    } else {
      if (contactName != null && contactName.isNotEmpty) {
        await speak(_getResponse('contact_not_found', contactName));
      } else {
        await speak(_getResponse('message_help'));
      }
    }
    _onCommandRecognized?.call("message");
  }

  Future<void> _handleRecordCommand() async {
    if (_audioRecorder.isRecording) {
      await _audioRecorder.stopRecording();
      await speak("Recording stopped and saved.");
    } else {
      await _audioRecorder.startRecording();
      await speak("Recording started. Say stop recording when done.");
    }
    _onCommandRecognized?.call("record");
  }

  Future<void> _handleEventsQuery() async {
    try {
      // TODO: Fetch recent events from API
      await speak("Checking recent events. I found some obstacle alerts in the last hour.");
      _onCommandRecognized?.call("events");
    } catch (e) {
      await speak("Unable to fetch events at the moment. Please try again later.");
    }
  }

  Future<void> _handleProactiveSuggestion() async {
    try {
      // Use smart AI for intelligent suggestions
      final analysis = await _smartAI.analyzeSituation();
      final recommendations = analysis['recommendations'] as List<String>;
      
      String suggestion = "";
      if (recommendations.isNotEmpty) {
        suggestion = "Based on your current situation: ${recommendations.join('. ')}";
      } else {
        suggestion = "Everything looks good! Your device is online and monitoring your surroundings.";
      }
      
      await speak(suggestion);
      _onCommandRecognized?.call("suggestion");
    } catch (e) {
      final hour = DateTime.now().hour;
      String suggestion = hour >= 21 || hour < 6
          ? "It's late. Make sure you're in a safe location."
          : "Everything looks good! Your device is monitoring your surroundings.";
      await speak(suggestion);
      _onCommandRecognized?.call("suggestion");
    }
  }

  /// Handle open app command
  Future<void> _handleOpenAppCommand(String command) async {
    // Extract app name (Hindi + English) - improved pattern matching
    String? appName;
    
    // Remove common prefixes
    String cleanedCommand = command.toLowerCase();
    cleanedCommand = cleanedCommand.replaceAll(RegExp(r'^(open|launch|start|खोलें|चलाएं|खोलो|शुरू)\s+'), '');
    cleanedCommand = cleanedCommand.replaceAll(RegExp(r'\s+(app|application|एप|एप्लिकेशन)$'), '');
    
    // Try to extract app name - can be multiple words
    final appPatterns = [
      RegExp(r'open\s+(.+?)(?:\s+(?:app|application|एप))?$', caseSensitive: false),
      RegExp(r'launch\s+(.+?)(?:\s+(?:app|application|एप))?$', caseSensitive: false),
      RegExp(r'start\s+(.+?)(?:\s+(?:app|application|एप))?$', caseSensitive: false),
      RegExp(r'खोलें\s+(.+?)(?:\s+(?:एप|एप्लिकेशन))?$', caseSensitive: false),
      RegExp(r'चलाएं\s+(.+?)(?:\s+(?:एप|एप्लिकेशन))?$', caseSensitive: false),
      RegExp(r'^(.+?)(?:\s+(?:app|application|एप|एप्लिकेशन))?$', caseSensitive: false),
    ];
    
    for (final pattern in appPatterns) {
      final match = pattern.firstMatch(command);
      if (match != null && match.group(1) != null) {
        appName = match.group(1)?.trim();
        if (appName != null && appName.isNotEmpty) {
          break;
        }
      }
    }
    
    // If still no name, use cleaned command
    appName ??= cleanedCommand.trim();
    
    // Remove common words
    appName = appName.replaceAll(RegExp(r'\s+(the|a|an|को|में|से)\s+', caseSensitive: false), ' ');
    appName = appName.trim();
    
    print('Extracted app name: $appName');
    
    if (appName.isNotEmpty) {
      await speak(_getResponse('opening_app', appName));
      final success = await _phoneControl.openApp(appName);
      if (success) {
        await speak("App opened successfully. एप सफलतापूर्वक खोली गई।");
      } else {
        await speak(_getResponse('app_not_found', appName));
      }
    } else {
      await speak(_getResponse('app_help'));
    }
    _onCommandRecognized?.call("open_app");
  }

  /// Handle open settings command
  Future<void> _handleOpenSettings() async {
    await speak(_getResponse('opening_settings'));
    await _phoneControl.openSettings();
    _onCommandRecognized?.call("settings");
  }

  /// Get response in Hindi or English based on command language
  String _getResponse(String key, [String? param]) {
    // Detect if command contains Hindi characters
    final hasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(key);
    
    // Try to detect language from user preference or default to English
    // For now, support both languages
    final responses = {
      'calling': {'en': 'Calling $param', 'hi': '$param को कॉल कर रहे हैं'},
      'call_failed': {'en': 'Failed to make call', 'hi': 'कॉल करने में विफल'},
      'finding_contact': {'en': 'Finding contact $param', 'hi': '$param का संपर्क ढूंढ रहे हैं'},
      'contact_not_found': {'en': 'Contact $param not found', 'hi': 'संपर्क $param नहीं मिला'},
      'call_help': {'en': 'Please tell me who to call or provide a phone number', 'hi': 'कृपया बताएं किसे कॉल करना है या फोन नंबर दें'},
      'sending_message': {'en': 'Sending message to $param', 'hi': '$param को संदेश भेज रहे हैं'},
      'message_sent': {'en': 'Message sent successfully', 'hi': 'संदेश सफलतापूर्वक भेजा गया'},
      'message_failed': {'en': 'Failed to send message', 'hi': 'संदेश भेजने में विफल'},
      'message_help': {'en': 'Please tell me who to message or provide a phone number', 'hi': 'कृपया बताएं किसे संदेश भेजना है या फोन नंबर दें'},
      'opening_app': {'en': 'Opening $param', 'hi': '$param खोल रहे हैं'},
      'app_not_found': {'en': 'App $param not found', 'hi': 'एप $param नहीं मिली'},
      'app_help': {'en': 'Please tell me which app to open', 'hi': 'कृपया बताएं कौन सी एप खोलनी है'},
      'opening_settings': {'en': 'Opening settings', 'hi': 'सेटिंग्स खोल रहे हैं'},
      'default_message': {'en': 'Message from SAARTHI', 'hi': 'SAARTHI से संदेश'},
    };
    
    final response = responses[key];
    if (response != null) {
      // Return both languages or based on detection
      return hasHindi ? response['hi'] ?? response['en']! : response['en']!;
    }
    return param ?? '';
  }

  Future<void> _handleSmartAIResponse(String command) async {
    try {
      // Use smart AI to generate intelligent response
      final response = await _smartAI.getIntelligentResponse(command);
      await speak(response);
      
      // Record interaction for learning
      _smartAI.recordInteraction(command, response, null);
      
      // Don't call onCommandRecognized for AI responses to prevent loops
      // _onCommandRecognized?.call("ai_response");
    } catch (e) {
      await speak("I didn't understand that. You can ask me about device status, location, or say SOS for emergency help.");
      _onCommandRecognized?.call("unknown");
    }
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return "recently";
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes} minutes ago";
    if (diff.inDays < 1) return "${diff.inHours} hours ago";
    return "${diff.inDays} days ago";
  }

  /// Proactive alerts based on context
  Future<void> checkProactiveAlerts() async {
    final devices = await _deviceService.getUserDevices();
    if (devices.isEmpty) return;
    
    final device = devices.first;
    final isOnline = _deviceService.isDeviceOnline(device.lastSeen);
    
    if (!isOnline && _shouldAlertOffline()) {
      await speak("Alert: Your device has been offline for a while. Please check the connection.");
    }
  }

  bool _shouldAlertOffline() {
    // Only alert if last interaction was more than 5 minutes ago
    if (_lastInteraction == null) return true;
    return DateTime.now().difference(_lastInteraction!) > const Duration(minutes: 5);
  }

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
}

