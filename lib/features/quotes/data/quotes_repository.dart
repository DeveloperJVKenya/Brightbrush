import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/quote_request.dart';

class QuotesRepository {
  QuotesRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _quotes =>
      _db.collection('QuoteRequests');

  Stream<List<QuoteRequest>> streamForCustomer(String uid) {
    return _quotes
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(QuoteRequest.fromFirestore).toList())
        .transform(logStreamErrors('[quotes] streamForCustomer($uid) failed'));
  }

  /// Manager/Admin inbox — every request.
  Stream<List<QuoteRequest>> streamAll() {
    return _quotes
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(QuoteRequest.fromFirestore).toList())
        .transform(logStreamErrors('[quotes] streamAll failed'));
  }

  Future<void> create({
    required String uid,
    required String customerName,
    required String customerEmail,
    required String title,
    required int quantity,
    required String details,
    String? packageId,
    String? itemId,
  }) async {
    appLogger.i('[quotes] create(uid=$uid, title=$title, qty=$quantity)');
    try {
      await _quotes.add({
        'customerId': uid,
        'customerName': customerName,
        if (customerEmail.isNotEmpty) 'customerEmail': customerEmail,
        'title': title,
        'packageId': ?packageId,
        'itemId': ?itemId,
        'quantity': quantity,
        'details': details,
        'status': QuoteStatus.newRequest.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      appLogger.e('[quotes] create failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  /// Staff: price a request (or re-price an unaccepted quote).
  Future<void> respond({
    required String quoteId,
    required String staffUid,
    required num quotedTotal,
    required String message,
    required DateTime validUntil,
  }) async {
    appLogger.i('[quotes] respond($quoteId, total=$quotedTotal)');
    await _quotes.doc(quoteId).update({
      'status': QuoteStatus.quoted.value,
      'quotedTotal': quotedTotal,
      'quoteMessage': message,
      'validUntil': Timestamp.fromDate(validUntil),
      'respondedBy': staffUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decline({
    required String quoteId,
    required String staffUid,
    required String message,
  }) async {
    appLogger.i('[quotes] decline($quoteId)');
    await _quotes.doc(quoteId).update({
      'status': QuoteStatus.declined.value,
      'quoteMessage': message,
      'respondedBy': staffUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Customer: withdraw an unpriced request or turn down a price.
  Future<void> customerClose(QuoteRequest quote) async {
    final next = quote.status == QuoteStatus.quoted
        ? QuoteStatus.rejected
        : QuoteStatus.cancelled;
    appLogger.i('[quotes] customerClose(${quote.id} -> ${next.value})');
    await _quotes.doc(quote.id).update({
      'status': next.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Customer: accept a price — the acceptQuote function creates the order
  /// at the quoted amount. Returns the new order id.
  Future<String> accept({
    required String quoteId,
    required String contactName,
    required String contactPhone,
    required String deliveryAddress,
    required String notes,
    required String paymentPlan,
  }) async {
    appLogger.i('[quotes] accept($quoteId, plan=$paymentPlan)');
    final result = await _functions.httpsCallable('acceptQuote').call({
      'quoteId': quoteId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'paymentPlan': paymentPlan,
    });
    return (result.data as Map)['orderId'] as String;
  }
}
