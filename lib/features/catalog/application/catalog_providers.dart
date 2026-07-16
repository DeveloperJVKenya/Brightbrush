import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
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
final catalogCategoryFilterProvider = StateProvider<CatalogCategory?>((ref) => null);

/// Live-filtered catalog: search query (substring, any position) combined
/// with an optional category chip filter. Recomputes on every keystroke.
final filteredCatalogItemsProvider = Provider<AsyncValue<List<CatalogItem>>>((ref) {
  final query = ref.watch(catalogSearchQueryProvider);
  final category = ref.watch(catalogCategoryFilterProvider);
  return ref.watch(activeCatalogItemsProvider).whenData((items) {
    final categoryFiltered = category == null ? items : items.where((i) => i.category == category).toList();
    return filterBySearch(categoryFiltered, query, (item) => item.searchFields);
  });
});

final packagesSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredPackagesProvider = Provider<AsyncValue<List<PackageModel>>>((ref) {
  final query = ref.watch(packagesSearchQueryProvider);
  return ref.watch(activePackagesProvider).whenData((packages) {
    return filterBySearch(packages, query, (p) => p.searchFields);
  });
});
