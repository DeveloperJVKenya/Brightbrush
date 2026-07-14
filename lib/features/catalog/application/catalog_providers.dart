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
final activeCatalogItemsProvider = StreamProvider<List<CatalogItem>>((ref) {
  return ref.watch(catalogRepositoryProvider).streamActive();
});

/// Manager/Admin authoring stream: every item regardless of isActive.
final allCatalogItemsProvider = StreamProvider<List<CatalogItem>>((ref) {
  return ref.watch(catalogRepositoryProvider).streamAll();
});

final activePackagesProvider = StreamProvider<List<PackageModel>>((ref) {
  return ref.watch(packagesRepositoryProvider).streamActive();
});

final allPackagesProvider = StreamProvider<List<PackageModel>>((ref) {
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
