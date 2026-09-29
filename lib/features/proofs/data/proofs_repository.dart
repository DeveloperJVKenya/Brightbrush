import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';

enum ProofResponse { pending, approved, changesRequested }

/// Orders/{orderId}/Proofs/{id} — one version of a digital proof.
class OrderProof {
  const OrderProof({
    required this.id,
    required this.version,
    required this.imageUrls,
    required this.note,
    required this.stitchCount,
    required this.status,
    required this.customerComment,
    required this.createdAt,
  });

  final String id;
  final int version;
  final List<String> imageUrls;
  final String note;
  final int? stitchCount;
  final ProofResponse status;
  final String? customerComment;
  final DateTime createdAt;

  factory OrderProof.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return OrderProof(
      id: doc.id,
      version: (d['version'] as num?)?.toInt() ?? 1,
      imageUrls: (d['imageUrls'] as List?)?.cast<String>() ?? const [],
      note: d['note'] as String? ?? '',
      stitchCount: (d['stitchCount'] as num?)?.toInt(),
      status: ProofResponse.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => ProofResponse.pending,
      ),
      customerComment: d['customerComment'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ProofsRepository {
  ProofsRepository(this._db, this._storage, this._functions);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  /// Newest first.
  Stream<List<OrderProof>> streamProofs(String orderId) {
    return _db
        .collection('Orders')
        .doc(orderId)
        .collection('Proofs')
        .orderBy('version', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(OrderProof.fromFirestore).toList())
        .transform(logStreamErrors('[proofs] streamProofs($orderId) failed'));
  }

  /// Staff: upload proof images, then ask the server to record the proof
  /// and move the order to "awaiting approval".
  Future<void> sendProof({
    required String orderId,
    required List<(Uint8List, String)> images,
    required String note,
    int? stitchCount,
  }) async {
    appLogger.i('[proofs] sendProof($orderId, ${images.length} image(s))');
    final urls = <String>[];
    for (final (i, (bytes, contentType)) in images.indexed) {
      final path =
          'proofs/$orderId/${DateTime.now().millisecondsSinceEpoch}_$i';
      final task = await _storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: contentType));
      urls.add(await task.ref.getDownloadURL());
    }
    await _functions.httpsCallable('sendProof').call({
      'orderId': orderId,
      'imageUrls': urls,
      'note': note,
      'stitchCount': ?stitchCount,
    });
  }

  Future<void> respond({
    required String orderId,
    required String proofId,
    required bool approve,
    required String comment,
  }) async {
    appLogger.i('[proofs] respond($orderId/$proofId, approve=$approve)');
    await _functions.httpsCallable('respondToProof').call({
      'orderId': orderId,
      'proofId': proofId,
      'decision': approve ? 'approved' : 'changesRequested',
      'comment': comment,
    });
  }
}
