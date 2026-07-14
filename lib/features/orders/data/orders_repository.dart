import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/order_model.dart';
import '../domain/order_status.dart';

class OrdersRepository {
  OrdersRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  /// A customer's own orders, newest first.
  Stream<List<OrderModel>> streamForCustomer(String uid) {
    return _orders
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(OrderModel.fromFirestore).toList());
  }

  /// Every order — the Manager/Admin view. Grouping by status/lifecycle
  /// happens client-side rather than via more composite indexes.
  Stream<List<OrderModel>> streamAll() {
    return _orders.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(OrderModel.fromFirestore).toList(),
        );
  }

  Future<String> create(OrderModel order) async {
    final doc = await _orders.add(order.toFirestoreCreate());
    return doc.id;
  }

  Future<void> updateStatus(String orderId, OrderStatus status) {
    return _orders.doc(orderId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) {
    return _orders.doc(orderId).update({
      'paymentStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String orderId) {
    return _orders.doc(orderId).update({
      'status': OrderStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
