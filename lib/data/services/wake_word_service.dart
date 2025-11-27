/**
 * SAARTHI Flutter App - Wake Word Service
 * Detects "Saarthi" wake word to activate voice assistant
 */

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

class WakeWordService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  Function()? _onWakeWordDetected;
  Timer? _listeningTimer;
  
  // Wake words in different languages
  final List<String> _wakeWords = [
    'saarthi',
    'सारथी',
    'sarthi',
    'hey saarthi',
    'ok saarthi',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isInitialized = await _stt.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
      onError: (error) {
        // Handle timeout errors gracefully
        if (error.errorMsg.contains('timeout') || 
            error.errorMsg.contains('error_speech_timeout')) {
          // Timeout is normal - just continue listening
          _isListening = false;
          // Restart listening after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (_onWakeWordDetected != null) {
              _listenForWakeWord();
            }
          });
          return;
        }
        print('Wake word detection error: ${error.errorMsg}');
        _isListening = false;
      },
    );
  }

  /// Start continuous listening for wake word
  void startListening({required Function() onWakeWordDetected}) {
    if (!_isInitialized) {
      initialize().then((_) => _startListeningInternal(onWakeWordDetected));
    } else {
      _startListeningInternal(onWakeWordDetected);
    }
  }

  void _startListeningInternal(Function() onWakeWordDetected) {
    if (_isListening) return;
    
    _onWakeWordDetected = onWakeWordDetected;
    _isListening = true;
    
    _listenForWakeWord();
  }

  void _listenForWakeWord() {
    if (!_isListening) return;
    
    _stt.listen(
      onResult: (result) {
        // Check both partial and final results for faster detection
        final text = result.recognizedWords.toLowerCase().trim();
        
        if (text.isNotEmpty) {
          print('Wake word service heard: $text');
          
          // Check if any wake word is detected (case-insensitive, partial match)
          for (final wakeWord in _wakeWords) {
            if (text.contains(wakeWord.toLowerCase()) || 
                text == wakeWord.toLowerCase() ||
                text.startsWith(wakeWord.toLowerCase())) {
              print('Wake word detected: $wakeWord in "$text"');
              _onWakeWordDetected?.call();
              _stopListening();
              // Restart listening after wake word detected
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_onWakeWordDetected != null) {
                  _listenForWakeWord();
                }
              });
              return;
            }
          }
        }
        
        // If final result and no wake word, restart listening
        if (result.finalResult) {
          // Continue listening if no wake word detected
          if (_isListening) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _listenForWakeWord();
            });
          }
        }
      },
      listenFor: const Duration(seconds: 10), // Longer timeout for better detection
      pauseFor: const Duration(seconds: 1), // Shorter pause for faster restart
      partialResults: true, // Enable partial results for faster detection
      cancelOnError: false, // Don't cancel on timeout errors
      listenMode: stt.ListenMode.confirmation, // Better for wake word detection
    );
  }

  void _stopListening() {
    _stt.stop();
    _isListening = false;
    _listeningTimer?.cancel();
  }

  void stopListening() {
    _stopListening();
  }

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
}

