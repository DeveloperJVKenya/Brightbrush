import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../data/guide_articles_repository.dart';
import '../domain/guide_article.dart';

final guideArticlesRepositoryProvider = Provider<GuideArticlesRepository>((ref) {
  return GuideArticlesRepository(ref.watch(firestoreProvider));
});

/// Admin/Developer authoring stream: every article.
final allGuideArticlesProvider = StreamProvider<List<GuideArticle>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(guideArticlesRepositoryProvider).streamAll();
});

/// The signed-in role's own articles — what the Guide screen shows.
final myGuideArticlesProvider = StreamProvider<List<GuideArticle>>((ref) {
  final role = ref.watch(resolvedRoleProvider).valueOrNull;
  if (role == null) return const Stream.empty();
  return ref.watch(guideArticlesRepositoryProvider).streamForRole(role.name);
});
