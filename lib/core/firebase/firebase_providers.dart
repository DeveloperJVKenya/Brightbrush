import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';

/// bright-brush provisions Firestore as a *named* Enterprise-edition
/// database (not the default one), so every access must go through
/// `instanceFor(databaseId: ...)` rather than `FirebaseFirestore.instance`.
const String firestoreDatabaseId = 'brightbrush-main';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: firestoreDatabaseId);
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// Live auth state — every real sign-in/sign-out event, logged so a
/// permission-denied downstream can be traced back to exactly which auth
/// transition preceded it. Anonymous sign-in is disabled project-wide: every
/// visitor must authenticate with a real account (customer, staff, or
/// developer), so `user == null` here always means "show the login screen."
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().map((user) {
    if (user == null) {
      appLogger.i('[auth] authStateChanges -> signed out');
    } else {
      appLogger.i('[auth] authStateChanges -> uid=${user.uid} anonymous=${user.isAnonymous} email=${user.email}');
    }
    return user;
  });
});

/// The current signed-in [User], reactively — `null` the instant a
/// sign-out happens, unlike the old `ensureSignedInProvider` (a
/// `FutureProvider` that resolved once and then stayed cached with the
/// *first* uid it ever saw for the rest of the app session, silently
/// feeding a stale customerId/staffUid into new Firestore writes after any
/// later sign-in/out — the direct cause of several "permission-denied on
/// create" reports). Read this with `ref.watch`/`ref.read` right before use;
/// never cache its value in a field.
final currentUserProvider = Provider<User?>((ref) => ref.watch(authStateProvider).valueOrNull);

/// Convenience accessor for the common case of just needing the uid.
final currentUidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.uid);
