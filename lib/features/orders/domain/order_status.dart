import 'package:flutter/material.dart';

/// Full order pipeline. Customers can only ever cause 'pendingReview' (on
/// create) or the self-cancel transition into 'cancelled'; every other
/// step is staff-driven — mirrors firestore.rules exactly.
enum OrderStatus {
  pendingReview(label: 'Pending Review', icon: Icons.hourglass_top_rounded),
  confirmed(label: 'Confirmed', icon: Icons.fact_check_outlined),
  inProduction(label: 'In Production', icon: Icons.precision_manufacturing_outlined),
  readyForDelivery(label: 'Ready for Delivery', icon: Icons.inventory_2_outlined),
  outForDelivery(label: 'Out for Delivery', icon: Icons.local_shipping_outlined),
  completed(label: 'Completed', icon: Icons.check_circle_outline_rounded),
  cancelled(label: 'Cancelled', icon: Icons.cancel_outlined);

  const OrderStatus({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static OrderStatus fromName(String name) {
    return OrderStatus.values.firstWhere((s) => s.name == name, orElse: () => OrderStatus.pendingReview);
  }

  /// The pipeline in display order, excluding the terminal 'cancelled'
  /// branch — used to render a linear progress timeline.
  static const List<OrderStatus> pipeline = [
    OrderStatus.pendingReview,
    OrderStatus.confirmed,
    OrderStatus.inProduction,
    OrderStatus.readyForDelivery,
    OrderStatus.outForDelivery,
    OrderStatus.completed,
  ];

  bool get isTerminal => this == OrderStatus.completed || this == OrderStatus.cancelled;

  /// Admin's "Completed / Running / Upcoming" grouping.
  OrderLifecycleBucket get lifecycleBucket {
    return switch (this) {
      OrderStatus.completed => OrderLifecycleBucket.completed,
      OrderStatus.cancelled => OrderLifecycleBucket.cancelled,
      OrderStatus.pendingReview => OrderLifecycleBucket.upcoming,
      _ => OrderLifecycleBucket.running,
    };
  }
}

enum OrderLifecycleBucket { upcoming, running, completed, cancelled }

enum PaymentStatus {
  unpaid(label: 'Unpaid'),
  invoiced(label: 'Invoiced'),
  paid(label: 'Paid');

  const PaymentStatus({required this.label});

  final String label;

  static PaymentStatus fromName(String name) {
    return PaymentStatus.values.firstWhere((s) => s.name == name, orElse: () => PaymentStatus.unpaid);
  }
}
