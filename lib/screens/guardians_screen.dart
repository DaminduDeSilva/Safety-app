import 'package:flutter/material.dart';
import '../widgets/live_guardians_section.dart';
import '../widgets/add_guardian_button.dart';
import '../widgets/modern_app_bar.dart';
import 'contacts_screen.dart';
import 'invitation_screen.dart';

/// Screen for managing all guardian-related functionality.
///
/// Combines emergency contacts, invitations, and guardian addition in one
/// organized interface with tab navigation.
class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(
        title: 'My Guardians',
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Modern Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[700],
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'My Guardians'),
                Tab(icon: Icon(Icons.mail_outline), text: 'Invitations'),
                Tab(icon: Icon(Icons.person_add), text: 'Add Guardian'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: My Emergency Contacts with Live Location
                _buildMyGuardiansTab(),

                // Tab 2: Invitations Management
                _buildInvitationsTab(),

                // Tab 3: Add New Guardian
                _buildAddGuardianTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "My Guardians" tab showing live guardians and contacts
  Widget _buildMyGuardiansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Guardians Section
          LiveGuardiansSection(),

          const SizedBox(height: 20),

          // Quick Actions Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ContactsScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.contacts),
                      label: const Text('Manage All Contacts'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "Invitations" tab for managing invitations
  Widget _buildInvitationsTab() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.mail_outline, size: 48, color: Colors.blue[700]),
                  const SizedBox(height: 12),
                  Text(
                    'Invitation Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View and manage your sent and received invitations',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InvitationScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Invitations'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "Add Guardian" tab for adding new guardians
  Widget _buildAddGuardianTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add Guardian Section
          AddGuardianButton(),

          const SizedBox(height: 20),

          // Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About Guardians',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.security,
                    'Emergency Contacts',
                    'Guardians receive your location during emergencies',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.location_on,
                    'Live Location',
                    'See real-time location of guardians who are sharing',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.phone,
                    'Two-Way Protection',
                    'You become each other\'s emergency contacts',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an information row with icon, title, and description
  Widget _buildInfoRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: Colors.blue[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
