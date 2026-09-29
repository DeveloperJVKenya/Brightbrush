import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Lifecycle of a quote. Customers create 'new', staff move it to 'quoted'
/// (with a price) or 'declined'; the customer then accepts (server-side,
/// becomes an Order), 'rejected's the price, or 'cancelled's the request.
/// Matches isValidQuoteStatus in firestore.rules.
enum QuoteStatus {
  newRequest('new', 'Awaiting price', Icons.hourglass_top_rounded),
  quoted('quoted', 'Price ready', Icons.request_quote_rounded),
  accepted('accepted', 'Accepted', Icons.check_circle_rounded),
  declined('declined', 'Declined by us', Icons.block_rounded),
  rejected('rejected', 'You declined', Icons.thumb_down_alt_outlined),
  cancelled('cancelled', 'Withdrawn', Icons.cancel_outlined);

  const QuoteStatus(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static QuoteStatus fromValue(String? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => QuoteStatus.newRequest,
  );

  bool get isOpen => this == newRequest || this == quoted;
}

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.title,
    required this.packageId,
    required this.itemId,
    required this.quantity,
    required this.details,
    required this.status,
    required this.quotedTotal,
    required this.quoteMessage,
    required this.validUntil,
    required this.orderId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String title;
  final String? packageId;
  final String? itemId;
  final int quantity;
  final String details;
  final QuoteStatus status;
  final num? quotedTotal;
  final String? quoteMessage;
  final DateTime? validUntil;
  final String? orderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);

  List<String> get searchFields => [title, customerName, details, id];

  factory QuoteRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return QuoteRequest(
      id: doc.id,
      customerId: d['customerId'] as String? ?? '',
      customerName: d['customerName'] as String? ?? '',
      customerEmail: d['customerEmail'] as String? ?? '',
      title: d['title'] as String? ?? '',
      packageId: d['packageId'] as String?,
      itemId: d['itemId'] as String?,
      quantity: (d['quantity'] as num?)?.toInt() ?? 1,
      details: d['details'] as String? ?? '',
      status: QuoteStatus.fromValue(d['status'] as String?),
      quotedTotal: d['quotedTotal'] as num?,
      quoteMessage: d['quoteMessage'] as String?,
      validUntil: (d['validUntil'] as Timestamp?)?.toDate(),
      orderId: d['orderId'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
