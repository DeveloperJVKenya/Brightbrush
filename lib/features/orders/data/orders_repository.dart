import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../../../core/monitoring/monitoring.dart';
import '../domain/order_model.dart';
import '../domain/order_status.dart';

class OrdersRepository {
  OrdersRepository(this._db, this._functions, this._currentUid);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  /// firestore.rules require every client order update to name its author
  /// (lastUpdatedBy == auth uid) for the order timeline and audit log.
  final String? Function() _currentUid;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('Orders');

  /// A customer's own orders, newest first.
  Stream<List<OrderModel>> streamForCustomer(String uid) {
    appLogger.d('[orders] streamForCustomer(uid=$uid)');
    return _orders
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(OrderModel.fromFirestore).toList())
        .transform(
          logStreamErrors(
            '[orders] streamForCustomer(uid=$uid) failed — check firestore.rules customerId ownership match',
          ),
        );
  }

  /// How far back the staff working set reaches for finished orders.
  /// Older ones live in the searchable archive ([searchArchive]).
  static const recentDays = 120;

  /// The Manager/Admin/Developer working set, newest first: every open
  /// order (any age), completed orders still owing money (any age), and
  /// everything from the last [recentDays] days. This stays small no
  /// matter how many years of history pile up, unlike streaming the whole
  /// collection. Reports over all time read the Stats counters instead.
  Stream<List<OrderModel>> streamAll() {
    appLogger.d('[orders] streamAll() — open + owing + last $recentDays days');
    final open = OrderStatus.values
        .where((s) => !s.isTerminal)
        .map((s) => s.name)
        .toList();
    final since = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: recentDays)),
    );
    final queries = <Query<Map<String, dynamic>>>[
      _orders.where('status', whereIn: open),
      _orders
          .where('status', isEqualTo: OrderStatus.completed.name)
          .where(
            'paymentStatus',
            whereIn: ['unpaid', 'invoiced', 'partiallyPaid'],
          ),
      _orders
          .where('createdAt', isGreaterThanOrEqualTo: since)
          .orderBy('createdAt', descending: true),
    ];
    return _mergeQueries(queries).transform(
      logStreamErrors(
        '[orders] streamAll() failed — likely signed in as a role without isOrderStaff()',
      ),
    );
  }

  /// Live union of several queries, de-duplicated by id, newest first.
  Stream<List<OrderModel>> _mergeQueries(
    List<Query<Map<String, dynamic>>> queries,
  ) {
    late final StreamController<List<OrderModel>> controller;
    final latest = List<Map<String, OrderModel>?>.filled(queries.length, null);
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    void emit() {
      if (latest.any((m) => m == null)) return;
      final byId = <String, OrderModel>{};
      for (final m in latest) {
        byId.addAll(m!);
      }
      final list = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(list);
    }

    controller = StreamController<List<OrderModel>>(
      onListen: () {
        for (var i = 0; i < queries.length; i++) {
          subs.add(
            queries[i].snapshots().listen((snap) {
              latest[i] = {
                for (final d in snap.docs) d.id: OrderModel.fromFirestore(d),
              };
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// The full order history, searched by order number, customer name,
  /// phone or email (Orders.searchKeywords, kept up to date by the
  /// indexOrderSearch function). Pass the returned next cursor as [after]
  /// for the following page; it is null on the last page.
  Future<
    ({List<OrderModel> orders, DocumentSnapshot<Map<String, dynamic>>? next})
  >
  searchArchive({
    String query = '',
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 30,
  }) async {
    final key = archiveSearchKey(query);
    Query<Map<String, dynamic>> q = _orders;
    if (key.isNotEmpty) q = q.where('searchKeywords', arrayContains: key);
    q = q.orderBy('createdAt', descending: true).limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.get();
    return (
      orders: snap.docs.map(OrderModel.fromFirestore).toList(),
      next: snap.docs.length < limit ? null : snap.docs.last,
    );
  }

  /// Places an order from the signed-in customer's saved cart. Pricing,
  /// MOQ checks, VAT, delivery and the deposit are all computed by the
  /// placeOrder Cloud Function — the client only supplies contact details
  /// and the payment plan. Returns the new order's id.
  Future<String> placeFromCart({
    required String contactName,
    required String contactPhone,
    required String deliveryAddress,
    required String notes,
    required String paymentPlan,
    String deliveryMethod = 'delivery',
    String? deliveryZoneId,
    String couponCode = '',
    double? deliveryLat,
    double? deliveryLng,
    int redeemPoints = 0,
  }) async {
    appLogger.i('[orders] placeFromCart(plan=$paymentPlan, $deliveryMethod)');
    try {
      final result = await _functions.httpsCallable('placeOrder').call({
        'contactName': contactName,
        'contactPhone': contactPhone,
        'deliveryAddress': deliveryAddress,
        'notes': notes,
        'paymentPlan': paymentPlan,
        'deliveryMethod': deliveryMethod,
        'deliveryZoneId': ?deliveryZoneId,
        if (couponCode.isNotEmpty) 'couponCode': couponCode,
        'deliveryLat': ?deliveryLat,
        'deliveryLng': ?deliveryLng,
        if (redeemPoints > 0) 'redeemPoints': redeemPoints,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      appLogger.i(
        '[orders] placed ${data['orderId']} (${data['orderNumber']}) total=${data['total']}',
      );
      Monitoring.purchase(
        orderId: data['orderId'] as String,
        value: (data['total'] as num?) ?? 0,
      );
      return data['orderId'] as String;
    } catch (error, stack) {
      appLogger.e(
        '[orders] placeFromCart failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> updateStatus(String orderId, OrderStatus status) {
    appLogger.i('[orders] updateStatus($orderId -> ${status.name})');
    return _orders
        .doc(orderId)
        .update({
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _currentUid(),
        })
        .catchError((error, stack) {
          appLogger.e(
            '[orders] updateStatus($orderId) failed',
            error: error,
            stackTrace: stack,
          );
          throw error;
        });
  }

  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) {
    appLogger.i('[orders] updatePaymentStatus($orderId -> ${status.name})');
    return _orders
        .doc(orderId)
        .update({
          'paymentStatus': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _currentUid(),
        })
        .catchError((error, stack) {
          appLogger.e(
            '[orders] updatePaymentStatus($orderId) failed',
            error: error,
            stackTrace: stack,
          );
          throw error;
        });
  }

  Future<void> cancel(String orderId) {
    appLogger.i('[orders] cancel($orderId)');
    return _orders
        .doc(orderId)
        .update({
          'status': OrderStatus.cancelled.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _currentUid(),
        })
        .catchError((error, stack) {
          appLogger.e(
            '[orders] cancel($orderId) failed',
            error: error,
            stackTrace: stack,
          );
          throw error;
        });
  }

  /// Delivery staff claims an unassigned, ready-for-delivery order (or a
  /// Manager/Admin/Developer push-assigns it to a specific staff member) —
  /// sets both the assignment and the status move in one write, matching
  /// the single staff-transition path firestore.rules allows.
  Future<void> claimForDelivery(String orderId, {required String staffUid}) {
    appLogger.i('[orders] claimForDelivery($orderId, staffUid=$staffUid)');
    return _orders
        .doc(orderId)
        .update({
          'status': OrderStatus.outForDelivery.name,
          'assignedStaffId': staffUid,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _currentUid(),
        })
        .catchError((error, stack) {
          appLogger.e(
            '[orders] claimForDelivery($orderId, staffUid=$staffUid) failed',
            error: error,
            stackTrace: stack,
          );
          throw error;
        });
  }

  Future<void> markDelivered(String orderId) {
    appLogger.i('[orders] markDelivered($orderId)');
    return _orders
        .doc(orderId)
        .update({
          'status': OrderStatus.completed.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _currentUid(),
        })
        .catchError((error, stack) {
          appLogger.e(
            '[orders] markDelivered($orderId) failed',
            error: error,
            stackTrace: stack,
          );
          throw error;
        });
  }

  Future<void> setDeliveryCoordinates(
    String orderId, {
    required double lat,
    required double lng,
  }) {
    appLogger.d(
      '[orders] setDeliveryCoordinates($orderId, lat=$lat, lng=$lng)',
    );
    return _orders
        .doc(orderId)
        .update({
          'deliveryLat': lat,
          'deliveryLng': lng,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': _currentUid(),
        })
        .catchError((error, stack) {
          appLogger.e(
            '[orders] setDeliveryCoordinates($orderId) failed',
            error: error,
            stackTrace: stack,
          );
          throw error;
        });
  }
}

/// The one keyword to look up for a search box entry — mirrors
/// searchKeywords() in functions/src/platform/platform.ts: words are split
/// on anything that isn't a letter or digit and indexed as 2–15 character
/// prefixes; phone numbers also by their last 9 digits (so 07…, 2547… and
/// +2547… all match). The longest word wins as the most selective.
String archiveSearchKey(String query) {
  final lower = query.toLowerCase().trim();
  final digits = lower.replaceAll(RegExp(r'[^0-9]'), '');
  final looksLikePhone = RegExp(r'^[0-9+\s()-]+$').hasMatch(lower);
  if (looksLikePhone && digits.length >= 9) {
    return digits.substring(digits.length - 9);
  }
  final words =
      lower.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 2).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (words.isEmpty) return '';
  final w = words.first;
  return w.length > 15 ? w.substring(0, 15) : w;
}
