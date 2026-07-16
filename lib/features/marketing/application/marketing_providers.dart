import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/announcements_repository.dart';
import '../domain/announcement_model.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(ref.watch(firestoreProvider));
});

/// Admin/CEO authoring stream: every announcement regardless of isActive.
final allAnnouncementsProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(announcementsRepositoryProvider).streamAll();
});

/// Everyone-facing stream: active announcements only, for Home/Notifications.
final activeAnnouncementsProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(announcementsRepositoryProvider).streamActive();
});
