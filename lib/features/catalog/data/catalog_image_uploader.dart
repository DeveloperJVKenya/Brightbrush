import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a picked image to Storage and returns its download URL. Storage
/// isn't activated on the project yet at the time this was written — calls
/// will throw until it is, so callers should catch and degrade gracefully
/// (save the item without a photo) rather than blocking the whole form.
class CatalogImageUploader {
  CatalogImageUploader(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadCatalogItemImage({
    required String itemId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = 'catalog/$itemId/${DateTime.now().millisecondsSinceEpoch}';
    final ref = _storage.ref(path);
    final task = await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return task.ref.getDownloadURL();
  }

  Future<String> uploadPackageImage({
    required String packageId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = 'packages/$packageId/${DateTime.now().millisecondsSinceEpoch}';
    final ref = _storage.ref(path);
    final task = await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return task.ref.getDownloadURL();
  }
}
