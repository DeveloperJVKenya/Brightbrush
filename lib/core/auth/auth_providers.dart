import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_profile_repository.dart';
import '../firebase/firebase_providers.dart';
import 'app_role.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(firestoreProvider));
});

/// Whether a guest has actually clicked "Continue as Guest Customer".
///
/// `ensureSignedInProvider` signs every visitor in anonymously at splash
/// purely so Firestore/Storage reads satisfy `request.auth != null` — that
/// technicality shouldn't, on its own, skip the login screen. Only an
/// explicit guest action resolves an anonymous session to AppRole.customer;
/// resets on sign-out so the next visit shows login again, same as before.
final guestEnteredProvider = StateProvider<bool>((ref) => false);

/// The signed-in role, resolved live from Firebase Auth + Firestore:
/// - signed out -> null (router sends the user to /login)
/// - anonymous session (guest browsing/ordering) -> AppRole.customer, no
///   Firestore lookup needed
/// - real account -> streams `users/{uid}.role` from Firestore, so a role
///   change (or the brief moment between sign-up and profile creation)
///   reflects live rather than needing a re-login.
///
/// This replaced an earlier local `StateProvider` demo toggle: that let
/// any browser tab claim to be Admin/Manager/etc without a matching
/// Firestore permission, which produced permission-denied errors the
/// instant a screen tried to read/write something gated by a real staff
/// role. Every role the UI shows now corresponds to a role Firestore rules
/// actually agree the signed-in user has.
final resolvedRoleProvider = StreamProvider<AppRole?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final guestEntered = ref.watch(guestEnteredProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);
    if (user.isAnonymous) return Stream.value(guestEntered ? AppRole.customer : null);
    // Only touches Firestore for a real (non-anonymous) account, so guest
    // browsing/ordering — and tests that only stub FirebaseAuth — never
    // need a live Firestore/Firebase.initializeApp() to resolve a role.
    final repo = ref.read(userProfileRepositoryProvider);
    return repo.streamProfile(user.uid).map((profile) => profile?.role ?? AppRole.customer);
  });
});
