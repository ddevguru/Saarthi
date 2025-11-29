/**
 * SAARTHI Flutter App - Voice Assistant Button Widget
 * Floating action button for voice commands
 */

import 'package:flutter/material.dart';
import '../../data/services/voice_assistant_service.dart';
import '../../core/app_theme.dart';

class VoiceAssistantButton extends StatefulWidget {
  final VoiceAssistantService voiceAssistant;
  
  const VoiceAssistantButton({
    super.key,
    required this.voiceAssistant,
  });

  @override
  State<VoiceAssistantButton> createState() => _VoiceAssistantButtonState();
}

class _VoiceAssistantButtonState extends State<VoiceAssistantButton> {
  bool _isListening = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await widget.voiceAssistant.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      // Initialize if not already initialized
      if (!widget.voiceAssistant.isInitialized) {
        await widget.voiceAssistant.initialize();
      }
      
      setState(() {
        _isListening = true;
      });
      
      // Speak acknowledgment and start listening
      await widget.voiceAssistant.speak("Yes, I'm listening. How can I help you?");
      await widget.voiceAssistant.startListening(
        onResult: (command) {
          setState(() {
            _isListening = false;
          });
          // Show feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Command: $command'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _toggleListening,
      backgroundColor: _isListening ? AppTheme.dangerColor : AppTheme.primaryColor,
      child: _isListening
          ? const Icon(Icons.mic, color: Colors.white)
          : const Icon(Icons.mic_none, color: Colors.white),
      tooltip: _isListening ? 'Listening...' : 'Voice Assistant',
    );
  }
}

