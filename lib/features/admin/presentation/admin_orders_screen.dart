import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allOrdersProvider);
    final theme = Theme.of(context);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: '$error'),
      data: (orders) {
        final byBucket = <OrderLifecycleBucket, List<OrderModel>>{
          for (final bucket in OrderLifecycleBucket.values) bucket: [],
        };
        for (final order in orders) {
          byBucket[order.status.lifecycleBucket]!.add(order);
        }
        final completedRevenue = byBucket[OrderLifecycleBucket.completed]!.fold<num>(0, (s, o) => s + o.total);

        return DefaultTabController(
          length: 4,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Orders overview',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Completed, running, and upcoming orders across the whole company.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        upcoming: byBucket[OrderLifecycleBucket.upcoming]!.length,
                        running: byBucket[OrderLifecycleBucket.running]!.length,
                        completed: byBucket[OrderLifecycleBucket.completed]!.length,
                        completedRevenue: completedRevenue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  tabs: [
                    Tab(text: 'Upcoming (${byBucket[OrderLifecycleBucket.upcoming]!.length})'),
                    Tab(text: 'Running (${byBucket[OrderLifecycleBucket.running]!.length})'),
                    Tab(text: 'Completed (${byBucket[OrderLifecycleBucket.completed]!.length})'),
                    Tab(text: 'Cancelled (${byBucket[OrderLifecycleBucket.cancelled]!.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OrdersList(orders: byBucket[OrderLifecycleBucket.upcoming]!),
                      _OrdersList(orders: byBucket[OrderLifecycleBucket.running]!),
                      _OrdersList(orders: byBucket[OrderLifecycleBucket.completed]!),
                      _OrdersList(orders: byBucket[OrderLifecycleBucket.cancelled]!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.upcoming,
    required this.running,
    required this.completed,
    required this.completedRevenue,
  });

  final int upcoming;
  final int running;
  final int completed;
  final num completedRevenue;

  static final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(label: 'Upcoming', value: '$upcoming', icon: Icons.hourglass_top_rounded),
            _StatCard(label: 'Running', value: '$running', icon: Icons.precision_manufacturing_outlined),
            _StatCard(label: 'Completed', value: '$completed', icon: Icons.check_circle_outline_rounded),
            _StatCard(
              label: 'Completed revenue',
              value: _currency.format(completedRevenue),
              icon: Icons.account_balance_wallet_outlined,
              accent: true,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.accent = false});

  final String label;
  final String value;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent
                  ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders});

  final List<OrderModel> orders;

  static final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  static final _date = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nothing here',
        message: 'No orders currently in this stage.',
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(order.contactName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${order.itemCount} item(s) · ${_date.format(order.createdAt)} · ${order.status.label}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(order.total),
                  style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                ),
                Text(order.paymentStatus.label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
