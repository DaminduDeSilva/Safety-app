import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Emergency Contact model with location tracking and availability status
class EnhancedEmergencyContact {
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

  /// Last known location of this contact (if they have the app)
  final ContactLocation? lastKnownLocation;

  /// Activity score based on recent interactions and locations
  final double activityScore;

  /// Geographic proximity score to the user
  final double proximityScore;

  /// Virtual closeness score based on frequent locations and time spent together
  final double virtualClosenessScore;

  /// Overall priority score calculated from all factors
  final double priorityScore;

  /// Last time this contact was active in the app
  final DateTime? lastActiveTime;

  /// FCM token for push notifications (if they have the app)
  final String? fcmToken;

  /// Whether this contact has the safety app installed
  final bool hasApp;

  /// Current availability status
  final ContactAvailability availability;

  /// Recent locations visited by this contact
  final List<LocationData> recentLocations;

  /// Time zones where this contact spends most time
  final List<String> frequentTimeZones;

  const EnhancedEmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    required this.isPrimary,
    this.lastKnownLocation,
    this.activityScore = 0.0,
    this.proximityScore = 0.0,
    this.virtualClosenessScore = 0.0,
    this.priorityScore = 0.0,
    this.lastActiveTime,
    this.fcmToken,
    this.hasApp = false,
    this.availability = ContactAvailability.unknown,
    this.recentLocations = const [],
    this.frequentTimeZones = const [],
  });

  factory EnhancedEmergencyContact.fromMap(Map<String, dynamic> map, String id) {
    return EnhancedEmergencyContact(
      id: id,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      relationship: map['relationship'] as String,
      isPrimary: map['isPrimary'] as bool? ?? false,
      lastKnownLocation: map['lastKnownLocation'] != null
          ? ContactLocation.fromMap(map['lastKnownLocation'])
          : null,
      activityScore: (map['activityScore'] as num?)?.toDouble() ?? 0.0,
      proximityScore: (map['proximityScore'] as num?)?.toDouble() ?? 0.0,
      virtualClosenessScore: (map['virtualClosenessScore'] as num?)?.toDouble() ?? 0.0,
      priorityScore: (map['priorityScore'] as num?)?.toDouble() ?? 0.0,
      lastActiveTime: map['lastActiveTime'] != null
          ? (map['lastActiveTime'] as Timestamp).toDate()
          : null,
      fcmToken: map['fcmToken'] as String?,
      hasApp: map['hasApp'] as bool? ?? false,
      availability: ContactAvailability.values.firstWhere(
        (e) => e.toString() == 'ContactAvailability.${map['availability']}',
        orElse: () => ContactAvailability.unknown,
      ),
      recentLocations: (map['recentLocations'] as List<dynamic>?)
              ?.map((e) => LocationData.fromMap(e))
              .toList() ??
          [],
      frequentTimeZones: (map['frequentTimeZones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'lastKnownLocation': lastKnownLocation?.toMap(),
      'activityScore': activityScore,
      'proximityScore': proximityScore,
      'virtualClosenessScore': virtualClosenessScore,
      'priorityScore': priorityScore,
      'lastActiveTime': lastActiveTime != null ? Timestamp.fromDate(lastActiveTime!) : null,
      'fcmToken': fcmToken,
      'hasApp': hasApp,
      'availability': availability.toString().split('.').last,
      'recentLocations': recentLocations.map((e) => e.toMap()).toList(),
      'frequentTimeZones': frequentTimeZones,
    };
  }

  EnhancedEmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
    ContactLocation? lastKnownLocation,
    double? activityScore,
    double? proximityScore,
    double? virtualClosenessScore,
    double? priorityScore,
    DateTime? lastActiveTime,
    String? fcmToken,
    bool? hasApp,
    ContactAvailability? availability,
    List<LocationData>? recentLocations,
    List<String>? frequentTimeZones,
  }) {
    return EnhancedEmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      activityScore: activityScore ?? this.activityScore,
      proximityScore: proximityScore ?? this.proximityScore,
      virtualClosenessScore: virtualClosenessScore ?? this.virtualClosenessScore,
      priorityScore: priorityScore ?? this.priorityScore,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      fcmToken: fcmToken ?? this.fcmToken,
      hasApp: hasApp ?? this.hasApp,
      availability: availability ?? this.availability,
      recentLocations: recentLocations ?? this.recentLocations,
      frequentTimeZones: frequentTimeZones ?? this.frequentTimeZones,
    );
  }
}

