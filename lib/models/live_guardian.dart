import 'emergency_contact.dart';
import 'live_location.dart';

/// Data model representing an emergency contact with their live location status.
///
/// This model combines emergency contact information with real-time location
/// sharing status for the "Live Guardians" section of the home screen.
class LiveGuardian {
  /// The emergency contact information
  final EmergencyContact contact;

  /// Current live location data (null if not sharing)
  final LiveLocation? liveLocation;

  /// Whether this contact is currently sharing their location
  bool get isSharingLocation => liveLocation != null;

  /// How long ago the location was last updated (in a readable format)
  String get lastSeenText {
    if (liveLocation == null) return 'Not sharing location';

    final now = DateTime.now();
    final lastUpdated = liveLocation!.timestamp;
    final difference = now.difference(lastUpdated);

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

  /// Creates a new [LiveGuardian] instance.
  const LiveGuardian({required this.contact, this.liveLocation});

  /// Creates a copy of this [LiveGuardian] with the given fields replaced.
  LiveGuardian copyWith({
    EmergencyContact? contact,
    LiveLocation? liveLocation,
  }) {
    return LiveGuardian(
      contact: contact ?? this.contact,
      liveLocation: liveLocation ?? this.liveLocation,
    );
  }

  @override
  String toString() {
    return 'LiveGuardian(contact: ${contact.name}, isSharingLocation: $isSharingLocation)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveGuardian &&
        other.contact == contact &&
        other.liveLocation == liveLocation;
  }

  @override
  int get hashCode {
    return contact.hashCode ^ liveLocation.hashCode;
  }
}
