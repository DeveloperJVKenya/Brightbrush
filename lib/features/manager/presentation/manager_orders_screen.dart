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
import 'widgets/order_status_filter_bar.dart';

final _managerOrdersSearchProvider = StateProvider<String>((ref) => '');
final _managerOrdersStatusFilterProvider = StateProvider<OrderStatus?>((ref) => null);

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
            Text('Orders', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Every order across all customers, live as customers place and staff progress them.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: 'Search by customer, phone, order id, or item',
              onChanged: (v) => ref.read(_managerOrdersSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            OrderStatusFilterBar(
              selected: statusFilter,
              onSelected: (value) => ref.read(_managerOrdersStatusFilterProvider.notifier).state = value,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  appLogger.e('[orders] Failed to load orders', error: error, stackTrace: stack);
                  return EmptyState(
                      icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: friendlyError(error));
                },
                data: (orders) {
                  final statusFiltered =
                      statusFilter == null ? orders : orders.where((o) => o.status == statusFilter).toList();
                  final filtered = filterBySearch(statusFiltered, query, (o) => o.searchFields);
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
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ManagerOrderRow(order: filtered[index]),
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

  Future<void> _updateStatus(OrderStatus value) async {
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).updateStatus(order.id, value);
    } catch (error, stack) {
      appLogger.e('[orders] Failed to update status for order ${order.id}', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t update status: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cyclePaymentStatus() async {
    final next = switch (order.paymentStatus) {
      PaymentStatus.unpaid => PaymentStatus.invoiced,
      PaymentStatus.invoiced => PaymentStatus.paid,
      PaymentStatus.paid => PaymentStatus.unpaid,
    };
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).updatePaymentStatus(order.id, next);
    } catch (error, stack) {
      appLogger.e('[orders] Failed to update payment status for order ${order.id}', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t update payment: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${order.contactPhone} · ${_date.format(order.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(order.total),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OrderStatusTimeline(status: order.status),
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
                      DropdownMenuItem(value: status, child: Text(status.label)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) _updateStatus(value);
                        },
                ),
                ChoiceChip(
                  label: Text('Payment: ${order.paymentStatus.label}'),
                  selected: order.paymentStatus.name != 'unpaid',
                  onSelected: _busy ? null : (_) => _cyclePaymentStatus(),
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
