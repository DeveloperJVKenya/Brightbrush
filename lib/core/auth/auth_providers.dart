import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_profile_repository.dart';
import '../../features/auth/domain/user_profile.dart';
import '../firebase/firebase_providers.dart';
import '../logging/app_logger.dart';
import 'app_role.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(firestoreProvider));
});

/// The signed-in account's own profile document (displayName/email/role) —
/// used by the shared Profile screen. Watches [currentUidProvider] (not a
/// manual subscription) so it tears down and resubscribes cleanly on every
/// auth transition, same reasoning as [resolvedRoleProvider].
final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).streamProfile(uid);
});

/// The delivery staff directory — used by Manager's Staff Assignment screen
/// and Admin's Deliveries screen to show names alongside orders, which only
/// ever store a staff *uid* (`assignedStaffId`), never a denormalized name.
final deliveryStaffDirectoryProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(userProfileRepositoryProvider).streamByRole(AppRole.deliveryStaff);
});

/// Every account, every role — the Role Management directory. Firestore
/// rules restrict the underlying read to Admin/CEO and Developer, so this
/// only ever resolves data for those two roles; anyone else gets a
/// permission-denied surfaced as an [AsyncError].
final allUserProfilesProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(userProfileRepositoryProvider).streamAllProfiles();
});

/// The signed-in role, resolved live from Firebase Auth + Firestore:
/// - signed out -> null (router sends the user to /login)
/// - real account -> streams `users/{uid}.role` from Firestore, so a role
///   change (or the brief moment between sign-up and profile creation)
///   reflects live rather than needing a re-login.
///
/// Anonymous/guest sign-in is intentionally not handled here at all —
/// anonymous auth is disabled project-wide (disabled in the Identity
/// Platform config, and the login screen only ever offers real
/// email/password sign-in/sign-up), so every non-null [User] this ever
/// sees is a real account with a `users/{uid}` profile.
///
/// Deliberately built by *watching* [authStateProvider] rather than doing
/// `auth.authStateChanges().asyncExpand(...)` inline: `asyncExpand` behaves
/// like `concatMap`, not `switchMap` — it waits for the current inner stream
/// to finish before processing the next outer event, instead of cancelling
/// it. A Firestore `.snapshots()` listener (the inner stream for any real
/// account below) never finishes on its own, so once any staff account
/// signed in, that inline version got permanently stuck on that one
/// listener — sign-out still happened at the Firebase Auth level, but this
/// provider never noticed, so the resolved role never changed again for the
/// rest of that page load (switching role looked like a dead button).
/// Watching [authStateProvider] instead makes Riverpod itself tear down and
/// rebuild this provider — cancelling the old Firestore listener — every
/// time the signed-in user actually changes.
final resolvedRoleProvider = StreamProvider<AppRole?>((ref) {
  final userAsync = ref.watch(authStateProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) {
        appLogger.i('[role] no signed-in user -> role=null');
        return Stream.value(null);
      }
      final repo = ref.watch(userProfileRepositoryProvider);
      return repo.streamProfile(user.uid).map((profile) {
        final role = profile?.role ?? AppRole.user;
        appLogger.i('[role] users/${user.uid} -> role=$role (profile ${profile == null ? "missing, defaulted" : "found"})');
        return role;
      }).transform(StreamTransformer<AppRole, AppRole?>.fromHandlers(
        handleError: (error, stack, sink) {
          appLogger.e('[role] streamProfile(${user.uid}) failed — treating as signed-out so the router falls back to /login',
              error: error, stackTrace: stack);
          sink.add(null);
        },
      ));
    },
    loading: () => const Stream<AppRole?>.empty(),
    error: (error, stack) {
      appLogger.e('[role] authStateProvider errored', error: error, stackTrace: stack);
      return Stream.value(null);
    },
  );
});
