/**
 * SAARTHI Flutter App - Device Pairing Screen
 * Generate and display device token for ESP32
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/device_token_service.dart';
import '../../../core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final DeviceTokenService _tokenService = DeviceTokenService();
  final TextEditingController _deviceIdController = TextEditingController();
  String? _deviceToken;
  bool _isGenerating = false;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(AppConstants.prefDeviceId);
    if (deviceId != null) {
      _deviceIdController.text = deviceId;
    } else {
      _deviceIdController.text = 'ESP32_CAM_001'; // Default
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _generateToken() async {
    if (_deviceIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter device ID'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _deviceToken = null;
    });

    try {
      final result = await _tokenService.generateDeviceToken(_deviceIdController.text.trim());
      
      if (result['success'] == true) {
        setState(() {
          _deviceToken = result['device_token'] as String;
        });
        
        // Save device ID
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.prefDeviceId, _deviceIdController.text.trim());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Token generated! ESP32 will auto-fetch on next boot.'),
            backgroundColor: AppTheme.secondaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to generate token'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _copyToken() async {
    if (_deviceToken != null) {
      await Clipboard.setData(ClipboardData(text: _deviceToken!));
      setState(() {
        _isCopied = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Pairing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Device Pairing Instructions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Enter your ESP32 device ID\n'
                      '2. Generate a secure token\n'
                      '3. Copy the token and update it in your ESP32 firmware\n'
                      '4. The device will authenticate automatically',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Device ID Input
            TextFormField(
              controller: _deviceIdController,
              decoration: InputDecoration(
                labelText: 'Device ID',
                hintText: 'ESP32_CAM_001',
                prefixIcon: const Icon(Icons.devices),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Generate Token Button
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateToken,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.vpn_key),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Device Token'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            
            // Token Display
            if (_deviceToken != null) ...[
              Card(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Device Token Generated',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          _deviceToken!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _copyToken,
                        icon: Icon(_isCopied ? Icons.check : Icons.copy),
                        label: Text(_isCopied ? 'Copied!' : 'Copy Token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Auto-Pairing Enabled',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '✓ Token has been saved to backend\n'
                                '✓ ESP32 will automatically fetch this token on next boot\n'
                                '✓ No manual firmware update needed!\n\n'
                                'Just restart your ESP32 device and it will connect automatically.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

