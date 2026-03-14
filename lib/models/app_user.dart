import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final String plan;
  final DateTime? planStartedAt;
  final DateTime? planExpiresAt;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    this.plan = 'free',
    this.planStartedAt,
    this.planExpiresAt,
  });

  bool get isTrader => plan == 'trader';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? '',
      displayName: json['display_name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      createdAt: (json['created_at'] as Timestamp).toDate(),
      lastLoginAt: (json['last_login_at'] as Timestamp).toDate(),
      plan: json['plan'] ?? 'free',
      planStartedAt: json['plan_started_at'] != null
          ? (json['plan_started_at'] as Timestamp).toDate()
          : null,
      planExpiresAt: json['plan_expires_at'] != null
          ? (json['plan_expires_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'created_at': Timestamp.fromDate(createdAt),
      'last_login_at': Timestamp.fromDate(lastLoginAt),
      'plan': plan,
      if (planStartedAt != null)
        'plan_started_at': Timestamp.fromDate(planStartedAt!),
      if (planExpiresAt != null)
        'plan_expires_at': Timestamp.fromDate(planExpiresAt!),
    };
  }
}
