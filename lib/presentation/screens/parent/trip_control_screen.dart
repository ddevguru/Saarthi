/**
 * SAARTHI Flutter App - Trip Control Screen
 * Allows parent to create and manage trips/routes for children
 */

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/api_client.dart';
import '../../../core/constants.dart';
import 'package:saarthi/l10n/app_localizations.dart';

class TripControlScreen extends StatefulWidget {
  final int? childId;
  
  const TripControlScreen({super.key, this.childId});

  @override
  State<TripControlScreen> createState() => _TripControlScreenState();
}

class _TripControlScreenState extends State<TripControlScreen> {
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime? _expectedEndTime;
  double? _endLat;
  double? _endLon;
  double? _startLat;
  double? _startLon;
  bool _isLoading = false;
  List<Map<String, dynamic>> _activeTrips = [];
  bool _isLoadingTrips = true;

  @override
  void initState() {
    super.initState();
    _loadActiveTrips();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveTrips() async {
    if (widget.childId == null) return;
    
    setState(() {
      _isLoadingTrips = true;
    });

    try {
      final response = await _apiClient.get(
        '/parent/listTrips.php?child_id=${widget.childId}',
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _activeTrips = List<Map<String, dynamic>>.from(response['data']['trips'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading trips: $e');
    } finally {
      setState(() {
        _isLoadingTrips = false;
      });
    }
  }

  Future<void> _selectDestination() async {
    final destination = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Destination'),
        content: TextField(
          controller: _destinationController,
          decoration: const InputDecoration(
            hintText: 'Enter destination name or address',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_destinationController.text.isNotEmpty) {
                Navigator.pop(context, _destinationController.text);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (destination != null && destination.isNotEmpty) {
      // Geocode destination
      setState(() {
        _isLoading = true;
      });

      try {
        // Use Google Geocoding API or OpenStreetMap Nominatim
        final response = await _apiClient.post(
          '/location/geocode.php',
          {'address': destination},
          requireAuth: true,
        );

        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          setState(() {
            _endLat = double.parse(data['latitude'].toString());
            _endLon = double.parse(data['longitude'].toString());
          });
        } else {
          // Fallback: Use current location + offset (for demo)
          final position = await Geolocator.getCurrentPosition();
          setState(() {
            _endLat = position.latitude + 0.01;
            _endLon = position.longitude + 0.01;
          });
        }
      } catch (e) {
        // Fallback: Use current location + offset
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _endLat = position.latitude + 0.01;
          _endLon = position.longitude + 0.01;
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectExpectedTime() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (selected != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selected.add(const Duration(hours: 1))),
      );

      if (time != null) {
        setState(() {
          _expectedEndTime = DateTime(
            selected.year,
            selected.month,
            selected.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createTrip() async {
    if (widget.childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child ID is required')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter destination')),
      );
      return;
    }

    if (_endLat == null || _endLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select destination location')),
      );
      return;
    }

    if (_expectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expected arrival time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.post(
        AppConstants.createTripEndpoint,
        {
          'child_id': widget.childId,
          'destination_name': _destinationController.text,
          'end_location_lat': _endLat,
          'end_location_lon': _endLon,
          'start_location_lat': _startLat,
          'start_location_lon': _startLon,
          'expected_end_time': _expectedEndTime!.toIso8601String(),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
        },
        requireAuth: true,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Trip created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reset form
          _destinationController.clear();
          _notesController.clear();
          _expectedEndTime = null;
          _endLat = null;
          _endLon = null;
          _startLat = null;
          _startLon = null;
          
          // Reload trips
          _loadActiveTrips();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to create trip'),
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
          title: const Text('Trip Control'),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.add), text: l10n.createTrip),
              Tab(icon: const Icon(Icons.list), text: 'Active Trips'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Create Trip Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Enter destination name or address',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter destination';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _selectDestination,
                      icon: const Icon(Icons.search),
                      label: const Text('Search & Select Location'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_endLat != null && _endLon != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Location: ${_endLat!.toStringAsFixed(6)}, ${_endLon!.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Expected Arrival Time'),
                      subtitle: Text(
                        _expectedEndTime != null
                            ? '${_expectedEndTime!.day}/${_expectedEndTime!.month}/${_expectedEndTime!.year} ${_expectedEndTime!.hour}:${_expectedEndTime!.minute.toString().padLeft(2, '0')}'
                            : 'Not selected',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectExpectedTime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add any additional notes',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createTrip,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              l10n.createTrip,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Active Trips Tab
            _isLoadingTrips
                ? const Center(child: CircularProgressIndicator())
                : _activeTrips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.directions, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No active trips',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadActiveTrips,
                        child: ListView.builder(
                          itemCount: _activeTrips.length,
                          itemBuilder: (context, index) {
                            final trip = _activeTrips[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.secondaryColor,
                                  child: const Icon(Icons.directions, color: Colors.white),
                                ),
                                title: Text(trip['destination_name'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status: ${trip['status'] ?? 'UNKNOWN'}'),
                                    if (trip['expected_end_time'] != null)
                                      Text('Expected: ${trip['expected_end_time']}'),
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

