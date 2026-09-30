import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/settings/shared_preferences_provider.dart';
import '../../../shared/search/search_utils.dart';
import '../data/catalog_image_uploader.dart';
import '../data/catalog_repository.dart';
import '../data/packages_repository.dart';
import '../domain/catalog_category.dart';
import '../domain/catalog_item.dart';
import '../domain/package_model.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(firestoreProvider));
});

final packagesRepositoryProvider = Provider<PackagesRepository>((ref) {
  return PackagesRepository(ref.watch(firestoreProvider));
});

final catalogImageUploaderProvider = Provider<CatalogImageUploader>((ref) {
  return CatalogImageUploader(ref.watch(firebaseStorageProvider));
});

/// Customer-facing stream: active items only, live-updating.
///
/// Watches [currentUidProvider] (not just the repository) so that any auth
/// transition — sign-in, sign-out, switching accounts — tears down and
/// resubscribes the underlying `.snapshots()` stream. Without this, a
/// transient `permission-denied` (e.g. a query firing a beat before the
/// auth token finishes attaching right after sign-in) terminates the stream
/// permanently and Riverpod caches that error forever, since nothing would
/// otherwise ever rebuild this provider for the rest of the app session.
final activeCatalogItemsProvider = StreamProvider<List<CatalogItem>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(catalogRepositoryProvider).streamActive();
});

/// Manager/Admin authoring stream: every item regardless of isActive.
final allCatalogItemsProvider = StreamProvider<List<CatalogItem>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(catalogRepositoryProvider).streamAll();
});

final activePackagesProvider = StreamProvider<List<PackageModel>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(packagesRepositoryProvider).streamActive();
});

final allPackagesProvider = StreamProvider<List<PackageModel>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(packagesRepositoryProvider).streamAll();
});

final catalogSearchQueryProvider = StateProvider<String>((ref) => '');
final catalogCategoryFilterProvider = StateProvider<CatalogCategory?>(
  (ref) => null,
);

enum CatalogSort {
  recommended,
  priceLow,
  priceHigh,
  newest,
  topRated,
  bulkSaving,
}

final catalogSortProvider = StateProvider<CatalogSort>(
  (ref) => CatalogSort.recommended,
);

/// Narrowing beyond search and category (the filter sheet).
class CatalogFilters {
  const CatalogFilters({
    this.minPrice,
    this.maxPrice,
    this.customisableOnly = false,
    this.minRating = 0,
    this.maxLeadDays,
  });

  final num? minPrice;
  final num? maxPrice;
  final bool customisableOnly;
  final double minRating;
  final int? maxLeadDays;

  /// How many filters are switched on (the badge on the Filter button).
  int get activeCount =>
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (customisableOnly ? 1 : 0) +
      (minRating > 0 ? 1 : 0) +
      (maxLeadDays != null ? 1 : 0);

  bool matches(CatalogItem i) =>
      (minPrice == null || i.fromPrice >= minPrice!) &&
      (maxPrice == null || i.fromPrice <= maxPrice!) &&
      (!customisableOnly || i.isCustomizable) &&
      (minRating <= 0 || i.ratingAvg >= minRating) &&
      (maxLeadDays == null || i.leadTimeDays <= maxLeadDays!);
}

final catalogFiltersProvider = StateProvider<CatalogFilters>(
  (ref) => const CatalogFilters(),
);

/// "See all" from a home section: show the full list without a search.
final catalogViewAllProvider = StateProvider<bool>((ref) => false);

/// True when the customer is looking at results (search, category,
/// filters or "See all") rather than the home page sections.
final catalogBrowsingProvider = Provider<bool>((ref) {
  return ref.watch(catalogSearchQueryProvider).trim().isNotEmpty ||
      ref.watch(catalogCategoryFilterProvider) != null ||
      ref.watch(catalogFiltersProvider).activeCount > 0 ||
      ref.watch(catalogViewAllProvider);
});

