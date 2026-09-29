import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/order_model.dart';
import '../domain/order_status.dart';

class OrdersRepository {
  OrdersRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

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

  /// Every order — the Manager/Admin/Developer view. Grouping by
  /// status/lifecycle happens client-side rather than via more composite
  /// indexes.
  Stream<List<OrderModel>> streamAll() {
    appLogger.d('[orders] streamAll()');
    return _orders
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(OrderModel.fromFirestore).toList())
        .transform(
          logStreamErrors(
            '[orders] streamAll() failed — likely signed in as a role without isOrderStaff()',
          ),
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
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      appLogger.i(
        '[orders] placed ${data['orderId']} (${data['orderNumber']}) total=${data['total']}',
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
