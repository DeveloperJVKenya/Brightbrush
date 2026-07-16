import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../shared/search/search_utils.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_material.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(firestoreProvider));
});

/// Watches [currentUidProvider] so any auth transition tears down and
/// resubscribes the stream instead of latching onto a stale error — see
/// the equivalent comment on activeCatalogItemsProvider.
final allInventoryMaterialsProvider = StreamProvider<List<InventoryMaterial>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(inventoryRepositoryProvider).streamAll();
});

final inventorySearchQueryProvider = StateProvider<String>((ref) => '');

final lowStockOnlyProvider = StateProvider<bool>((ref) => false);

final filteredInventoryMaterialsProvider = Provider<AsyncValue<List<InventoryMaterial>>>((ref) {
  final query = ref.watch(inventorySearchQueryProvider);
  final lowStockOnly = ref.watch(lowStockOnlyProvider);
  return ref.watch(allInventoryMaterialsProvider).whenData((materials) {
    final stockFiltered = lowStockOnly ? materials.where((m) => m.isLowStock).toList() : materials;
    return filterBySearch(stockFiltered, query, (m) => m.searchFields);
  });
});
