import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting/currency.dart';
import '../../orders/domain/order_model.dart';
import '../../payments/application/payments_providers.dart';
import '../../payments/domain/payment_models.dart';
import '../application/commerce_providers.dart';
import '../data/commerce_repository.dart';

/// Invoice, one receipt per payment, and credit notes for refunds — each a
/// server-generated PDF the customer (or staff) can save, print or share.
class OrderDocumentsPanel extends ConsumerWidget {
  const OrderDocumentsPanel({
    super.key,
    required this.order,
    this.asStaff = false,
  });

  final OrderModel order;
  final bool asStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final payments =
        ref
            .watch(orderPaymentsProvider((orderId: order.id, asStaff: asStaff)))
            .valueOrNull
            ?.where((p) => p.status == PaymentState.succeeded)
            .toList() ??
        const <PaymentRecord>[];
    final refunds =
        ref
            .watch(orderRefundsProvider((orderId: order.id, asStaff: asStaff)))
            .valueOrNull ??
        const <RefundRecord>[];
    final date = DateFormat('d MMM y');
    final etimsStatus = order.etimsStatus;

    Widget tile(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) => ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.download_rounded),
      onTap: onTap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              tile(
                Icons.receipt_long_outlined,
                'Invoice ${order.invoiceNumber.isEmpty ? order.displayNumber : order.invoiceNumber}',
                [
                  currencyFormat.format(order.total),
                  if (etimsStatus == 'submitted') 'KRA eTIMS verified',
                ].join(' · '),
                () =>
                    openDocument(context, ref, DocumentKind.invoice, order.id),
              ),
              for (final p in payments)
                tile(
                  Icons.payments_outlined,
                  'Receipt ${p.receiptNumber ?? ''}'.trim(),
                  '${p.gatewayLabel} · ${currencyFormat.format(p.amount)} · ${date.format(p.createdAt)}',
                  () => openDocument(context, ref, DocumentKind.receipt, p.id),
                ),
              for (final r in refunds)
                tile(
                  Icons.undo_rounded,
                  'Credit note ${r.creditNoteNumber}',
                  '${currencyFormat.format(r.amount)} refunded · ${r.reason}',
                  () =>
                      openDocument(context, ref, DocumentKind.creditNote, r.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
