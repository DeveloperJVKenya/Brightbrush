import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/domain/package_model.dart';
import '../data/cart_repository.dart';

/// Cart keys with this prefix are seasonal packages; every other key is a
/// CatalogItems id. Must match PACKAGE_PREFIX in
/// functions/src/orders/place_order.ts, which prices the cart server-side.
const String packageCartKeyPrefix = 'pkg:';

String packageCartKey(String packageId) => '$packageCartKeyPrefix$packageId';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(firestoreProvider));
});

/// Live cart contents (item id -> quantity), persisted per customer in
/// Firestore — survives app restarts and follows the account across
/// devices, unlike the old session-only in-memory cart.
final cartProvider = StreamProvider<Map<String, int>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(cartRepositoryProvider).streamCart(uid);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? const {};
  return cart.values.fold(0, (sum, qty) => sum + qty);
});

/// Cart mutations, split out from [cartProvider] since that's a plain
/// [StreamProvider] (the write path always goes straight to Firestore —
/// the stream above is the only source of truth for what's displayed).
class CartActions {
  CartActions(this._ref);

  final Ref _ref;

  Future<void> add(String itemId, {int quantity = 1}) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final current =
        _ref.read(cartProvider).valueOrNull ?? const <String, int>{};
    final next = {...current, itemId: (current[itemId] ?? 0) + quantity};
    await _ref.read(cartRepositoryProvider).setItems(uid, next);
  }

  /// Adds a catalog item, starting at its minimum order quantity the first
  /// time (the server rejects anything below MOQ), then one more per tap.
  Future<int> addCatalogItem(CatalogItem item) async {
    final current =
        _ref.read(cartProvider).valueOrNull?[item.id] ?? 0;
    final next = current == 0 ? (item.moq < 1 ? 1 : item.moq) : current + 1;
    await setQuantity(item.id, next);
    return next;
  }

  Future<void> addPackage(PackageModel package) =>
      add(packageCartKey(package.id));

  Future<void> setQuantity(String itemId, int quantity) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final current =
        _ref.read(cartProvider).valueOrNull ?? const <String, int>{};
    final next = {...current};
    if (quantity <= 0) {
      next.remove(itemId);
    } else {
      next[itemId] = quantity;
    }
    await _ref.read(cartRepositoryProvider).setItems(uid, next);
  }

  Future<void> remove(String itemId) => setQuantity(itemId, 0);

  Future<void> clear() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(cartRepositoryProvider).clear(uid);
  }
}

final cartActionsProvider = Provider<CartActions>((ref) => CartActions(ref));
