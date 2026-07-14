import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_status.dart';

class OrderLineItem {
  const OrderLineItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.quantity,
  });

  final String itemId;
  final String name;
  final String category;
  final num unitPrice;
  final int quantity;

  num get lineTotal => unitPrice * quantity;

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    return OrderLineItem(
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      unitPrice: map['unitPrice'] as num? ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'itemId': itemId, 'name': name, 'category': category, 'unitPrice': unitPrice, 'quantity': quantity};
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.customerId,
    required this.contactName,
    required this.contactPhone,
    required this.deliveryAddress,
    required this.notes,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String contactName;
  final String contactPhone;
  final String deliveryAddress;
  final String notes;
  final List<OrderLineItem> items;
  final num subtotal;
  final num total;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get itemCount => items.fold(0, (runningTotal, item) => runningTotal + item.quantity);

  List<String> get searchFields => [contactName, contactPhone, id, ...items.map((i) => i.name)];

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return OrderModel(
      id: doc.id,
      customerId: d['customerId'] as String? ?? '',
      contactName: d['contactName'] as String? ?? '',
      contactPhone: d['contactPhone'] as String? ?? '',
      deliveryAddress: d['deliveryAddress'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      items: (d['items'] as List? ?? [])
          .map((e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: d['subtotal'] as num? ?? 0,
      total: d['total'] as num? ?? 0,
      status: OrderStatus.fromName(d['status'] as String? ?? 'pendingReview'),
      paymentStatus: PaymentStatus.fromName(d['paymentStatus'] as String? ?? 'unpaid'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      'customerId': customerId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'deliveryAddress': deliveryAddress,
      if (notes.isNotEmpty) 'notes': notes,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'total': total,
      'status': OrderStatus.pendingReview.name,
      'paymentStatus': PaymentStatus.unpaid.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
