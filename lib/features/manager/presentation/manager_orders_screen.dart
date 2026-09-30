import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/formatting/currency.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/order_status_timeline.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../../chat/order_chat.dart';
import '../../commerce/application/commerce_providers.dart';
import '../../commerce/data/commerce_repository.dart';
import '../../commerce/presentation/refund_dialog.dart';
import '../../customization/presentation/widgets/customization_summary.dart';
import '../../ops/presentation/delivery_completion_sheet.dart';
import '../../ops/presentation/order_timeline.dart';
import '../../ops/presentation/qc_dialog.dart';
import '../../payments/presentation/widgets/record_payment_dialog.dart';
import '../../proofs/presentation/proof_widgets.dart';
import '../../../shared/whatsapp.dart';
import 'widgets/order_status_filter_bar.dart';

final _managerOrdersSearchProvider = StateProvider<String>((ref) => '');
final _managerOrdersStatusFilterProvider = StateProvider<OrderStatus?>(
  (ref) => null,
);

class ManagerOrdersScreen extends ConsumerWidget {
  const ManagerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final query = ref.watch(_managerOrdersSearchProvider);
    final statusFilter = ref.watch(_managerOrdersStatusFilterProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Every order across all customers, live as customers place and staff progress them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: 'Search by customer, phone, order id, or item',
              onChanged: (v) =>
                  ref.read(_managerOrdersSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            OrderStatusFilterBar(
              selected: statusFilter,
              onSelected: (value) =>
                  ref.read(_managerOrdersStatusFilterProvider.notifier).state =
                      value,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(semanticsLabel: 'Loading'),
                ),
                error: (error, stack) {
                  appLogger.e(
                    '[orders] Failed to load orders',
                    error: error,
                    stackTrace: stack,
                  );
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Couldn\'t load orders',
                    message: friendlyError(error),
                    action: TextButton.icon(
                      onPressed: () => ref.invalidate(allOrdersProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  );
                },
                data: (orders) {
                  final statusFiltered = statusFilter == null
                      ? orders
                      : orders.where((o) => o.status == statusFilter).toList();
                  final filtered = filterBySearch(
                    statusFiltered,
                    query,
                    (o) => o.searchFields,
                  );
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: orders.isEmpty ? 'No orders yet' : 'No matches',
                      message: orders.isEmpty
                          ? 'Orders customers place from the catalog will show up here.'
                          : 'Try a different search or clear the status filter.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ManagerOrderRow(order: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerOrderRow extends ConsumerStatefulWidget {
  const _ManagerOrderRow({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_ManagerOrderRow> createState() => _ManagerOrderRowState();
}

class _ManagerOrderRowState extends ConsumerState<_ManagerOrderRow> {
  static final _date = DateFormat('MMM d, y · h:mm a');

  bool _busy = false;

  OrderModel get order => widget.order;

  static const _productionStages = {
    OrderStatus.inProduction,
    OrderStatus.readyForDelivery,
    OrderStatus.outForDelivery,
    OrderStatus.completed,
  };

  Future<void> _updateStatus(OrderStatus value) async {
    // Proof gate: firestore.rules reject this anyway; explain it up front.
    if (_productionStages.contains(value) &&
        !_productionStages.contains(order.status) &&
        order.proofBlocksProduction) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The customer hasn\'t approved a proof yet (${order.proofStatus.label.toLowerCase()}). Send one with "Proof".',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Deposit check: a warning, not a block — some clients are on credit.
    if (value == OrderStatus.inProduction && !order.depositCovered) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deposit not received'),
          content: Text(
            'Only ${currencyFormat.format(order.amountPaid)} of the ${currencyFormat.format(order.depositAmount)} deposit has been paid. Start production anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Wait'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start anyway'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).updateStatus(order.id, value);
    } catch (error, stack) {
      appLogger.e(
        '[orders] Failed to update status for order ${order.id}',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t update status: ${friendlyError(error)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Payment status is owned by the server-side ledger now: staff record
  /// money received (cash, bank, off-app M-Pesa) and see every gateway
  /// attempt here, rather than flipping a status by hand.
  Future<void> _openPayments() => showRecordPaymentDialog(context, order);

  Future<void> _onMenu(String action) async {
    switch (action) {
      case 'invoice':
        await openDocument(context, ref, DocumentKind.invoice, order.id);
      case 'whatsapp':
        await openWhatsApp(
          context,
          phone: order.contactPhone,
          message:
              'Hello ${order.contactName}, this is BrightBrush about your order ${order.displayNumber} (${order.status.label}). ',
        );
      case 'jobSheet':
        await openDocument(context, ref, DocumentKind.jobSheet, order.id);
      case 'qc':
        await showQualityCheckDialog(
          context,
          orderId: order.id,
          orderLabel: order.displayNumber,
        );
      case 'handover':
        await showDeliveryCompletionSheet(context, order);
      case 'history':
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: OrderTimeline(order: order, staffView: true),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      case 'refund':
        await showRefundDialog(context, order);
      case 'etims':
        setState(() => _busy = true);
        try {
          await ref.read(commerceRepositoryProvider).submitEtims(order.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invoice reported to KRA eTIMS'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(friendlyError(error)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Keeps the eTIMS status live for the 'Submit to KRA' menu item.
    final etimsOn = ref.watch(etimsEnabledProvider).valueOrNull ?? false;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.contactName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${order.contactPhone} · ${_date.format(order.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(order.total),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order.displayNumber} · ${order.items.map((i) => '${i.quantity}× ${i.name}').join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            // Production needs the full brief: colours, sizes, placements,
            // artwork and threads for every customised line.
            for (final item in order.items)
              if (item.customization != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: CustomizationSummary(config: item.customization!),
                ),
            const SizedBox(height: 12),
            OrderStatusTimeline(
              status: order.status,
              includeProofStep: order.requiresProof || order.proofVersion > 0,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<OrderStatus>(
                  value: order.status,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final status in OrderStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) _updateStatus(value);
                        },
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.payments_outlined, size: 16),
                  label: Text(
                    order.balanceDue > 0 && order.amountPaid > 0
                        ? '${order.paymentStatus.label} · ${currencyFormat.format(order.balanceDue)} due'
                        : 'Payment: ${order.paymentStatus.label}',
                  ),
                  selected: order.paymentStatus.name != 'unpaid',
                  onSelected: _busy ? null : (_) => _openPayments(),
                ),
                if (order.requiresProof || order.proofVersion > 0)
                  ActionChip(
                    avatar: Icon(
                      order.proofStatus == ProofStatus.approved
                          ? Icons.verified_rounded
                          : Icons.rate_review_outlined,
                      size: 16,
                    ),
                    label: Text('Proof: ${order.proofStatus.label}'),
                    onPressed: () => showSendProofDialog(context, order),
                  ),
                if (order.etimsStatus != 'none')
                  Chip(
                    avatar: Icon(
                      order.etimsStatus == 'submitted'
                          ? Icons.verified_outlined
                          : Icons.error_outline_rounded,
                      size: 16,
                    ),
                    label: Text('eTIMS: ${order.etimsStatus}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (order.overdue)
                  Chip(
                    avatar: const Icon(Icons.schedule_rounded, size: 16),
                    label: const Text('Overdue'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                OrderChatButton(
                  orderId: order.id,
                  orderLabel: order.displayNumber,
                  asStaff: true,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) => _onMenu(v),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'invoice',
                      child: Text('Invoice PDF'),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('History'),
                    ),
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Text('WhatsApp customer'),
                    ),
                    if (![
                      OrderStatus.pendingReview,
                      OrderStatus.cancelled,
                    ].contains(order.status))
                      const PopupMenuItem(
                        value: 'jobSheet',
                        child: Text('Print job sheet'),
                      ),
                    if ([
                      OrderStatus.inProduction,
                      OrderStatus.qualityCheck,
                    ].contains(order.status))
                      const PopupMenuItem(
                        value: 'qc',
                        child: Text('Quality check'),
                      ),
                    if (order.isPickup &&
                        order.status == OrderStatus.readyForDelivery)
                      const PopupMenuItem(
                        value: 'handover',
                        child: Text('Hand over (pickup)'),
                      ),
                    if (order.netPaid > 0)
                      const PopupMenuItem(
                        value: 'refund',
                        child: Text('Refund / cancel with fee'),
                      ),
                    if (etimsOn && order.etimsStatus != 'submitted')
                      const PopupMenuItem(
                        value: 'etims',
                        child: Text('Submit to KRA eTIMS'),
                      ),
                  ],
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
