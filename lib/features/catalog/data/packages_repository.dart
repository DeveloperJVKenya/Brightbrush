import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/package_model.dart';

class PackagesRepository {
  PackagesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _packages => _db.collection('Packages');

  Stream<List<PackageModel>> streamAll() {
    appLogger.d('[packages] streamAll()');
    return _packages
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PackageModel.fromFirestore).toList())
        .transform(logStreamErrors('[packages] streamAll() failed — likely signed in as a role without isCatalogManager()'));
  }

  Stream<List<PackageModel>> streamActive() {
    appLogger.d('[packages] streamActive()');
    return _packages
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PackageModel.fromFirestore).toList())
        .transform(logStreamErrors('[packages] streamActive() failed'));
  }

  Future<String> create(PackageModel package, {required String uid}) async {
    appLogger.i('[packages] create() name="${package.name}" createdBy=$uid');
    try {
      final doc = await _packages.add(package.toFirestoreCreate(uid: uid));
      appLogger.i('[packages] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[packages] create() failed for name="${package.name}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(PackageModel package) async {
    appLogger.i('[packages] update(${package.id})');
    try {
      await _packages.doc(package.id).update(package.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[packages] update(${package.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[packages] delete($id)');
    try {
      await _packages.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[packages] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
