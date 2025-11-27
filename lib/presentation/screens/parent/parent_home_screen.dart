/**
 * SAARTHI Flutter App - Parent Home Screen
 * Dashboard showing linked children with alerts and status
 */

import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/api_client.dart';
import 'child_detail_screen.dart';
import 'package:saarthi/l10n/app_localizations.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get(
        '/parent/listChildren.php',
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final children = List<Map<String, dynamic>>.from(data['children'] ?? []);
        
        // Transform data to match UI expectations
        final transformedChildren = children.map((child) {
          DateTime? lastEventTime;
          if (child['last_event_time'] != null) {
            try {
              lastEventTime = DateTime.parse(child['last_event_time'].toString());
            } catch (e) {
              lastEventTime = null;
            }
          }
          
          return {
            'id': child['id'],
            'name': child['name'] ?? 'Unknown',
            'status': (child['device_status'] == 'ONLINE' || child['device_status'] == 'online') ? 'online' : 'offline',
            'device_connected': child['device_status'] == 'ONLINE' || child['device_status'] == 'online',
            'last_alert': child['last_event_type'],
            'last_alert_time': lastEventTime != null ? _formatTimeAgo(lastEventTime) : null,
            'device_name': child['device_name'] ?? null,
            'phone': child['phone'],
            'disability_type': child['disability_type'],
          };
        }).toList();
        
        setState(() {
          _children = transformedChildren;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load children';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.children),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadChildren,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _children.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.child_care, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No children linked',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a child to start monitoring',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChildren,
                      child: ListView.builder(
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (child['device_connected'] == true || child['status'] == 'online')
                          ? AppTheme.secondaryColor
                          : Colors.grey,
                      child: Icon(
                        (child['device_connected'] == true || child['status'] == 'online') ? Icons.check : Icons.close,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      child['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${child['status'] ?? 'unknown'}',
                          style: TextStyle(
                            color: (child['status'] == 'online' || child['device_connected'] == true)
                                ? AppTheme.secondaryColor
                                : Colors.grey,
                          ),
                        ),
                        if (child['last_alert'] != null)
                          Text(
                            'Last: ${child['last_alert']} - ${child['last_alert_time'] ?? ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (child['device_name'] != null)
                          Text(
                            'Device: ${child['device_name']}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChildDetailScreen(
                            childId: child['id'] is int ? child['id'] : int.parse(child['id'].toString()),
                            childName: child['name'] ?? 'Child',
                          ),
                        ),
                      );
                    },
                  ),
                );
                      },
                    ),
                  ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Add child functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add child feature coming soon')),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Child'),
      ),
    );
  }
}

