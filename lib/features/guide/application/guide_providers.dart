import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/settings/shared_preferences_provider.dart';
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

String _guideCacheKey(String roleName) => 'guide.cache.$roleName';

/// The signed-in role's own articles — what the Guide screen shows. Every
/// fresh batch is also written to on-device storage so the predefined
/// questions still work offline (see [readCachedGuideArticles]); the
/// free-text "Ask something else" assistant call has no offline path and
/// simply fails without a connection.
final myGuideArticlesProvider = StreamProvider<List<GuideArticle>>((ref) {
  final role = ref.watch(resolvedRoleProvider).valueOrNull;
  if (role == null) return const Stream.empty();
  final prefs = ref.watch(sharedPreferencesProvider);
  return ref.watch(guideArticlesRepositoryProvider).streamForRole(role.name).map((articles) {
    prefs.setString(_guideCacheKey(role.name), jsonEncode(articles.map((a) => a.toCacheJson()).toList()));
    return articles;
  });
});

/// Reads whatever was last cached for [role] — used as the Guide screen's
/// fallback when the live stream errors out (e.g. no connection).
List<GuideArticle> readCachedGuideArticles(WidgetRef ref, AppRole role) {
  final raw = ref.read(sharedPreferencesProvider).getString(_guideCacheKey(role.name));
  if (raw == null) return const [];
  try {
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => GuideArticle.fromCacheJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return const [];
  }
}
