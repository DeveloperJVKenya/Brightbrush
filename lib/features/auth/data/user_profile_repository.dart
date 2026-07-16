import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('Users').doc(uid);

  Stream<UserProfile?> streamProfile(String uid) {
    appLogger.d('[users] streamProfile(uid=$uid)');
    return _doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null)
        .transform(logStreamErrors('[users] streamProfile(uid=$uid) failed'));
  }

  /// Staff directory lookup (e.g. delivery staff for assignment/oversight
  /// screens). firestore.rules only lets manager/admin/developer read
  /// deliveryStaff profiles through this path — see [streamAllProfiles] for
  /// the Admin/CEO-and-Developer-only full directory used by Role
  /// Management.
  Stream<List<UserProfile>> streamByRole(AppRole role) {
    appLogger.d('[users] streamByRole(${role.name})');
    return _db
        .collection('Users')
        .where('role', isEqualTo: role.name)
        .orderBy('displayName')
        .snapshots()
        .map((snap) => snap.docs.map(UserProfile.fromFirestore).toList())
        .transform(logStreamErrors('[users] streamByRole(${role.name}) failed — caller likely lacks isManagerOrAdmin()'));
  }

  /// Every account, every role — the Role Management directory. Restricted
  /// by firestore.rules to Admin/CEO and Developer (`isAdminOrDeveloper()`);
  /// anyone else's Firestore read is denied regardless of what this query
  /// asks for.
  Stream<List<UserProfile>> streamAllProfiles() {
    appLogger.d('[users] streamAllProfiles()');
    return _db
        .collection('Users')
        .orderBy('displayName')
        .snapshots()
        .map((snap) => snap.docs.map(UserProfile.fromFirestore).toList())
        .transform(logStreamErrors('[users] streamAllProfiles() failed — caller likely lacks isAdminOrDeveloper()'));
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _doc(uid).get();
    return doc.exists ? UserProfile.fromFirestore(doc) : null;
  }

  /// Called right after a brand-new email/password sign-up. A no-op if the
  /// profile somehow already exists (e.g. a retried request). Every
  /// self-registered account always starts as [AppRole.user] — every other
  /// role is assigned afterward via [updateRole].
  Future<void> ensureUserProfile({required String uid, required String email, required String displayName}) async {
    appLogger.i('[users] ensureUserProfile(uid=$uid, email=$email)');
    try {
      final existing = await _doc(uid).get();
      if (existing.exists) {
        appLogger.i('[users] profile already exists for uid=$uid — no-op');
        return;
      }
      await _doc(uid).set(UserProfile.newUserProfile(email: email, displayName: displayName));
      appLogger.i('[users] created user profile for uid=$uid');
    } catch (error, stack) {
      appLogger.e('[users] ensureUserProfile(uid=$uid) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  /// Self-service: the owner updating their own display name from the
  /// Profile screen. firestore.rules' owner-update path allows this while
  /// keeping role/email/createdAt immutable.
  Future<void> updateDisplayName({required String uid, required String displayName}) async {
    appLogger.i('[users] updateDisplayName(uid=$uid, displayName=$displayName)');
    try {
      await _doc(uid).update({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      appLogger.i('[users] displayName updated uid=$uid');
    } catch (error, stack) {
      appLogger.e('[users] updateDisplayName(uid=$uid) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  /// Role Management: Admin/CEO or Developer assigning a role to some other
  /// account. firestore.rules blocks this for `uid == request.auth.uid` —
  /// you can't change your own role through this path, only someone else's.
  Future<void> updateRole({required String uid, required AppRole role, required String changedByUid}) async {
    appLogger.i('[users] updateRole(uid=$uid -> ${role.name}, changedBy=$changedByUid)');
    try {
      await _doc(uid).update({
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      appLogger.i('[users] role updated uid=$uid -> ${role.name}');
    } catch (error, stack) {
      appLogger.e('[users] updateRole(uid=$uid) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
