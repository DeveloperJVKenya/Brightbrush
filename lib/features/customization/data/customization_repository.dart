import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/artwork.dart';
import '../domain/customization_pricing.dart';

/// Artwork library (Storage + Artworks docs) and the admin decoration
/// pricing settings.
class CustomizationRepository {
  CustomizationRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _artworks =>
      _db.collection('Artworks');

  Stream<List<Artwork>> streamMyArtworks(String uid) {
    return _artworks
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Artwork.fromFirestore).toList())
        .transform(logStreamErrors('[artwork] streamMyArtworks failed'));
  }

  /// Manager/Admin: every artwork (the digitizing queue).
  Stream<List<Artwork>> streamAllArtworks() {
    return _artworks
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Artwork.fromFirestore).toList())
        .transform(logStreamErrors('[artwork] streamAllArtworks failed'));
  }

  static String contentTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      'ai' => 'application/illustrator',
      'eps' => 'application/postscript',
      _ => 'application/octet-stream',
    };
  }

  /// Uploads a logo into the customer's library and returns it.
  Future<Artwork> uploadArtwork({
    required String uid,
    required String name,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final doc = _artworks.doc();
    final contentType = contentTypeFor(fileName);
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'artwork/$uid/${doc.id}/$safeName';
    appLogger.i('[artwork] upload $path ($contentType, ${bytes.length} bytes)');
    try {
      final task = await _storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: contentType));
      final url = await task.ref.getDownloadURL();
      await doc.set({
        'ownerId': uid,
        'name': name,
        'fileUrl': url,
        'storagePath': path,
        'contentType': contentType,
        'sizeBytes': bytes.length,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Artwork(
        id: doc.id,
        ownerId: uid,
        name: name,
        fileUrl: url,
        storagePath: path,
        contentType: contentType,
        sizeBytes: bytes.length,
        digitized: false,
        stitchCount: null,
        threadCount: null,
        digitizedFiles: const [],
        staffNotes: '',
        createdAt: DateTime.now(),
      );
    } catch (error, stack) {
      appLogger.e('[artwork] upload failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> renameArtwork(String id, String name) => _artworks
      .doc(id)
      .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});

  /// Removes the library entry and its file. Past orders keep their own
  /// copy of the name/URL, so this never breaks order history.
  Future<void> deleteArtwork(Artwork artwork) async {
    await _artworks.doc(artwork.id).delete();
    try {
      await _storage.ref(artwork.storagePath).delete();
    } catch (error) {
      appLogger.w(
        '[artwork] file cleanup failed for ${artwork.id}',
        error: error,
      );
    }
  }

  /// Staff: attach a digitized machine file (DST/EMB/PES...).
  Future<DigitizedFile> uploadDigitizedFile({
    required Artwork artwork,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'artwork/${artwork.ownerId}/${artwork.id}/digitized/$safeName';
    final task = await _storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(contentType: 'application/octet-stream'),
        );
    return DigitizedFile(
      name: safeName,
      format: safeName.contains('.')
          ? safeName.split('.').last.toUpperCase()
          : 'FILE',
      url: await task.ref.getDownloadURL(),
      storagePath: path,
    );
  }

  /// Staff: save digitizing details. Marking an artwork digitized waives
  /// the embroidery setup fee on future orders and prices by stitch count.
  Future<void> saveDigitizing({
    required String artworkId,
    required bool digitized,
    required int? stitchCount,
    required int? threadCount,
    required List<DigitizedFile> files,
    required String staffNotes,
  }) {
    appLogger.i(
      '[artwork] saveDigitizing($artworkId, digitized=$digitized, stitches=$stitchCount)',
    );
    return _artworks.doc(artworkId).update({
      'digitized': digitized,
      'stitchCount': stitchCount ?? FieldValue.delete(),
      'threadCount': threadCount ?? FieldValue.delete(),
      'digitizedFiles': [for (final f in files) f.toMap()],
      'staffNotes': staffNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DecorationPricing> streamDecorationPricing() {
    return _db
        .collection('Settings')
        .doc('decoration')
        .snapshots()
        .map((snap) => DecorationPricing.fromMap(snap.data()))
        .transform(
          logStreamErrors('[decoration] streamDecorationPricing failed'),
        );
  }

  Future<void> saveDecorationPricing(
    DecorationPricing pricing, {
    required String uid,
  }) {
    appLogger.i('[decoration] saveDecorationPricing by $uid');
    return _db
        .collection('Settings')
        .doc('decoration')
        .set(pricing.toFirestore(uid: uid));
  }
}
