import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  Stream<UserProfile?> streamProfile(String uid) {
    return _doc(uid).snapshots().map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _doc(uid).get();
    return doc.exists ? UserProfile.fromFirestore(doc) : null;
  }

  /// Called right after a brand-new email/password sign-up. A no-op if the
  /// profile somehow already exists (e.g. a retried request).
  Future<void> ensureCustomerProfile({required String uid, required String email, required String displayName}) async {
    final existing = await _doc(uid).get();
    if (existing.exists) return;
    await _doc(uid).set(UserProfile.newCustomerProfile(email: email, displayName: displayName));
  }
}
