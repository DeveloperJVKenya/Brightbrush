import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/inventory_material.dart';

class InventoryRepository {
  InventoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _materials => _db.collection('InventoryMaterials');

  Stream<List<InventoryMaterial>> streamAll() {
    appLogger.d('[inventory] streamAll()');
    return _materials
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(InventoryMaterial.fromFirestore).toList())
        .transform(logStreamErrors('[inventory] streamAll() failed — likely signed in as a role without isManagerOrAdmin()'));
  }

  Future<String> create(InventoryMaterial material, {required String uid}) async {
    appLogger.i('[inventory] create() name="${material.name}" createdBy=$uid');
    try {
      final doc = await _materials.add(material.toFirestoreCreate(uid: uid));
      appLogger.i('[inventory] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[inventory] create() failed for name="${material.name}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(InventoryMaterial material) async {
    appLogger.i('[inventory] update(${material.id})');
    try {
      await _materials.doc(material.id).update(material.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[inventory] update(${material.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[inventory] delete($id)');
    try {
      await _materials.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[inventory] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
