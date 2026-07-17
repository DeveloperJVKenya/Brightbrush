import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/cart_repository.dart';

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
