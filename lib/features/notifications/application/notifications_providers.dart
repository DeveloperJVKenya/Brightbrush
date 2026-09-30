import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

final inboxProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationsRepositoryProvider).streamInbox(uid);
});

final unreadCountProvider = Provider<int>((ref) {
  return (ref.watch(inboxProvider).valueOrNull ?? const [])
      .where((n) => !n.read)
      .length;
});

final notificationPrefsProvider = StreamProvider<NotificationPrefs>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const NotificationPrefs());
  return ref.watch(notificationsRepositoryProvider).streamPrefs(uid);
});
