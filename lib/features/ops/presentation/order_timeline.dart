import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting/currency.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../application/ops_providers.dart';
import '../data/ops_repository.dart';

/// Human-readable history of an order (status, payments, proof, QC,
/// delivery), newest first.
class OrderTimeline extends ConsumerWidget {
  const OrderTimeline({super.key, required this.order, this.staffView = false});

  final OrderModel order;

  /// Staff see who made each change.
  final bool staffView;

  static String describe(OrderEvent e) {
    String status(Object? v) =>
        OrderStatus.values
            .where((s) => s.name == v)
            .map((s) => s.label)
            .firstOrNull ??
        '$v';
    return switch (e.field) {
      'status' => 'Status: ${status(e.to)}',
      'paymentStatus' => 'Payment: ${PaymentStatus.fromName('${e.to}').label}',
      'amountPaid' =>
        'Payment received — ${currencyFormat.format((e.to as num? ?? 0) - (e.from as num? ?? 0))}',
      'refundedAmount' =>
        'Refund — ${currencyFormat.format((e.to as num? ?? 0) - (e.from as num? ?? 0))}',
      'assignedStaffId' =>
        e.to == null ? 'Delivery unassigned' : 'Assigned to a driver',
      'proofStatus' => 'Proof: ${ProofStatus.fromName('${e.to}').label}',
      'qcStatus' =>
        e.to == 'passed'
            ? 'Passed quality check'
            : e.to == 'failed'
            ? 'Sent back for rework after QC'
            : 'Quality check pending',
      'etims.status' =>
        e.to == 'submitted' ? 'Reported to KRA eTIMS' : 'KRA eTIMS: ${e.to}',
      'overdue' => e.to == true ? 'Payment overdue' : 'No longer overdue',
      _ => '${e.field}: ${e.to}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events =
        ref.watch(orderEventsProvider(order.id)).valueOrNull ?? const [];
    final fmt = DateFormat('d MMM, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final e in events)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 10),
                    minLeadingWidth: 12,
                    title: Text(describe(e)),
                    subtitle: Text(
                      staffView && e.by.isNotEmpty
                          ? '${fmt.format(e.at)} · ${e.by.startsWith('system')
                                ? 'automatic'
                                : e.by == order.customerId
                                ? 'customer'
                                : 'staff ${e.by.substring(0, e.by.length.clamp(0, 6))}'}'
                          : fmt.format(e.at),
                    ),
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle_outlined, size: 10),
                  minLeadingWidth: 12,
                  title: const Text('Order placed'),
                  subtitle: Text(fmt.format(order.createdAt)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown to the customer while their order is on its way (or ready to
/// collect): the secret code the driver needs to complete the handover.
class DeliveryCodeCard extends ConsumerWidget {
  const DeliveryCodeCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final relevant = [
      OrderStatus.readyForDelivery,
      OrderStatus.outForDelivery,
    ].contains(order.status);
    if (order.status == OrderStatus.completed &&
        order.proofOfDelivery.isNotEmpty) {
      final pod = order.proofOfDelivery;
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.verified_rounded, color: Colors.green),
          title: Text('Received by ${pod['recipientName'] ?? ''}'),
          subtitle: Text(
            pod['codeVerified'] == true
                ? 'Confirmed with your delivery code'
                : 'Confirmed with photo and signature',
          ),
        ),
      );
    }
    if (!relevant) return const SizedBox.shrink();
    final code = ref.watch(deliveryCodeProvider(order.id)).valueOrNull;
    if (code == null) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                order.isPickup
                    ? 'Show this code when you collect your order.'
                    : 'Give this code to the driver when your order arrives — only then will they hand it over.',
              ),
            ),
            const SizedBox(width: 12),
            Text(
              code,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
