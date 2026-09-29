import 'package:cloud_firestore/cloud_firestore.dart';

import '../../customization/domain/customization_pricing.dart';
import 'order_status.dart';

/// What an order line refers to: a catalog item, a seasonal package, a
/// staff-priced quote, or a customised (decorated) catalog item — see
/// functions/src/orders/order_writer.ts.
enum OrderLineKind { item, package, quote, custom }

class OrderLineItem {
  const OrderLineItem({
    this.kind = OrderLineKind.item,
    required this.itemId,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    this.storedLineTotal,
    this.customization,
    this.pricing = const {},
  });

  final OrderLineKind kind;
  final String itemId;
  final String name;
  final String category;
  final num unitPrice;
  final int quantity;

  /// Server-computed total for customised lines (setup fees and size
  /// surcharges mean it isn't unitPrice × quantity).
  final num? storedLineTotal;

  /// Colour, sizes, decorations and names for customised lines.
  final CustomLineConfig? customization;

  /// Server price breakdown (blankTotal, decorationTotal, setupFees...).
  final Map<String, num> pricing;

  num get lineTotal => storedLineTotal ?? unitPrice * quantity;

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    return OrderLineItem(
      kind: OrderLineKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => OrderLineKind.item,
      ),
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      unitPrice: map['unitPrice'] as num? ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      storedLineTotal: map['lineTotal'] as num?,
      customization: map['customization'] is Map
          ? CustomLineConfig.fromMap({
              ...Map<String, dynamic>.from(map['customization'] as Map),
              'itemId': map['itemId'],
            })
          : null,
      pricing: {
        for (final e in Map<String, dynamic>.from(
          (map['pricing'] as Map?) ?? const {},
        ).entries)
          if (e.value is num) e.key: e.value as num,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kind': kind.name,
      'itemId': itemId,
      'name': name,
      'category': category,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
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
    required this.assignedStaffId,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.createdAt,
    required this.updatedAt,
    this.orderNumber = '',
    this.deliveryFee = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.paymentPlan = 'full',
    num? depositAmount,
    this.amountPaid = 0,
    this.requiresProof = false,
    this.proofStatus = ProofStatus.notRequired,
    this.proofVersion = 0,
  }) : depositAmount = depositAmount ?? total;

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
  final String? assignedStaffId;
  final double? deliveryLat;
  final double? deliveryLng;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Human-friendly number (BB-000123) assigned by placeOrder/acceptQuote.
  /// Empty on orders created before server-side ordering existed.
  final String orderNumber;
  final num deliveryFee;
  final num taxRate;
  final num taxAmount;

  /// 'full' or 'deposit' — see [depositAmount].
  final String paymentPlan;

  /// What must be paid before production starts (equals [total] on a
  /// 'full' plan).
  final num depositAmount;

  /// Running total of successful payments, maintained only by the
  /// server-side payment ledger.
  final num amountPaid;

  /// Decorated orders need a customer-approved proof before production
  /// (enforced in firestore.rules; set by the proof functions).
  final bool requiresProof;
  final ProofStatus proofStatus;
  final int proofVersion;

  bool get proofBlocksProduction =>
      proofStatus != ProofStatus.notRequired &&
      proofStatus != ProofStatus.approved;

  /// Reference shown to customers and staff — the order number when there
  /// is one, else a short form of the document id.
  String get displayNumber => orderNumber.isNotEmpty
      ? orderNumber
      : '#${id.length > 6 ? id.substring(0, 6).toUpperCase() : id}';

  num get balanceDue => (total - amountPaid) < 0 ? 0 : total - amountPaid;

  bool get isDepositPlan => paymentPlan == 'deposit' && depositAmount < total;

  bool get depositCovered => amountPaid >= depositAmount;

  /// Money actually received on this order. Orders from before the payment
  /// ledger only carry a manual 'paid' flag, so those count in full.
  num get collectedAmount {
    if (amountPaid > 0) return amountPaid;
    return paymentStatus == PaymentStatus.paid ? total : 0;
  }

  bool get hasDeliveryCoordinates => deliveryLat != null && deliveryLng != null;

  int get itemCount =>
      items.fold(0, (runningTotal, item) => runningTotal + item.quantity);

  List<String> get searchFields => [
    orderNumber,
    contactName,
    contactPhone,
    id,
    ...items.map((i) => i.name),
  ];

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
          .map(
            (e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      subtotal: d['subtotal'] as num? ?? 0,
      total: d['total'] as num? ?? 0,
      status: OrderStatus.fromName(d['status'] as String? ?? 'pendingReview'),
      paymentStatus: PaymentStatus.fromName(
        d['paymentStatus'] as String? ?? 'unpaid',
      ),
      assignedStaffId: d['assignedStaffId'] as String?,
      deliveryLat: (d['deliveryLat'] as num?)?.toDouble(),
      deliveryLng: (d['deliveryLng'] as num?)?.toDouble(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      orderNumber: d['orderNumber'] as String? ?? '',
      deliveryFee: d['deliveryFee'] as num? ?? 0,
      taxRate: d['taxRate'] as num? ?? 0,
      taxAmount: d['taxAmount'] as num? ?? 0,
      paymentPlan: d['paymentPlan'] as String? ?? 'full',
      depositAmount: d['depositAmount'] as num?,
      amountPaid: d['amountPaid'] as num? ?? 0,
      requiresProof: d['requiresProof'] as bool? ?? false,
      proofStatus: ProofStatus.fromName(d['proofStatus'] as String?),
      proofVersion: (d['proofVersion'] as num?)?.toInt() ?? 0,
    );
  }
}
