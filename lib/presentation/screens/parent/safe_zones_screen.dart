/**
 * SAARTHI Flutter App - Safe Zones Screen
 * Allows parent to create and manage safe zones for children
 */

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/api_client.dart';
import '../../../core/constants.dart';
import 'package:saarthi/l10n/app_localizations.dart';

class SafeZonesScreen extends StatefulWidget {
  final int? childId;
  
  const SafeZonesScreen({super.key, this.childId});

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  
  double? _centerLat;
  double? _centerLon;
  bool _isRestricted = false;
  TimeOfDay? _activeStartTime;
  TimeOfDay? _activeEndTime;
  bool _isLoading = false;
  List<Map<String, dynamic>> _safeZones = [];
  bool _isLoadingZones = true;

  @override
  void initState() {
    super.initState();
    _loadSafeZones();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadSafeZones() async {
    if (widget.childId == null) return;
    
    setState(() {
      _isLoadingZones = true;
    });

    try {
      final response = await _apiClient.get(
        '/parent/listSafeZones.php?child_id=${widget.childId}',
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _safeZones = List<Map<String, dynamic>>.from(response['data']['safe_zones'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading safe zones: $e');
    } finally {
      setState(() {
        _isLoadingZones = false;
      });
    }
  }

  Future<void> _selectLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _centerLat = position.latitude;
        _centerLon = position.longitude;
      });
      
      // Show dialog to confirm or adjust location
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Selected'),
            content: Text(
              'Latitude: ${_centerLat!.toStringAsFixed(6)}\n'
              'Longitude: ${_centerLon!.toStringAsFixed(6)}\n\n'
              'Use this location as the center of the safe zone?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) {
          setState(() {
            _centerLat = null;
            _centerLon = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectActiveTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart 
          ? (_activeStartTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_activeEndTime ?? const TimeOfDay(hour: 20, minute: 0)),
    );

    if (selected != null) {
      setState(() {
        if (isStart) {
          _activeStartTime = selected;
        } else {
          _activeEndTime = selected;
        }
      });
    }
  }

  Future<void> _createSafeZone() async {
    if (widget.childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child ID is required')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter safe zone name')),
      );
      return;
    }

    if (_centerLat == null || _centerLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select location')),
      );
      return;
    }

    final radius = int.tryParse(_radiusController.text);
    if (radius == null || radius < 10 || radius > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius must be between 10 and 10000 meters')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.post(
        AppConstants.createSafeZoneEndpoint,
        {
          'child_id': widget.childId,
          'name': _nameController.text,
          'center_lat': _centerLat,
          'center_lon': _centerLon,
          'radius_meters': radius,
          'is_restricted': _isRestricted,
          'active_start_time': _activeStartTime != null
              ? '${_activeStartTime!.hour.toString().padLeft(2, '0')}:${_activeStartTime!.minute.toString().padLeft(2, '0')}:00'
              : null,
          'active_end_time': _activeEndTime != null
              ? '${_activeEndTime!.hour.toString().padLeft(2, '0')}:${_activeEndTime!.minute.toString().padLeft(2, '0')}:00'
              : null,
        },
        requireAuth: true,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Safe zone created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reset form
          _nameController.clear();
          _radiusController.text = '100';
          _centerLat = null;
          _centerLon = null;
          _isRestricted = false;
          _activeStartTime = null;
          _activeEndTime = null;
          
          // Reload safe zones
          _loadSafeZones();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to create safe zone'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Safe Zones'),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.add), text: 'Create Zone'),
              Tab(icon: const Icon(Icons.list), text: 'Active Zones'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Create Safe Zone Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Zone Name',
                        hintText: 'Home, School, Office, etc.',
                        prefixIcon: const Icon(Icons.label),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter zone name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _selectLocation,
                      icon: const Icon(Icons.location_on),
                      label: const Text('Select Center Location'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_centerLat != null && _centerLon != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Location: ${_centerLat!.toStringAsFixed(6)}, ${_centerLon!.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _radiusController,
                      decoration: InputDecoration(
                        labelText: 'Radius (meters)',
                        hintText: '100',
                        prefixIcon: const Icon(Icons.radio_button_unchecked),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter radius';
                        }
                        final radius = int.tryParse(value);
                        if (radius == null || radius < 10 || radius > 10000) {
                          return 'Radius must be between 10 and 10000 meters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Restricted Zone'),
                      subtitle: const Text('Alert when entering (true) or exiting (false)'),
                      value: _isRestricted,
                      onChanged: (value) {
                        setState(() {
                          _isRestricted = value;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Active Start Time (Optional)'),
                      subtitle: Text(
                        _activeStartTime != null
                            ? '${_activeStartTime!.hour.toString().padLeft(2, '0')}:${_activeStartTime!.minute.toString().padLeft(2, '0')}'
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectActiveTime(true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Active End Time (Optional)'),
                      subtitle: Text(
                        _activeEndTime != null
                            ? '${_activeEndTime!.hour.toString().padLeft(2, '0')}:${_activeEndTime!.minute.toString().padLeft(2, '0')}'
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectActiveTime(false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createSafeZone,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Create Safe Zone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Active Safe Zones Tab
            _isLoadingZones
                ? const Center(child: CircularProgressIndicator())
                : _safeZones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No safe zones',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSafeZones,
                        child: ListView.builder(
                          itemCount: _safeZones.length,
                          itemBuilder: (context, index) {
                            final zone = _safeZones[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: zone['is_restricted'] == 1 
                                      ? Colors.red 
                                      : AppTheme.secondaryColor,
                                  child: Icon(
                                    zone['is_restricted'] == 1 
                                        ? Icons.warning 
                                        : Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(zone['name'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Radius: ${zone['radius_meters']} meters'),
                                    Text(
                                      'Center: ${zone['center_lat']?.toStringAsFixed(4)}, ${zone['center_lon']?.toStringAsFixed(4)}',
                                    ),
                                    if (zone['active_start_time'] != null && zone['active_end_time'] != null)
                                      Text(
                                        'Active: ${zone['active_start_time']} - ${zone['active_end_time']}',
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}

