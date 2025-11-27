/**
 * SAARTHI Flutter App - WhatsApp Service
 * Sends messages with images and audio to WhatsApp contacts
 */

import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'api_client.dart';
import '../../core/constants.dart';

class WhatsAppService {
  final ApiClient _apiClient = ApiClient();

  /// Send message to WhatsApp contact
  Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
    String? imagePath,
    String? audioPath,
  }) async {
    try {
      // Format phone number (remove +, spaces, etc.)
      String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      // If image or audio provided, upload to backend first
      String? imageUrl;
      String? audioUrl;
      
      if (imagePath != null) {
        imageUrl = await _uploadFile(imagePath, 'image');
      }
      
      if (audioPath != null) {
        audioUrl = await _uploadFile(audioPath, 'audio');
      }
      
      // Use backend WhatsApp API
      final response = await _apiClient.post(
        '/device/sendWhatsApp.php',
        {
          'phone': formattedPhone,
          'message': message,
          'image_url': imageUrl,
          'audio_url': audioUrl,
        },
        requireAuth: true,
      );
      
      if (response['success'] == true) {
        return true;
      }
      
      // Fallback: Try direct WhatsApp URL
      return await _sendViaWhatsAppUrl(formattedPhone, message);
    } catch (e) {
      print('Error sending WhatsApp: $e');
      // Fallback to direct URL
      return await _sendViaWhatsAppUrl(
        phoneNumber.replaceAll(RegExp(r'[^\d]'), ''),
        message,
      );
    }
  }

  Future<String?> _uploadFile(String filePath, String type) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      // TODO: Implement file upload to backend
      // For now, return null and use direct WhatsApp
      return null;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<bool> _sendViaWhatsAppUrl(String phone, String message) async {
    try {
      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      print('Error launching WhatsApp: $e');
      return false;
    }
  }

  /// Get emergency contacts from backend
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    try {
      final response = await _apiClient.get(
        '/user/getEmergencyContacts.php',
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']['contacts'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching emergency contacts: $e');
      return [];
    }
  }
}

