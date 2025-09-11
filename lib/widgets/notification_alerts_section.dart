import 'package:flutter/material.dart';
import '../models/realtime_notification.dart';
import '../services/realtime_notification_service.dart';

/// Widget that displays real-time notifications as alerts on the home screen
///
/// This widget shows a stream of notifications from the Firebase Realtime Database
/// and displays them as expandable cards with emergency information.
class NotificationAlertsSection extends StatelessWidget {
  final RealtimeNotificationService _notificationService =
      RealtimeNotificationService();

  NotificationAlertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RealtimeNotification>>(
      stream: _notificationService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error loading notifications',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        // Only show unread notifications from the last 24 hours
        final recentNotifications = notifications.where((notification) {
          final isRecent =
              DateTime.now().difference(notification.timestamp).inHours < 24;
          return !notification.isRead && isRecent;
        }).toList();

        if (recentNotifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              '🚨 Emergency Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            ...recentNotifications
                .map(
                  (notification) =>
                      _buildNotificationCard(context, notification),
                )
                .toList(),
          ],
        );
      },
    );
  }

  /// Builds an individual notification card
  Widget _buildNotificationCard(
    BuildContext context,
    RealtimeNotification notification,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: notification.type == 'emergency'
          ? Colors.red.shade50
          : Colors.blue.shade50,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: notification.type == 'emergency'
              ? Colors.red
              : Colors.blue,
          child: Icon(
            notification.type == 'emergency'
                ? Icons.emergency
                : Icons.notifications,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification.senderName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(notification.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Full Message:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.message,
                  style: const TextStyle(fontSize: 14),
                ),
                if (notification.metadata != null) ...[
                  const SizedBox(height: 16),
                  _buildMetadataSection(context, notification.metadata!),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Received: ${_formatTimestamp(notification.timestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _markAsRead(notification),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 32),
                      ),
                      child: const Text('Mark Read'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds metadata section with location and additional info
  Widget _buildMetadataSection(
    BuildContext context,
    Map<String, dynamic> metadata,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metadata['address'] != null) ...[
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Location: ${metadata['address']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (metadata['latitude'] != null &&
              metadata['longitude'] != null) ...[
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Coordinates: ${metadata['latitude']}, ${metadata['longitude']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (metadata['mapUrl'] != null) ...[
            ElevatedButton.icon(
              onPressed: () => _openMap(metadata['mapUrl']),
              icon: const Icon(Icons.map, size: 16),
              label: const Text('View on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 32),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Format time ago in a readable format
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Format full timestamp
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Mark notification as read
  Future<void> _markAsRead(RealtimeNotification notification) async {
    try {
      await _notificationService.markAsRead(notification.senderId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Open map with the provided URL
  Future<void> _openMap(String mapUrl) async {
    try {
      // This would typically use url_launcher
      debugPrint('Opening map: $mapUrl');
      // await launchUrl(Uri.parse(mapUrl));
    } catch (e) {
      debugPrint('Error opening map: $e');
    }
  }
}
