import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fake_call_model.dart';
import '../services/fake_call_service.dart';
import '../widgets/modern_app_bar.dart';

class FakeCallConfigScreen extends StatefulWidget {
  const FakeCallConfigScreen({super.key});

  @override
  State<FakeCallConfigScreen> createState() => _FakeCallConfigScreenState();
}

class _FakeCallConfigScreenState extends State<FakeCallConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _callerNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  double _delaySeconds = 10.0;
  bool _isEnabled = true;
  List<FakeCallConfig> _savedConfigs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUserAndLoadConfigs();
  }

  Future<void> _checkUserAndLoadConfigs() async {
    // Check if user is authenticated first
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Please sign in to access fake call settings');
      return;
    }

    print('Loading fake call configs for user: ${user.uid}');
    await _loadSavedConfigs();
  }

  @override
  void dispose() {
    _callerNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfigs() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Attempting to load configs for user: ${user.uid}');

        // Try to get documents without ordering first
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fake_call_configs')
            .get();

        print('Successfully retrieved ${querySnapshot.docs.length} configs');

        setState(() {
          _savedConfigs = querySnapshot.docs
              .map((doc) {
                try {
                  return FakeCallConfig.fromMap(doc.data());
                } catch (e) {
                  print('Error parsing config document: $e');
                  return null;
                }
              })
              .where((config) => config != null)
              .cast<FakeCallConfig>()
              .toList();

          // Sort locally by createdAt if available
          _savedConfigs.sort((a, b) {
            final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime); // Descending order
          });
        });

        print('Loaded ${_savedConfigs.length} valid configurations');
      } else {
        setState(() {
          _savedConfigs = [];
        });
        _showErrorSnackBar('User not authenticated');
      }
    } catch (e) {
      print('Error loading configs: $e');
      setState(() {
        _savedConfigs = [];
      });

      // More specific error messages
      String errorMessage = 'Failed to load saved configurations';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Please check your account access.';
      } else if (e.toString().contains('UNAVAILABLE')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final config = FakeCallConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        callerName: _callerNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        delayBeforeCall: Duration(seconds: _delaySeconds.round()),
        isEnabled: _isEnabled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fake_call_configs')
          .doc(config.id)
          .set(config.toMap());

      _showSuccessSnackBar('Configuration saved successfully!');
      _clearForm();
      _loadSavedConfigs();
    } catch (e) {
      print('Error saving config: $e');
      _showErrorSnackBar('Failed to save configuration');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteConfig(FakeCallConfig config) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fake_call_configs')
          .doc(config.id)
          .delete();

      _showSuccessSnackBar('Configuration deleted');
      _loadSavedConfigs();
    } catch (e) {
      print('Error deleting config: $e');
      _showErrorSnackBar('Failed to delete configuration');
    }
  }

  Future<void> _testFakeCall(FakeCallConfig config) async {
    try {
      await FakeCallService.instance.triggerImmediateFakeCall(context, config);
    } catch (e) {
      print('Error testing fake call: $e');
      _showErrorSnackBar('Failed to test fake call');
    }
  }

  void _loadTemplate(FakeCallConfig template) {
    setState(() {
      _callerNameController.text = template.callerName;
      _phoneNumberController.text = template.phoneNumber;
      _delaySeconds = template.delayBeforeCall.inSeconds.toDouble();
      _isEnabled = template.isEnabled;
    });
  }

  void _clearForm() {
    _callerNameController.clear();
    _phoneNumberController.clear();
    setState(() {
      _delaySeconds = 10.0;
      _isEnabled = true;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildConfigForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Fake Call',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Caller Name Field
              TextFormField(
                controller: _callerNameController,
                decoration: const InputDecoration(
                  labelText: 'Caller Name',
                  hintText: 'e.g., Mom, Boss, Doctor',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a caller name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number Field
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g., +1 (555) 123-4567',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Delay Slider
              Text(
                'Delay Before Call: ${_delaySeconds.round()} seconds',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Slider(
                value: _delaySeconds,
                min: 3.0,
                max: 60.0,
                divisions: 57,
                label: '${_delaySeconds.round()}s',
                onChanged: (value) {
                  setState(() {
                    _delaySeconds = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Enable Switch
              SwitchListTile(
                title: const Text('Enable Configuration'),
                subtitle: const Text('Turn on/off this fake call config'),
                value: _isEnabled,
                onChanged: (value) {
                  setState(() {
                    _isEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Configuration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplates() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Templates',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...FakeCallTemplates.defaultTemplates.map(
              (template) => ListTile(
                leading: CircleAvatar(child: Text(template.callerName[0])),
                title: Text(template.callerName),
                subtitle: Text(template.phoneNumber),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _loadTemplate(template),
                ),
                onTap: () => _loadTemplate(template),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedConfigs() {
    if (_savedConfigs.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No saved configurations yet.\nCreate your first fake call configuration above!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Configurations',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._savedConfigs.map(
              (config) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(config.callerName[0])),
                  title: Text(config.callerName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.phoneNumber),
                      Text('Delay: ${config.delayBeforeCall.inSeconds}s'),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'test',
                        child: const Row(
                          children: [
                            Icon(Icons.play_arrow),
                            SizedBox(width: 8),
                            Text('Test Call'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: const Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'test':
                          _testFakeCall(config);
                          break;
                        case 'edit':
                          _loadTemplate(config);
                          break;
                        case 'delete':
                          _deleteConfig(config);
                          break;
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Fake Call Settings'),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildConfigForm(),
                  _buildTemplates(),
                  _buildSavedConfigs(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
