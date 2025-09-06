import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact.dart';
import '../services/database_service.dart';

/// Screen for managing emergency contacts.
///
/// Allows users to view, add, and delete their emergency contacts
/// that will be notified during an emergency.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final DatabaseService _databaseService = DatabaseService();

  /// Requests contacts permission and imports contacts from phone
  Future<void> _importContactsFromPhone() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking contacts permission...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      bool permissionGranted = false;

      // First check current permission status
      try {
        final currentStatus = await Permission.contacts.status;
        print('Current permission status: $currentStatus');

        if (currentStatus == PermissionStatus.granted) {
          permissionGranted = true;
          print('Permission already granted');
        }
      } catch (e) {
        print('Error checking current permission status: $e');
      }

      // If not granted, try to request permission
      if (!permissionGranted) {
        try {
          print('Requesting permission via flutter_contacts...');
          permissionGranted = await FlutterContacts.requestPermission();
          print(
            'FlutterContacts.requestPermission() returned: $permissionGranted',
          );
        } catch (e) {
          print('FlutterContacts.requestPermission() error: $e');
        }

        // Fallback to permission_handler if flutter_contacts failed
        if (!permissionGranted) {
          try {
            print('Requesting permission via permission_handler...');
            final status = await Permission.contacts.request();
            permissionGranted = status == PermissionStatus.granted;
            print('Permission.contacts.request() returned: $status');
          } catch (e) {
            print('Permission.contacts.request() error: $e');
          }
        }
      }

      // Final test: try to actually access contacts to verify permission
      if (!permissionGranted) {
        print('Permission not confirmed, testing by accessing contacts...');
        try {
          final testContacts = await FlutterContacts.getContacts(
            withProperties: false,
          );
          permissionGranted = true;
          print(
            'Permission test successful - can access ${testContacts.length} contacts',
          );
        } catch (e) {
          print('Permission test failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contacts permission denied',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('To import contacts:'),
                    Text('1. Go to Settings > Apps > Safety App'),
                    Text('2. Enable Contacts permission'),
                    Text('3. Return and try again'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () async {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    await openAppSettings();
                  },
                ),
              ),
            );
          }
          return;
        }
      }

      print('Permission granted, proceeding to get contacts...');

      // Get contacts from phone
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No contacts found on your device')),
          );
        }
        return;
      }

      // Filter contacts that have phone numbers
      final List<Contact> contactsWithPhones = contacts
          .where(
            (contact) =>
                contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
          )
          .toList();

      if (contactsWithPhones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No contacts with phone numbers found'),
            ),
          );
        }
        return;
      }

      // Show contact selection dialog
      if (mounted) {
        _showContactSelectionDialog(contactsWithPhones);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows dialog to select contacts to import
  Future<void> _showContactSelectionDialog(List<Contact> contacts) async {
    final List<Contact> selectedContacts = [];

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Contacts to Import'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      '${selectedContacts.length} contact(s) selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final isSelected = selectedContacts.contains(contact);
                          final phoneNumber = contact.phones.first.number;

                          return CheckboxListTile(
                            title: Text(contact.displayName),
                            subtitle: Text(phoneNumber),
                            value: isSelected,
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedContacts.add(contact);
                                } else {
                                  selectedContacts.remove(contact);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedContacts.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _addSelectedContacts(selectedContacts);
                        },
                  child: const Text('Import Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Adds selected contacts to emergency contacts
  Future<void> _addSelectedContacts(List<Contact> selectedContacts) async {
    int successCount = 0;
    int errorCount = 0;

    for (final contact in selectedContacts) {
      try {
        final phoneNumber = contact.phones.first.number;
        final name = contact.displayName;

        // Clean phone number (remove spaces, dashes, parentheses)
        final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

        if (cleanedPhone.isEmpty) {
          errorCount++;
          continue;
        }

        final emergencyContact = EmergencyContact(
          id: '', // Will be auto-generated by Firestore
          name: name,
          phoneNumber: cleanedPhone,
          relationship: 'Imported Contact', // Default relationship
          isPrimary: false, // Imported contacts are not primary by default
        );

        await _databaseService.addEmergencyContact(emergencyContact);
        successCount++;
      } catch (e) {
        errorCount++;
      }
    }

    // Show result
    if (mounted) {
      String message;
      Color backgroundColor;

      if (errorCount == 0) {
        message = 'Successfully imported $successCount contact(s)';
        backgroundColor = Colors.green;
      } else if (successCount == 0) {
        message = 'Failed to import any contacts';
        backgroundColor = Colors.red;
      } else {
        message = 'Imported $successCount contact(s), $errorCount failed';
        backgroundColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    }
  }

  /// Shows the add contact dialog
  Future<void> _showAddContactDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g., John Doe',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g., +1 (555) 123-4567',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9+\-\(\)\s]'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a phone number';
                      }
                      // Basic phone number validation
                      final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
                      if (cleanPhone.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: relationshipController,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      hintText: 'e.g., Parent, Friend, Sibling',
                      prefixIcon: Icon(Icons.family_restroom),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your relationship';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final contact = EmergencyContact(
                      id: '', // Will be set by Firestore
                      name: nameController.text.trim(),
                      phoneNumber: phoneController.text.trim(),
                      relationship: relationshipController.text.trim(),
                      isPrimary: false, // Can be modified later if needed
                    );

                    await _databaseService.addEmergencyContact(contact);

                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${contact.name} added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to add contact: ${e.toString()}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Shows confirmation dialog before deleting a contact
  Future<void> _showDeleteConfirmation(EmergencyContact contact) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Contact'),
          content: Text('Are you sure you want to delete ${contact.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _databaseService.deleteEmergencyContact(contact.id);

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${contact.name} deleted successfully!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete contact: ${e.toString()}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds a contact list item
  Widget _buildContactTile(EmergencyContact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact.phoneNumber,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              contact.relationship,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _showDeleteConfirmation(contact),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Contact',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _importContactsFromPhone,
            icon: const Icon(Icons.contact_phone),
            tooltip: 'Import from Phone',
          ),
          IconButton(
            onPressed: _showAddContactDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add Contact',
          ),
        ],
      ),
      body: StreamBuilder<List<EmergencyContact>>(
        stream: _databaseService.getEmergencyContactsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading contacts',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contacts, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No Emergency Contacts',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add contacts who should be notified during emergencies.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddContactDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Contact'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These contacts will receive SMS alerts when you use the SOS button.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    return _buildContactTile(contacts[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
