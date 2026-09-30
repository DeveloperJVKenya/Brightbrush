import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../financials/application/financials_providers.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_status.dart';
import '../../reports/order_stats.dart';

/// Admin/CEO's landing screen: revenue, real P&L (revenue collected against
/// logged Expenses — same computation as the Financials screen), and order
/// pipeline at a glance, plus a shortcut into every other Admin section.
class AdminExecutiveDashboardScreen extends ConsumerWidget {
  const AdminExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final expensesAsync = ref.watch(allExpensesProvider);

    if (ordersAsync.isLoading || expensesAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading'),
      );
    }
    if (ordersAsync.hasError) {
      appLogger.e(
        '[dashboard] Failed to load orders',
        error: ordersAsync.error,
        stackTrace: ordersAsync.stackTrace,
      );
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load dashboard',
        message: friendlyError(ordersAsync.error!),
        action: TextButton.icon(
          onPressed: () => ref.invalidate(allOrdersProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }
    if (expensesAsync.hasError) {
      appLogger.e(
        '[dashboard] Failed to load expenses',
        error: expensesAsync.error,
        stackTrace: expensesAsync.stackTrace,
      );
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load dashboard',
        message: friendlyError(expensesAsync.error!),
        action: TextButton.icon(
          onPressed: () => ref.invalidate(allExpensesProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }

    final orders = ordersAsync.requireValue;
    final expenses = expensesAsync.requireValue;

    final byBucket = <OrderLifecycleBucket, int>{
      for (final bucket in OrderLifecycleBucket.values) bucket: 0,
    };
    for (final order in orders) {
      byBucket[order.status.lifecycleBucket] =
          byBucket[order.status.lifecycleBucket]! + 1;
    }

    final live = orders
        .where((o) => o.status != OrderStatus.cancelled)
        .toList();
    final totalValue = live.fold<num>(0, (s, o) => s + o.total);
    final collected = live
        // Deposits and part-payments count as collected money.
        .fold<num>(0, (s, o) => s + o.collectedAmount);
    final outstanding = totalValue - collected;
    final totalExpenses = expenses.fold<num>(0, (s, e) => s + e.amount);
    final net = collected - totalExpenses;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Executive dashboard',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recent business (open orders plus the last 120 days) and all-time totals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatCard(
                  label: 'Total order value',
                  value: currencyFormat.format(totalValue),
                  icon: Icons.receipt_long_outlined,
                  hint: 'Sum of every non-cancelled order\'s total.',
                ),
                StatCard(
                  label: 'Collected',
                  value: currencyFormat.format(collected),
                  icon: Icons.account_balance_wallet_outlined,
                  accent: true,
                  hint:
                      'Of the total order value, how much has actually been marked paid.',
                ),
                StatCard(
                  label: 'Outstanding',
                  value: currencyFormat.format(outstanding),
                  icon: Icons.pending_actions_outlined,
                  hint:
                      'Total order value minus what\'s been collected — still owed.',
                ),
                StatCard(
                  label: 'Net (after expenses)',
                  value: currencyFormat.format(net),
                  icon: Icons.trending_up_rounded,
                  hint:
                      'Collected revenue minus every logged expense — see Financials for the breakdown.',
                ),
              ],
            ),
            const SizedBox(height: 28),
            const AllTimeStatsSection(canRecount: true),
            const SizedBox(height: 28),
            Text(
              'Order pipeline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatCard(
                  label: 'Upcoming',
                  value: '${byBucket[OrderLifecycleBucket.upcoming]}',
                  icon: Icons.hourglass_top_rounded,
                  hint:
                      'Orders not yet in production (pending review or confirmed).',
                ),
                StatCard(
                  label: 'Running',
                  value: '${byBucket[OrderLifecycleBucket.running]}',
                  icon: Icons.precision_manufacturing_outlined,
                  hint: 'Orders currently in production or out for delivery.',
                ),
                StatCard(
                  label: 'Completed',
                  value: '${byBucket[OrderLifecycleBucket.completed]}',
                  icon: Icons.check_circle_outline_rounded,
                  hint: 'Orders delivered and closed out.',
                ),
                StatCard(
                  label: 'Cancelled',
                  value: '${byBucket[OrderLifecycleBucket.cancelled]}',
                  icon: Icons.cancel_outlined,
                  hint: 'Orders cancelled by the customer or staff.',
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Jump to',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickLink(
                  label: 'Orders Overview',
                  icon: Icons.list_alt_outlined,
                  onTap: () => context.go('/admin/orders'),
                ),
                _QuickLink(
                  label: 'Deliveries',
                  icon: Icons.local_shipping_outlined,
                  onTap: () => context.go('/admin/deliveries'),
                ),
                _QuickLink(
                  label: 'Reports',
                  icon: Icons.bar_chart_outlined,
                  onTap: () => context.go('/admin/reports'),
                ),
                _QuickLink(
                  label: 'Role Management',
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: () => context.go('/admin/settings'),
                ),
                _QuickLink(
                  label: 'Support Inbox',
                  icon: Icons.support_agent_outlined,
                  onTap: () => context.go('/admin/support'),
                ),
                _QuickLink(
                  label: 'Guide Editor',
                  icon: Icons.menu_book_outlined,
                  onTap: () => context.go('/admin/guide-editor'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
