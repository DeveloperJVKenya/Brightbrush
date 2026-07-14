import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/catalog_item.dart';

class CatalogRepository {
  CatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('catalog_items');

  /// All items, newest first — used by Manager/Admin authoring views, which
  /// need to see inactive/draft items too.
  Stream<List<CatalogItem>> streamAll() {
    return _items.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(CatalogItem.fromFirestore).toList(),
        );
  }

  /// Active-only items, newest first — the customer-facing catalog.
  Stream<List<CatalogItem>> streamActive() {
    return _items
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CatalogItem.fromFirestore).toList());
  }

  Future<CatalogItem?> fetchById(String id) async {
    final doc = await _items.doc(id).get();
    if (!doc.exists) return null;
    return CatalogItem.fromFirestore(doc);
  }

  Future<String> create(CatalogItem item, {required String uid}) async {
    final doc = await _items.add(item.toFirestoreCreate(uid: uid));
    return doc.id;
  }

  Future<void> update(CatalogItem item) {
    return _items.doc(item.id).update(item.toFirestoreUpdate());
  }

  Future<void> delete(String id) {
    return _items.doc(id).delete();
  }
}
