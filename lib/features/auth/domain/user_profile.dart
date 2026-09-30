import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/auth/app_role.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.phone,
    required this.photoUrl,
    required this.dailyWage,
    required this.vehiclePlate,
    required this.availability,
    required this.disabled,
  });

  final String uid;
  final String email;
  final String displayName;
  final AppRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String phone;
  final String? photoUrl;

  /// Daily pay rate for manual-worker roles — set by Admin/CEO/Developer
  /// only, never self-editable (see firestore.rules' owner-path immutable
  /// fields for `Users`).
  final num? dailyWage;

  /// Delivery Staff-only self-reported fields.
  final String vehiclePlate;
  final bool availability;

  /// Set by Admin/CEO/Developer only (never self-editable). A disabled
  /// account is force-signed-out and loses every staff/manager/admin
  /// permission immediately — see hasStaffRole() in firestore.rules.
  final bool disabled;

  /// Email domain every account created by the local `seed/` scripts uses.
  static const demoEmailDomain = '@brightbrush.demo';

  /// Seeded demonstration account (not a real sign-up). Role Management
  /// keeps these on their own tab so they never mix with real accounts.
  bool get isDemo => email.toLowerCase().endsWith(demoEmailDomain);

  String get nameOrEmail => displayName.isEmpty ? email : displayName;

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: AppRole.fromRoleName(d['role'] as String?),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      phone: d['phone'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      dailyWage: d['dailyWage'] as num?,
      vehiclePlate: d['vehiclePlate'] as String? ?? '',
      availability: d['availability'] as bool? ?? true,
      disabled: d['disabled'] as bool? ?? false,
    );
  }

  /// Self-registration always creates a plain User profile — matches
  /// firestore.rules, which only ever allows a client to create its own
  /// `users/{uid}` doc with role == 'user'. Every other role (Delivery
  /// Staff, System Manager, Admin/CEO, Developer) is assigned afterward by
  /// an Admin/CEO or Developer via the Role Management screen.
  static Map<String, dynamic> newUserProfile({
    required String email,
    required String displayName,
  }) {
    return {
      'email': email,
      'displayName': displayName,
      'role': AppRole.user.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
