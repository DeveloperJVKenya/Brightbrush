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

  /// Self-registration always creates a plain customer profile — matches
  /// firestore.rules, which only ever allows a client to create its own
  /// `users/{uid}` doc with role == 'customer'.
  static Map<String, dynamic> newCustomerProfile({required String email, required String displayName}) {
    return {
      'email': email,
      'displayName': displayName,
      'role': AppRole.customer.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
