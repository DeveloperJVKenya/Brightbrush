import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/package_model.dart';

class PackagesRepository {
  PackagesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _packages => _db.collection('packages');

  Stream<List<PackageModel>> streamAll() {
    return _packages.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(PackageModel.fromFirestore).toList(),
        );
  }

  Stream<List<PackageModel>> streamActive() {
    return _packages
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PackageModel.fromFirestore).toList());
  }

  Future<String> create(PackageModel package, {required String uid}) async {
    final doc = await _packages.add(package.toFirestoreCreate(uid: uid));
    return doc.id;
  }

  Future<void> update(PackageModel package) {
    return _packages.doc(package.id).update(package.toFirestoreUpdate());
  }

  Future<void> delete(String id) {
    return _packages.doc(id).delete();
  }
}
