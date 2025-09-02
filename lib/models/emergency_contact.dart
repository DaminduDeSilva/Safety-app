/// Data model representing an emergency contact for a user.
///
/// Emergency contacts are people who should be notified when a user
/// triggers an emergency alert in the safety app.
class EmergencyContact {
  /// Unique identifier for this emergency contact
  final String id;

  /// Full name of the emergency contact
  final String name;

  /// Phone number to contact this person
  final String phoneNumber;

  /// Relationship to the user (e.g., "Parent", "Friend", "Sibling", "Spouse")
  final String relationship;

  /// Whether this is the primary emergency contact
  final bool isPrimary;

  /// Creates a new [EmergencyContact] instance.
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    required this.isPrimary,
  });

  /// Creates an [EmergencyContact] from a Firestore document map.
  ///
  /// The [map] parameter should contain the document data from Firestore.
  /// The [id] parameter is typically the document ID from Firestore.
  factory EmergencyContact.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyContact(
      id: id,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      relationship: map['relationship'] as String,
      isPrimary: map['isPrimary'] as bool? ?? false,
    );
  }

  /// Converts the [EmergencyContact] to a map suitable for Firestore storage.
  ///
  /// Note: The ID is not included in the map as it serves as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'isPrimary': isPrimary,
    };
  }

  /// Creates a copy of this [EmergencyContact] with the given fields replaced.
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact(id: $id, name: $name, phoneNumber: $phoneNumber, relationship: $relationship, isPrimary: $isPrimary)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyContact &&
        other.id == id &&
        other.name == name &&
        other.phoneNumber == phoneNumber &&
        other.relationship == relationship &&
        other.isPrimary == isPrimary;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        phoneNumber.hashCode ^
        relationship.hashCode ^
        isPrimary.hashCode;
  }
}
