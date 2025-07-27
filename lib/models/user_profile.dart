class UserProfile {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String subscriptionPlan; // "1-meal" or "2-meal"
  final String? currentScheduleId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.subscriptionPlan,
    this.currentScheduleId,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'subscriptionPlan': subscriptionPlan,
      'currentScheduleId': currentScheduleId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      subscriptionPlan: map['subscriptionPlan'] ?? '1-meal',
      currentScheduleId: map['currentScheduleId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isActive: map['isActive'] ?? true,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? subscriptionPlan,
    String? currentScheduleId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      currentScheduleId: currentScheduleId ?? this.currentScheduleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
