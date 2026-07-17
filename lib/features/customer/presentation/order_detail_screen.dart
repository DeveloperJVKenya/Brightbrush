import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatting/currency.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timeline.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('Order details'),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          appLogger.e('[orders] Failed to load order detail', error: error, stackTrace: stack);
          return EmptyState(icon: Icons.cloud_off_rounded, title: 'Failed to load', message: friendlyError(error));
        },
        data: (orders) {
          final matches = orders.where((o) => o.id == orderId);
          final order = matches.isEmpty ? null : matches.first;
          if (order == null) {
            return const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Order not found',
              message: 'It may have been removed.',
            );
          }
          return _OrderDetailBody(order: order);
        },
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: OrderStatusTimeline(status: order.status),
          ),
        ),
        const SizedBox(height: 16),
        Text('Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final item in order.items) ...[
                ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} × ${currencyFormat.format(item.unitPrice)}'),
                  trailing: Text(
                    currencyFormat.format(item.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (item != order.items.last) const Divider(height: 1),
              ],
              const Divider(height: 1),
              ListTile(
                title: const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(
                  currencyFormat.format(order.total),
                  style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Delivery', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(icon: Icons.person_outline, label: order.contactName),
                _InfoRow(icon: Icons.call_outlined, label: order.contactPhone),
                _InfoRow(icon: Icons.location_on_outlined, label: order.deliveryAddress),
                if (order.notes.isNotEmpty) _InfoRow(icon: Icons.notes_rounded, label: order.notes),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Payment: ${order.paymentStatus.label}',
                ),
              ],
            ),
          ),
        ),
        if (order.status == OrderStatus.pendingReview) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel this order?'),
                  content: const Text('This can\'t be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order')),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(ordersRepositoryProvider).cancel(order.id);
              }
            },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel order'),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