/// Contact's location information
class ContactLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime timestamp;
  final double accuracy;

  const ContactLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.timestamp,
    this.accuracy = 0.0,
  });

  factory ContactLocation.fromMap(Map<String, dynamic> map) {
    return ContactLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': Timestamp.fromDate(timestamp),
      'accuracy': accuracy,
    };
  }
}

/// Historical location data for analysis
class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime timestamp;
  final Duration timeSpent;
  final String? placeType; // 'home', 'work', 'shopping', etc.

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.timestamp,
    this.timeSpent = Duration.zero,
    this.placeType,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      timeSpent: Duration(milliseconds: map['timeSpentMs'] as int? ?? 0),
      placeType: map['placeType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': Timestamp.fromDate(timestamp),
      'timeSpentMs': timeSpent.inMilliseconds,
      'placeType': placeType,
    };
  }
}

/// Contact availability status
enum ContactAvailability {
  /// Contact is currently active and likely to respond
  active,
  
  /// Contact was recently active (within last hour)
  recentlyActive,
  
  /// Contact is in a typical active time zone but hasn't been seen recently
  likelyAvailable,
  
  /// Contact might be sleeping or in a different timezone
  possiblyUnavailable,
  
  /// Contact is likely unavailable (sleeping hours, different timezone)
  unavailable,
  
  /// Unable to determine availability
  unknown,
}

/// Emergency notification request and response tracking
class EmergencyNotification {
  final String id;
  final String emergencyId;
  final String contactId;
  final String contactName;
  final String contactPhone;
  final String message;
  final DateTime sentAt;
  final NotificationStatus status;
  final DateTime? respondedAt;
  final ContactResponse? response;
  final int retryCount;
  final DateTime? nextRetryAt;
  final NotificationMethod method;
  final double priorityScore;

  const EmergencyNotification({
    required this.id,
    required this.emergencyId,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.message,
    required this.sentAt,
    this.status = NotificationStatus.sent,
    this.respondedAt,
    this.response,
    this.retryCount = 0,
    this.nextRetryAt,
    this.method = NotificationMethod.pushNotification,
    this.priorityScore = 0.0,
  });

  factory EmergencyNotification.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyNotification(
      id: id,
      emergencyId: map['emergencyId'] as String,
      contactId: map['contactId'] as String,
      contactName: map['contactName'] as String,
      contactPhone: map['contactPhone'] as String,
      message: map['message'] as String,
      sentAt: (map['sentAt'] as Timestamp).toDate(),
      status: NotificationStatus.values.firstWhere(
        (e) => e.toString() == 'NotificationStatus.${map['status']}',
        orElse: () => NotificationStatus.sent,
      ),
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
      response: map['response'] != null
          ? ContactResponse.values.firstWhere(
              (e) => e.toString() == 'ContactResponse.${map['response']}',
              orElse: () => ContactResponse.noResponse,
            )
          : null,
      retryCount: map['retryCount'] as int? ?? 0,
      nextRetryAt: map['nextRetryAt'] != null
          ? (map['nextRetryAt'] as Timestamp).toDate()
          : null,
      method: NotificationMethod.values.firstWhere(
        (e) => e.toString() == 'NotificationMethod.${map['method']}',
        orElse: () => NotificationMethod.pushNotification,
      ),
      priorityScore: (map['priorityScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emergencyId': emergencyId,
      'contactId': contactId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'message': message,
      'sentAt': Timestamp.fromDate(sentAt),
      'status': status.toString().split('.').last,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'response': response?.toString().split('.').last,
      'retryCount': retryCount,
      'nextRetryAt': nextRetryAt != null ? Timestamp.fromDate(nextRetryAt!) : null,
      'method': method.toString().split('.').last,
      'priorityScore': priorityScore,
    };
  }

  EmergencyNotification copyWith({
    String? id,
    String? emergencyId,
    String? contactId,
    String? contactName,
    String? contactPhone,
    String? message,
    DateTime? sentAt,
    NotificationStatus? status,
    DateTime? respondedAt,
    ContactResponse? response,
    int? retryCount,
    DateTime? nextRetryAt,
    NotificationMethod? method,
    double? priorityScore,
  }) {
    return EmergencyNotification(
      id: id ?? this.id,
      emergencyId: emergencyId ?? this.emergencyId,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      response: response ?? this.response,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      method: method ?? this.method,
      priorityScore: priorityScore ?? this.priorityScore,
    );
  }
}

enum NotificationStatus {
  sent,
  delivered,
  read,
  responded,
  failed,
  expired,
}

enum NotificationMethod {
  pushNotification,
  sms,
  phoneCall,
  email,
}

enum ContactResponse {
  willHelp,
  cannotHelp,
  onMyWay,
  calledAuthorities,
  noResponse,
}
