import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/company_asset.dart';

class AssetsRepository {
  AssetsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _assets => _db.collection('CompanyAssets');

  Stream<List<CompanyAsset>> streamAll() {
    appLogger.d('[assets] streamAll()');
    return _assets
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CompanyAsset.fromFirestore).toList())
        .transform(logStreamErrors('[assets] streamAll() failed — likely signed in as a role without isAdminOrDeveloper()'));
  }

  Future<String> create(CompanyAsset asset, {required String uid}) async {
    appLogger.i('[assets] create() name="${asset.name}" createdBy=$uid');
    try {
      final doc = await _assets.add(asset.toFirestoreCreate(uid: uid));
      appLogger.i('[assets] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[assets] create() failed for name="${asset.name}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(CompanyAsset asset) async {
    appLogger.i('[assets] update(${asset.id})');
    try {
      await _assets.doc(asset.id).update(asset.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[assets] update(${asset.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[assets] delete($id)');
    try {
      await _assets.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[assets] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
