import 'package:flutter/material.dart';
import '../models/live_guardian.dart';
import '../services/database_service.dart';
import '../screens/guardian_location_screen.dart';

/// Widget that displays a list of live guardians (emergency contacts with location sharing status).
///
/// Shows contacts who are sharing their location prominently with a green indicator,
/// and other contacts with a gray indicator. Includes last seen timestamps and
/// tap-to-view functionality.
class LiveGuardiansSection extends StatelessWidget {
  final DatabaseService _databaseService = DatabaseService();

  LiveGuardiansSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveGuardian>>(
      stream: _databaseService.getLiveGuardiansStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading guardians',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Please try again later',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final guardians = snapshot.data ?? [];

        if (guardians.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: Colors.grey, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No Guardians Yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add emergency contacts to see their live locations here',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Live Guardians',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${guardians.length} contact${guardians.length == 1 ? '' : 's'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[300]),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: guardians.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey[200],
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final guardian = guardians[index];
                  return _buildGuardianTile(context, guardian);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds a tile for a single guardian showing their location sharing status.
  Widget _buildGuardianTile(BuildContext context, LiveGuardian guardian) {
    final isSharing = guardian.isSharingLocation;
    final contact = guardian.contact;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      leading: CircleAvatar(
        backgroundColor: isSharing ? Colors.green : Colors.grey[300],
        child: Icon(
          isSharing ? Icons.location_on : Icons.location_off,
          color: isSharing ? Colors.white : Colors.grey[600],
          size: 20,
        ),
      ),
      title: Text(
        contact.name,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.relationship,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                isSharing
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 12,
                color: isSharing ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                guardian.lastSeenText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSharing ? Colors.green[700] : Colors.grey[600],
                  fontWeight: isSharing ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: isSharing
          ? IconButton(
              icon: const Icon(Icons.map, color: Colors.blue),
              tooltip: 'View on map',
              onPressed: () => _viewGuardianLocation(context, guardian),
            )
          : Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: () => _showGuardianDetails(context, guardian),
    );
  }

  /// Shows detailed information about a guardian.
  void _showGuardianDetails(BuildContext context, LiveGuardian guardian) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guardian.contact.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Relationship', guardian.contact.relationship),
            if (guardian.contact.phoneNumber.isNotEmpty)
              _buildDetailRow('Phone', guardian.contact.phoneNumber),
            _buildDetailRow('Location Status', guardian.lastSeenText),
            if (guardian.isSharingLocation &&
                guardian.liveLocation?.address != null)
              _buildDetailRow(
                'Current Location',
                guardian.liveLocation!.address!,
              ),
          ],
        ),
        actions: [
          if (guardian.isSharingLocation)
            TextButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('View on Map'),
              onPressed: () {
                Navigator.of(context).pop();
                _viewGuardianLocation(context, guardian);
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Builds a detail row for the guardian details dialog.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Opens the guardian's location on a map screen.
  void _viewGuardianLocation(BuildContext context, LiveGuardian guardian) {
    if (!guardian.isSharingLocation) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuardianLocationScreen(guardian: guardian),
      ),
    );
  }
}
