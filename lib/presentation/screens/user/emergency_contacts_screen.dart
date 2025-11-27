/**
 * SAARTHI Flutter App - Emergency Contacts Screen
 * Manage emergency contacts for SOS alerts
 */

import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../data/services/api_client.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get(
        '/user/getEmergencyContacts.php',
        requireAuth: true,
      );
      if (response['success'] == true) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditContact([Map<String, dynamic>? contact]) async {
    final nameController = TextEditingController(text: contact?['name'] ?? '');
    final phoneController = TextEditingController(text: contact?['phone'] ?? '');
    final relationshipController = TextEditingController(text: contact?['relationship'] ?? 'Friend');
    bool isPrimary = contact?['is_primary'] == 1 || contact?['is_primary'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact == null ? 'Add Emergency Contact' : 'Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              CheckboxListTile(
                title: const Text('Primary Contact'),
                value: isPrimary,
                onChanged: (value) => isPrimary = value ?? false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _apiClient.post(
          '/user/saveEmergencyContact.php',
          {
            if (contact != null) 'id': contact['id'],
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'relationship': relationshipController.text.trim(),
            'is_primary': isPrimary,
          },
          requireAuth: true,
        );
        _loadContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(contact == null ? 'Contact added' : 'Contact updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteContact(int contactId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to delete this contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiClient.post(
          '/user/deleteEmergencyContact.php',
          {'id': contactId},
          requireAuth: true,
        );
        _loadContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.contacts, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No emergency contacts yet'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _addOrEditContact(),
                        child: const Text('Add Contact'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: contact['is_primary'] == 1 || contact['is_primary'] == true
                            ? AppTheme.primaryColor
                            : Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(contact['name'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact['phone'] ?? ''),
                          if (contact['relationship'] != null)
                            Text(contact['relationship'], style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            if (contact['is_primary'] == 1 || contact['is_primary'] == true)
                            Chip(
                              label: const Text('Primary', style: TextStyle(fontSize: 10)),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _addOrEditContact(contact),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteContact(contact['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditContact(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}

