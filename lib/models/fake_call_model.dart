class FakeCallConfig {
  final String id;
  final String callerName;
  final String phoneNumber;
  final String ringtone; // Optional: path to custom ringtone
  final Duration delayBeforeCall;
  final bool isEnabled;
  final String? avatarUrl; // Optional caller photo
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FakeCallConfig({
    required this.id,
    required this.callerName,
    required this.phoneNumber,
    this.ringtone = 'default',
    this.delayBeforeCall = const Duration(seconds: 10),
    this.isEnabled = true,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerName': callerName,
      'phoneNumber': phoneNumber,
      'ringtone': ringtone,
      'delayBeforeCall': delayBeforeCall.inSeconds,
      'isEnabled': isEnabled,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  // Create from Map (Firestore data)
  factory FakeCallConfig.fromMap(Map<String, dynamic> map) {
    return FakeCallConfig(
      id: map['id'] ?? '',
      callerName: map['callerName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      ringtone: map['ringtone'] ?? 'default',
      delayBeforeCall: Duration(seconds: map['delayBeforeCall'] ?? 10),
      isEnabled: map['isEnabled'] ?? true,
      avatarUrl: map['avatarUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  // Create a copy with updated fields
  FakeCallConfig copyWith({
    String? id,
    String? callerName,
    String? phoneNumber,
    String? ringtone,
    Duration? delayBeforeCall,
    bool? isEnabled,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FakeCallConfig(
      id: id ?? this.id,
      callerName: callerName ?? this.callerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      ringtone: ringtone ?? this.ringtone,
      delayBeforeCall: delayBeforeCall ?? this.delayBeforeCall,
      isEnabled: isEnabled ?? this.isEnabled,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FakeCallConfig(id: $id, callerName: $callerName, phoneNumber: $phoneNumber, delayBeforeCall: $delayBeforeCall, isEnabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FakeCallConfig &&
        other.id == id &&
        other.callerName == callerName &&
        other.phoneNumber == phoneNumber &&
        other.ringtone == ringtone &&
        other.delayBeforeCall == delayBeforeCall &&
        other.isEnabled == isEnabled &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        callerName.hashCode ^
        phoneNumber.hashCode ^
        ringtone.hashCode ^
        delayBeforeCall.hashCode ^
        isEnabled.hashCode ^
        avatarUrl.hashCode;
  }
}

// Predefined fake call templates
class FakeCallTemplates {
  static final List<FakeCallConfig> defaultTemplates = [
    FakeCallConfig(
      id: 'template_1',
      callerName: 'Mom',
      phoneNumber: '+1 (555) 123-4567',
      delayBeforeCall: const Duration(seconds: 10),
    ),
    FakeCallConfig(
      id: 'template_2',
      callerName: 'Work Emergency',
      phoneNumber: '+1 (555) 987-6543',
      delayBeforeCall: const Duration(seconds: 15),
    ),
    FakeCallConfig(
      id: 'template_3',
      callerName: 'Doctor\'s Office',
      phoneNumber: '+1 (555) 246-8135',
      delayBeforeCall: const Duration(seconds: 20),
    ),
    FakeCallConfig(
      id: 'template_4',
      callerName: 'Roommate',
      phoneNumber: '+1 (555) 369-2580',
      delayBeforeCall: const Duration(seconds: 5),
    ),
  ];
}
