import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// bright-brush provisions Firestore as a *named* Enterprise-edition
/// database (not the default one), so every access must go through
/// `instanceFor(databaseId: ...)` rather than `FirebaseFirestore.instance`.
const String firestoreDatabaseId = 'brightbrush-main';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: firestoreDatabaseId);
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// Live auth state. Firestore/Storage security rules require
/// `request.auth != null`, so the app signs every visitor in anonymously
/// (see [ensureSignedInProvider]) even before they pick a demo role.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Signs in anonymously if no session exists yet. The splash screen awaits
/// this before routing anywhere, so every screen can assume `auth.currentUser`
/// is non-null.
final ensureSignedInProvider = FutureProvider<User>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final existing = auth.currentUser;
  if (existing != null) return existing;
  final credential = await auth.signInAnonymously();
  return credential.user!;
});
