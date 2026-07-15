import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';

/// System Manager's landing screen: what needs attention today, at a
/// glance, plus a shortcut into every other Manager section.
class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final catalogAsync = ref.watch(allCatalogItemsProvider);
    final packagesAsync = ref.watch(allPackagesProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load dashboard', message: '$error'),
      data: (orders) {
        final now = DateTime.now();
        final newToday = orders
            .where((o) => o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day)
            .length;
        final pendingReview = orders.where((o) => o.status == OrderStatus.pendingReview).toList();
        final production = orders.where((o) => o.status == OrderStatus.confirmed || o.status == OrderStatus.inProduction).length;
        final readyBacklog = orders.where((o) => o.status == OrderStatus.readyForDelivery).length;
        final activeCatalogCount = catalogAsync.valueOrNull?.where((i) => i.isActive).length ?? 0;
        final activePackagesCount = packagesAsync.valueOrNull?.where((p) => p.isActive).length ?? 0;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Today\'s new orders, what\'s in production, and quick access to every section.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatCard(label: 'New orders today', value: '$newToday', icon: Icons.hourglass_top_rounded),
                    StatCard(
                      label: 'Awaiting review',
                      value: '${pendingReview.length}',
                      icon: Icons.rate_review_outlined,
                      accent: pendingReview.isNotEmpty,
                    ),
                    StatCard(label: 'In production', value: '$production', icon: Icons.precision_manufacturing_outlined),
                    StatCard(label: 'Ready-for-delivery backlog', value: '$readyBacklog', icon: Icons.inventory_2_outlined),
                    StatCard(label: 'Active catalog items', value: '$activeCatalogCount', icon: Icons.checkroom_outlined),
                    StatCard(label: 'Active packages', value: '$activePackagesCount', icon: Icons.card_giftcard_outlined),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Needs review', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (pendingReview.isEmpty)
                  const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Nothing waiting',
                    message: 'Every incoming order has been reviewed.',
                  )
                else
                  Column(
                    children: [
                      for (final order in pendingReview.take(5)) ...[
                        _PendingOrderRow(order: order),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                const SizedBox(height: 28),
                Text('Jump to', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickLink(label: 'Orders', icon: Icons.list_alt_outlined, onTap: () => context.go('/manager/orders')),
                    _QuickLink(label: 'Catalog', icon: Icons.checkroom_outlined, onTap: () => context.go('/manager/catalog')),
                    _QuickLink(label: 'Packages', icon: Icons.card_giftcard_outlined, onTap: () => context.go('/manager/packages')),
                    _QuickLink(label: 'Staff Assignment', icon: Icons.groups_2_outlined, onTap: () => context.go('/manager/staff')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingOrderRow extends StatelessWidget {
  const _PendingOrderRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.hourglass_top_rounded),
        title: Text(order.contactName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${order.itemCount} item(s) · ${order.contactPhone}'),
        trailing: Text(
          currencyFormat.format(order.total),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
        ),
        onTap: () => GoRouter.of(context).go('/manager/orders'),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.colorScheme.outlineVariant)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
