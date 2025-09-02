/// Data model representing an emergency event triggered by a user.
///
/// Emergency events are created when a user activates the emergency alert
/// feature, capturing their location and other relevant information.
class EmergencyEvent {
  /// Unique identifier for this emergency event
  final String id;

  /// UID of the user who triggered this emergency event
  final String userId;

  /// Latitude coordinate of the emergency location
  final double latitude;

  /// Longitude coordinate of the emergency location
  final double longitude;

  /// Human-readable address of the emergency location
  final String address;

  /// Timestamp when the emergency event was triggered
  final DateTime timestamp;

  /// Whether this emergency event has been resolved
  final bool resolved;

  /// Creates a new [EmergencyEvent] instance.
  const EmergencyEvent({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
    this.resolved = false,
  });

  /// Creates an [EmergencyEvent] from a Firestore document map.
  ///
  /// The [map] parameter should contain the document data from Firestore.
  /// The [id] parameter is typically the document ID from Firestore.
  factory EmergencyEvent.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyEvent(
      id: id,
      userId: map['userId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      resolved: map['resolved'] as bool? ?? false,
    );
  }

  /// Converts the [EmergencyEvent] to a map suitable for Firestore storage.
  ///
  /// Note: The ID is not included in the map as it serves as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'resolved': resolved,
    };
  }

  /// Creates a copy of this [EmergencyEvent] with the given fields replaced.
  EmergencyEvent copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? timestamp,
    bool? resolved,
  }) {
    return EmergencyEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
      resolved: resolved ?? this.resolved,
    );
  }

  @override
  String toString() {
    return 'EmergencyEvent(id: $id, userId: $userId, latitude: $latitude, longitude: $longitude, address: $address, timestamp: $timestamp, resolved: $resolved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyEvent &&
        other.id == id &&
        other.userId == userId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.timestamp == timestamp &&
        other.resolved == resolved;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        address.hashCode ^
        timestamp.hashCode ^
        resolved.hashCode;
  }
}
