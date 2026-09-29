import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/domain/package_model.dart';
import '../../customization/domain/customization_pricing.dart';
import '../../orders/domain/order_model.dart';
import '../data/cart_repository.dart';

/// Cart keys with this prefix are seasonal packages; every other key is a
/// CatalogItems id. Must match PACKAGE_PREFIX in
/// functions/src/orders/place_order.ts, which prices the cart server-side.
const String packageCartKeyPrefix = 'pkg:';

String packageCartKey(String packageId) => '$packageCartKeyPrefix$packageId';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(firestoreProvider));
});

/// The whole live cart (simple + customised lines), persisted per customer
/// in Firestore so it follows the account across devices.
final cartStateProvider = StreamProvider<CartState>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const CartState());
  return ref.watch(cartRepositoryProvider).streamCart(uid);
});

/// Simple lines only (catalog item / package key -> quantity).
final cartProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  return ref.watch(cartStateProvider).whenData((s) => s.items);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartStateProvider).valueOrNull ?? const CartState();
  return cart.items.values.fold(0, (sum, qty) => sum + qty) +
      cart.lines.values.fold(0, (sum, l) => sum + l.quantity);
});

/// Cart mutations. The stream above is the only source of truth for what's
/// displayed; every write sends the full cart so the two halves never
/// clobber each other.
class CartActions {
  CartActions(this._ref);

  final Ref _ref;

  CartState get _current =>
      _ref.read(cartStateProvider).valueOrNull ?? const CartState();

  Future<void> _write({
    Map<String, int>? items,
    Map<String, CustomLineConfig>? lines,
  }) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final current = _current;
    await _ref
        .read(cartRepositoryProvider)
        .setCart(
          uid,
          items: items ?? current.items,
          lines: lines ?? current.lines,
        );
  }

  Future<void> add(String itemId, {int quantity = 1}) {
    final current = _current.items;
    return _write(
      items: {...current, itemId: (current[itemId] ?? 0) + quantity},
    );
  }

  /// Adds a plain (non-customised) catalog item, starting at its minimum
  /// order quantity the first time (the server rejects anything below
  /// MOQ), then one more per tap.
  Future<int> addCatalogItem(CatalogItem item) async {
    final current = _current.items[item.id] ?? 0;
    final next = current == 0 ? (item.moq < 1 ? 1 : item.moq) : current + 1;
    await setQuantity(item.id, next);
    return next;
  }

  Future<void> addPackage(PackageModel package) =>
      add(packageCartKey(package.id));

  Future<void> setQuantity(String itemId, int quantity) {
    final next = {..._current.items};
    if (quantity <= 0) {
      next.remove(itemId);
    } else {
      next[itemId] = quantity;
    }
    return _write(items: next);
  }

  Future<void> remove(String itemId) => setQuantity(itemId, 0);

  static String _newLineId() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  /// Adds (or, with [lineId], replaces) a customised line.
  Future<void> saveCustomLine(CustomLineConfig config, {String? lineId}) {
    return _write(lines: {..._current.lines, lineId ?? _newLineId(): config});
  }

  Future<void> removeCustomLine(String lineId) {
    return _write(lines: {..._current.lines}..remove(lineId));
  }

  /// "Order again": puts a past order's catalog items, packages and
  /// customised lines (same artwork, placements and sizes) back in the
  /// cart. Quote lines are skipped — they need a fresh quote. Returns how
  /// many lines were added. Prices are recalculated at checkout.
  Future<int> reorder(OrderModel order) async {
    final items = {..._current.items};
    final lines = {..._current.lines};
    var added = 0;
    for (final line in order.items) {
      switch (line.kind) {
        case OrderLineKind.custom:
          final config = line.customization;
          if (config == null) continue;
          lines[_newLineId()] = config;
          added++;
        case OrderLineKind.package:
          final key = packageCartKey(line.itemId);
          items[key] = (items[key] ?? 0) + line.quantity;
          added++;
        case OrderLineKind.item:
          items[line.itemId] = (items[line.itemId] ?? 0) + line.quantity;
          added++;
        case OrderLineKind.quote:
          break;
      }
    }
    if (added > 0) await _write(items: items, lines: lines);
    return added;
  }

  Future<void> clear() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(cartRepositoryProvider).clear(uid);
  }
}

final cartActionsProvider = Provider<CartActions>((ref) => CartActions(ref));
