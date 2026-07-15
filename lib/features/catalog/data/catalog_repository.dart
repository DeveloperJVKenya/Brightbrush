import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/catalog_item.dart';

class CatalogRepository {
  CatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('CatalogItems');

  /// All items, newest first — used by Manager/Admin authoring views, which
  /// need to see inactive/draft items too.
  Stream<List<CatalogItem>> streamAll() {
    appLogger.d('[catalog] streamAll()');
    return _items
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CatalogItem.fromFirestore).toList())
        .transform(logStreamErrors('[catalog] streamAll() failed — likely signed in as a role without isCatalogManager()'));
  }

  /// Active-only items, newest first — the customer-facing catalog.
  Stream<List<CatalogItem>> streamActive() {
    appLogger.d('[catalog] streamActive()');
    return _items
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CatalogItem.fromFirestore).toList())
        .transform(logStreamErrors('[catalog] streamActive() failed'));
  }

  Future<CatalogItem?> fetchById(String id) async {
    final doc = await _items.doc(id).get();
    if (!doc.exists) return null;
    return CatalogItem.fromFirestore(doc);
  }

  Future<String> create(CatalogItem item, {required String uid}) async {
    appLogger.i('[catalog] create() name="${item.name}" createdBy=$uid');
    try {
      final doc = await _items.add(item.toFirestoreCreate(uid: uid));
      appLogger.i('[catalog] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[catalog] create() failed for name="${item.name}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(CatalogItem item) async {
    appLogger.i('[catalog] update(${item.id})');
    try {
      await _items.doc(item.id).update(item.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[catalog] update(${item.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[catalog] delete($id)');
    try {
      await _items.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[catalog] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
