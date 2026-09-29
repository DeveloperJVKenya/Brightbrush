import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../../customization/domain/customization_pricing.dart';

/// Everything in a customer's cart: simple lines (catalog item id or
/// `pkg:<id>` -> quantity) and customised lines (lineId -> configuration).
class CartState {
  const CartState({this.items = const {}, this.lines = const {}});

  final Map<String, int> items;
  final Map<String, CustomLineConfig> lines;

  bool get isEmpty => items.isEmpty && lines.isEmpty;
}

/// One cart per customer, persisted at `Carts/{uid}` so it survives app
/// restarts, sign-out/sign-in, and switching devices — unlike the old
/// in-memory-only cart, which reset on every fresh app launch.
class CartRepository {
  CartRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('Carts').doc(uid);

  Stream<CartState> streamCart(String uid) {
    appLogger.d('[cart] streamCart(uid=$uid)');
    return _doc(uid)
        .snapshots()
        .map((snap) {
          final data = snap.data() ?? const {};
          final raw = data['items'] as Map<String, dynamic>? ?? const {};
          final lines = data['lines'] as Map<String, dynamic>? ?? const {};
          return CartState(
            items: raw.map(
              (itemId, qty) => MapEntry(itemId, (qty as num).toInt()),
            ),
            lines: lines.map(
              (id, cfg) => MapEntry(
                id,
                CustomLineConfig.fromMap(Map<String, dynamic>.from(cfg as Map)),
              ),
            ),
          );
        })
        .transform(logStreamErrors('[cart] streamCart() failed'));
  }

  /// Writes the whole cart. Always includes both maps so a write to one
  /// never wipes the other.
  Future<void> setCart(
    String uid, {
    required Map<String, int> items,
    required Map<String, CustomLineConfig> lines,
  }) async {
    appLogger.i(
      '[cart] setCart(uid=$uid, ${items.length} simple, ${lines.length} custom)',
    );
    try {
      await _doc(uid).set({
        'items': items,
        'lines': {for (final e in lines.entries) e.key: e.value.toCartMap()},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      appLogger.e(
        '[cart] setCart(uid=$uid) failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> clear(String uid) =>
      setCart(uid, items: const {}, lines: const {});
}
