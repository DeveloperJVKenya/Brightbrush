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
  });

  final String uid;
  final String email;
  final String displayName;
  final AppRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: AppRole.fromRoleName(d['role'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Self-registration always creates a plain User profile — matches
  /// firestore.rules, which only ever allows a client to create its own
  /// `users/{uid}` doc with role == 'user'. Every other role (Delivery
  /// Staff, System Manager, Admin/CEO, Developer) is assigned afterward by
  /// an Admin/CEO or Developer via the Role Management screen.
  static Map<String, dynamic> newUserProfile({required String email, required String displayName}) {
    return {
      'email': email,
      'displayName': displayName,
      'role': AppRole.user.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
