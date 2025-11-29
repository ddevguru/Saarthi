/**
 * SAARTHI Flutter App - Phone Control Service
 * Full phone control via voice commands (calls, messages, apps, settings)
 */

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PhoneControlService {

  /// Make a phone call
  Future<bool?> makeCall(String phoneNumber) async {
    try {
      // Remove any non-digit characters
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      if (Platform.isAndroid) {
        // Use direct caller for Android
        final result = await FlutterPhoneDirectCaller.callNumber(cleanNumber);
        return result ?? false;
      } else {
        // Use tel: URL for iOS
        final uri = Uri.parse('tel:$cleanNumber');
        return await launchUrl(uri);
      }
    } catch (e) {
      print('Error making call: $e');
      return false;
    }
  }

  /// Send SMS
  Future<bool> sendSMS(String phoneNumber, String message) async {
    try {
      // Clean phone number - keep only digits and +
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Remove + if present for sms: URI (Android doesn't always handle + well)
      if (cleanNumber.startsWith('+')) {
        cleanNumber = cleanNumber.substring(1);
      }
      
      print('Sending SMS to: $cleanNumber, Message: $message');
      
      // Use sms: URL scheme for both Android and iOS
      final uri = Uri.parse('sms:$cleanNumber?body=${Uri.encodeComponent(message)}');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (launched) {
        print('SMS app opened successfully');
        return true;
      } else {
        print('Failed to open SMS app');
        return false;
      }
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Find contact by name
  Future<Contact?> findContact(String name) async {
    try {
      // Request permission first
      final permission = await FlutterContacts.requestPermission();
      if (!permission) {
        print('Contacts permission denied');
        return null;
      }
      
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      
      print('Searching for contact: $name (Total contacts: ${contacts.length})');
      
      // Search for contact by name (case insensitive, partial match)
      final nameLower = name.toLowerCase().trim();
      final nameWords = nameLower.split(RegExp(r'\s+'));
      
      for (final contact in contacts) {
        final displayName = contact.displayName.toLowerCase();
        final firstName = contact.name.first.toLowerCase();
        final lastName = contact.name.last.toLowerCase();
        final fullName = '$firstName $lastName'.trim().toLowerCase();
        
        // Exact match
        if (displayName == nameLower || fullName == nameLower) {
          print('Found exact match: ${contact.displayName}');
          return contact;
        }
        
        // Partial match - check if all words in name are present
        bool allWordsMatch = true;
        for (final word in nameWords) {
          if (word.isEmpty) continue;
          if (!displayName.contains(word) && 
              !firstName.contains(word) && 
              !lastName.contains(word)) {
            allWordsMatch = false;
            break;
          }
        }
        
        if (allWordsMatch) {
          print('Found partial match: ${contact.displayName}');
          return contact;
        }
        
        // Also check if name contains any part of contact name
        if (displayName.contains(nameLower) ||
            firstName.contains(nameLower) ||
            lastName.contains(nameLower) ||
            fullName.contains(nameLower)) {
          print('Found substring match: ${contact.displayName}');
          return contact;
        }
      }
      
      print('Contact not found: $name');
      return null;
    } catch (e) {
      print('Error finding contact: $e');
      return null;
    }
  }

  /// Get phone number from contact name
  Future<String?> getPhoneNumberFromContact(String contactName) async {
    try {
      final contact = await findContact(contactName);
      if (contact != null && contact.phones.isNotEmpty) {
        // Get first phone number and clean it
        String phone = contact.phones.first.number;
        // Remove spaces, dashes, parentheses, and other non-digit characters except +
        phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
        // Ensure it starts with country code if needed (for India, add +91 if missing)
        if (phone.length == 10 && !phone.startsWith('+')) {
          phone = '+91$phone';
        }
        print('Extracted phone number: $phone');
        return phone;
      }
      print('Contact found but no phone number available');
      return null;
    } catch (e) {
      print('Error getting phone number from contact: $e');
      return null;
    }
  }

  /// Open app by package name or name
  Future<bool> openApp(String appName) async {
    try {
      if (Platform.isAndroid) {
        // Extended app mappings with package names and intents
        final appMap = {
          // Social Media
          'whatsapp': {'package': 'com.whatsapp', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'facebook': {'package': 'com.facebook.katana', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'instagram': {'package': 'com.instagram.android', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'youtube': {'package': 'com.google.android.youtube', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'twitter': {'package': 'com.twitter.android', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'telegram': {'package': 'org.telegram.messenger', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          
          // Google Apps
          'gmail': {'package': 'com.google.android.gm', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'maps': {'package': 'com.google.android.apps.maps', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'google': {'package': 'com.google.android.googlequicksearchbox', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'chrome': {'package': 'com.android.chrome', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'drive': {'package': 'com.google.android.apps.docs', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'photos': {'package': 'com.google.android.apps.photos', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          
          // System Apps
          'camera': {'package': 'com.android.camera2', 'intent': 'android.media.action.IMAGE_CAPTURE'},
          'gallery': {'package': 'com.android.gallery3d', 'intent': 'android.intent.action.VIEW'},
          'settings': {'package': 'com.android.settings', 'intent': 'android.settings.SETTINGS'},
          'calculator': {'package': 'com.android.calculator2', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'clock': {'package': 'com.android.deskclock', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'calendar': {'package': 'com.google.android.calendar', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'phone': {'package': 'com.android.dialer', 'intent': 'android.intent.action.DIAL'},
          'messages': {'package': 'com.android.mms', 'intent': 'android.intent.action.VIEW'},
          'contacts': {'package': 'com.android.contacts', 'intent': 'android.intent.action.VIEW'},
          'file': {'package': 'com.android.documentsui', 'intent': 'android.intent.action.VIEW'},
          
          // Music & Media
          'music': {'package': 'com.android.music', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'spotify': {'package': 'com.spotify.music', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'player': {'package': 'com.android.music', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          
          // Shopping
          'amazon': {'package': 'in.amazon.mShop.android.shopping', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'flipkart': {'package': 'com.flipkart.android', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          
          // Payment
          'paytm': {'package': 'net.one97.paytm', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'gpay': {'package': 'com.google.android.apps.nfc.payment', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
          'phonepe': {'package': 'com.phonepe.app', 'intent': 'android.intent.action.MAIN', 'category': 'android.intent.category.LAUNCHER'},
        };

        final appNameLower = appName.toLowerCase().trim();
        final appInfo = appMap[appNameLower];
        
        if (appInfo != null) {
          final package = appInfo['package']!;
          final intent = appInfo['intent']!;
          final category = appInfo['category'];
          
          // Try to launch using package name with proper Android intent
          try {
            String intentUri;
            if (category != null) {
              intentUri = 'intent://#Intent;action=$intent;category=$category;package=$package;end';
            } else {
              intentUri = 'intent://#Intent;action=$intent;package=$package;end';
            }
            
            final uri = Uri.parse(intentUri);
            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            
            if (launched) {
              print('Successfully launched app: $package');
              return true;
            }
          } catch (e) {
            print('Error launching app with intent: $e');
            // Fallback 1: Try with component
            try {
              String intentUri;
              if (category != null) {
                intentUri = 'intent://#Intent;action=$intent;category=$category;component=$package/.MainActivity;end';
              } else {
                intentUri = 'intent://#Intent;action=$intent;component=$package/.MainActivity;end';
              }
              final uri = Uri.parse(intentUri);
              return await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e2) {
              print('Error launching app with component: $e2');
              // Fallback 2: Try package name only
              try {
                final uri = Uri.parse('package:$package');
                return await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e3) {
                print('Error launching app with package: $e3');
              }
            }
          }
        }
        
        // If not found in map, try common URL schemes as fallback
        final urlSchemes = {
          'whatsapp': 'whatsapp://',
          'youtube': 'vnd.youtube://',
          'facebook': 'fb://',
          'instagram': 'instagram://',
          'maps': 'geo:0,0?q=',
        };
        
        if (urlSchemes.containsKey(appNameLower)) {
          final uri = Uri.parse(urlSchemes[appNameLower]!);
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      
      return false;
    } catch (e) {
      print('Error opening app: $e');
      return false;
    }
  }

  /// Open WhatsApp with contact
  Future<bool> openWhatsApp(String phoneNumber) async {
    try {
      // Clean phone number - remove + and spaces
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      // Remove country code if present (for India, remove 91)
      if (cleanNumber.length == 12 && cleanNumber.startsWith('91')) {
        cleanNumber = cleanNumber.substring(2);
      }
      
      // WhatsApp URL format: whatsapp://send?phone=919876543210
      final uri = Uri.parse('whatsapp://send?phone=$cleanNumber');
      
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          print('WhatsApp opened successfully for $cleanNumber');
          return true;
        }
      } catch (e) {
        print('WhatsApp not installed or error: $e');
        // Fallback: Try opening WhatsApp web or play store
        try {
          final webUri = Uri.parse('https://wa.me/$cleanNumber');
          return await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } catch (e2) {
          print('Failed to open WhatsApp web: $e2');
        }
      }
      
      return false;
    } catch (e) {
      print('Error opening WhatsApp: $e');
      return false;
    }
  }

  /// Open settings
  Future<bool> openSettings() async {
    try {
      if (Platform.isAndroid) {
        final uri = Uri.parse('package:com.android.settings');
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Request permissions
  Future<bool> requestPermissions() async {
    try {
      // Request contacts permission using flutter_contacts
      final contactsPermission = await FlutterContacts.requestPermission();
      
      // Request phone and SMS permissions
      final statuses = await [
        Permission.phone,
        Permission.sms,
      ].request();
      
      return contactsPermission ||
             statuses[Permission.phone]?.isGranted == true ||
             statuses[Permission.sms]?.isGranted == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      // Check contacts permission
      final contactsPermission = await FlutterContacts.requestPermission(readonly: true);
      
      // Check phone and SMS permissions
      final phone = await Permission.phone.status;
      final sms = await Permission.sms.status;
      
      return contactsPermission || phone.isGranted || sms.isGranted;
    } catch (e) {
      return false;
    }
  }
}

