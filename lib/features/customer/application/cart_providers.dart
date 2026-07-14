import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal cart: item id -> quantity. Full checkout/payment lives in the
/// Cart & Checkout module (still a placeholder); this exists so "Add to
/// cart" on a catalog item is a real, working action today rather than a
/// dead button, and the shell can show a live item count badge.
class CartController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void add(String itemId, {int quantity = 1}) {
    state = {...state, itemId: (state[itemId] ?? 0) + quantity};
  }

  void remove(String itemId) {
    final next = {...state};
    next.remove(itemId);
    state = next;
  }

  void clear() => state = const {};
}

final cartProvider = NotifierProvider<CartController, Map<String, int>>(CartController.new);

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.values.fold(0, (sum, qty) => sum + qty);
});