/// Back to the home page: clears search, category, filters and sort.
void resetCatalogBrowsing(WidgetRef ref) {
  ref.read(catalogSearchQueryProvider.notifier).state = '';
  ref.read(catalogCategoryFilterProvider.notifier).state = null;
  ref.read(catalogFiltersProvider.notifier).state = const CatalogFilters();
  ref.read(catalogSortProvider.notifier).state = CatalogSort.recommended;
  ref.read(catalogViewAllProvider.notifier).state = false;
}

/// "Recommended": featured first, then well-reviewed, then newest.
double _recommendScore(CatalogItem i) =>
    (i.isFeatured ? 1000 : 0) +
    i.ratingAvg * 20 * (i.ratingCount.clamp(0, 20) / 20) +
    i.bulkSavingPercent * 0.5;

List<CatalogItem> sortCatalog(List<CatalogItem> items, CatalogSort sort) {
  final list = [...items];
  int byNewest(CatalogItem a, CatalogItem b) =>
      b.createdAt.compareTo(a.createdAt);
  switch (sort) {
    case CatalogSort.recommended:
      list.sort((a, b) {
        final c = _recommendScore(b).compareTo(_recommendScore(a));
        return c != 0 ? c : byNewest(a, b);
      });
    case CatalogSort.priceLow:
      list.sort((a, b) => a.fromPrice.compareTo(b.fromPrice));
    case CatalogSort.priceHigh:
      list.sort((a, b) => b.fromPrice.compareTo(a.fromPrice));
    case CatalogSort.newest:
      list.sort(byNewest);
    case CatalogSort.topRated:
      list.sort((a, b) {
        final c = b.ratingAvg.compareTo(a.ratingAvg);
        return c != 0 ? c : b.ratingCount.compareTo(a.ratingCount);
      });
    case CatalogSort.bulkSaving:
      list.sort((a, b) => b.bulkSavingPercent.compareTo(a.bulkSavingPercent));
  }
  return list;
}

/// Live-filtered catalog: search query (substring, any position), category,
/// filter sheet and sort. Recomputes on every keystroke.
final filteredCatalogItemsProvider = Provider<AsyncValue<List<CatalogItem>>>((
  ref,
) {
  final query = ref.watch(catalogSearchQueryProvider);
  final category = ref.watch(catalogCategoryFilterProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final sort = ref.watch(catalogSortProvider);
  return ref.watch(activeCatalogItemsProvider).whenData((items) {
    final narrowed = items
        .where((i) => (category == null || i.category == category))
        .where(filters.matches)
        .toList();
    final searched = filterBySearch(narrowed, query, (i) => i.searchFields);
    // A text search keeps its relevance order unless a sort was chosen.
    return query.trim().isNotEmpty && sort == CatalogSort.recommended
        ? searched
        : sortCatalog(searched, sort);
  });
});

/// A short most-recent-first list of strings kept on this device.
class _RecentList extends StateNotifier<List<String>> {
  _RecentList(this._ref, this._key, this._max)
    : super(_ref.read(sharedPreferencesProvider).getStringList(_key) ?? []);

  final Ref _ref;
  final String _key;
  final int _max;

  void add(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    state = [
      v,
      ...state.where((x) => x.toLowerCase() != v.toLowerCase()),
    ].take(_max).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }

  void _save() {
    try {
      _ref.read(sharedPreferencesProvider).setStringList(_key, state);
    } catch (_) {
      // Storage unavailable (private window) — keep it in memory only.
    }
  }
}

/// Item ids the customer opened, newest first (this device only).
final recentlyViewedProvider = StateNotifierProvider<_RecentList, List<String>>(
  (ref) => _RecentList(ref, 'catalog.recentlyViewed', 12),
);

/// Search terms the customer submitted, newest first (this device only).
final recentSearchesProvider = StateNotifierProvider<_RecentList, List<String>>(
  (ref) => _RecentList(ref, 'catalog.recentSearches', 8),
);

final packagesSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredPackagesProvider = Provider<AsyncValue<List<PackageModel>>>((
  ref,
) {
  final query = ref.watch(packagesSearchQueryProvider);
  return ref.watch(activePackagesProvider).whenData((packages) {
    return filterBySearch(packages, query, (p) => p.searchFields);
  });
});
