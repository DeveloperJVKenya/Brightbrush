import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';

/// One cart per customer, persisted at `Carts/{uid}` so it survives app
/// restarts, sign-out/sign-in, and switching devices — unlike the old
/// in-memory-only cart, which reset on every fresh app launch.
class CartRepository {
  CartRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('Carts').doc(uid);

  Stream<Map<String, int>> streamCart(String uid) {
    appLogger.d('[cart] streamCart(uid=$uid)');
    return _doc(uid)
        .snapshots()
        .map((snap) {
          final raw =
              snap.data()?['items'] as Map<String, dynamic>? ?? const {};
          return raw.map(
            (itemId, qty) => MapEntry(itemId, (qty as num).toInt()),
          );
        })
        .transform(logStreamErrors('[cart] streamCart() failed'));
  }

  Future<void> setItems(String uid, Map<String, int> items) async {
    appLogger.i('[cart] setItems(uid=$uid, ${items.length} line(s))');
    try {
      await _doc(
        uid,
      ).set({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (error, stack) {
      appLogger.e(
        '[cart] setItems(uid=$uid) failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> clear(String uid) => setItems(uid, const {});
}
