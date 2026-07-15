import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/horizontal_bar_chart.dart';
import '../../auth/domain/user_profile.dart';
import '../../catalog/domain/catalog_category.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_status.dart';

/// Analytics across sales, production and delivery — computed client-side
/// from the same `orders` stream every other role screen already reads,
/// rather than a separate aggregation pipeline (fine at this pilot's volume).
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final staffAsync = ref.watch(deliveryStaffDirectoryProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load reports', message: '$error'),
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'Nothing to report yet',
            message: 'Once orders start coming in, sales, production and delivery analytics show up here.',
          );
        }

        final live = orders.where((o) => o.status != OrderStatus.cancelled).toList();
        final totalValue = live.fold<num>(0, (s, o) => s + o.total);
        final collected = live.where((o) => o.paymentStatus.name == 'paid').fold<num>(0, (s, o) => s + o.total);
        final outstanding = totalValue - collected;

        final statusCounts = <OrderStatus, int>{for (final s in OrderStatus.values) s: 0};
        for (final o in orders) {
          statusCounts[o.status] = statusCounts[o.status]! + 1;
        }

        final categoryRevenue = <CatalogCategory, num>{};
        for (final o in live) {
          for (final item in o.items) {
            final category = CatalogCategory.fromName(item.category);
            categoryRevenue[category] = (categoryRevenue[category] ?? 0) + item.lineTotal;
          }
        }
        final topCategories = categoryRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        final staff = staffAsync.valueOrNull ?? const <UserProfile>[];
        final deliveryPerformance = staff
            .map((member) {
              final completed = orders.where((o) => o.assignedStaffId == member.uid && o.status == OrderStatus.completed).length;
              return MapEntry(member.displayName.isEmpty ? member.email : member.displayName, completed);
            })
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final production = statusCounts[OrderStatus.confirmed]! + statusCounts[OrderStatus.inProduction]!;
        final backlog = statusCounts[OrderStatus.readyForDelivery]!;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                          Text('Reports', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Sales, production and delivery analytics across the whole company.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copySummary(
                        context,
                        totalValue: totalValue,
                        collected: collected,
                        outstanding: outstanding,
                        statusCounts: statusCounts,
                        topCategories: topCategories,
                        deliveryPerformance: deliveryPerformance,
                      ),
                      icon: const Icon(Icons.ios_share_outlined, size: 18),
                      label: const Text('Copy summary'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: 'Total order value', value: currencyFormat.format(totalValue), icon: Icons.receipt_long_outlined),
                    _MetricCard(
                      label: 'Collected',
                      value: currencyFormat.format(collected),
                      icon: Icons.account_balance_wallet_outlined,
                      accent: true,
                    ),
                    _MetricCard(label: 'Outstanding', value: currencyFormat.format(outstanding), icon: Icons.pending_actions_outlined),
                    _MetricCard(label: 'In production', value: '$production', icon: Icons.precision_manufacturing_outlined),
                    _MetricCard(label: 'Ready-for-delivery backlog', value: '$backlog', icon: Icons.inventory_2_outlined),
                  ],
                ),
                const SizedBox(height: 28),
                _ReportSection(
                  title: 'Orders by status',
                  child: HorizontalBarChart(
                    data: [
                      for (final status in OrderStatus.values)
                        BarDatum(label: status.label, value: statusCounts[status]!, valueLabel: '${statusCounts[status]}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _ReportSection(
                  title: 'Top categories by revenue',
                  child: topCategories.isEmpty
                      ? Text('No sales yet.', style: theme.textTheme.bodyMedium)
                      : HorizontalBarChart(
                          data: [
                            for (final entry in topCategories.take(6))
                              BarDatum(label: entry.key.label, value: entry.value, valueLabel: currencyFormat.format(entry.value)),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                _ReportSection(
                  title: 'Delivery performance',
                  child: deliveryPerformance.isEmpty
                      ? Text('No completed deliveries yet.', style: theme.textTheme.bodyMedium)
                      : HorizontalBarChart(
                          data: [
                            for (final entry in deliveryPerformance)
                              BarDatum(label: entry.key, value: entry.value, valueLabel: '${entry.value} delivered'),
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

  void _copySummary(
    BuildContext context, {
    required num totalValue,
    required num collected,
    required num outstanding,
    required Map<OrderStatus, int> statusCounts,
    required List<MapEntry<CatalogCategory, num>> topCategories,
    required List<MapEntry<String, int>> deliveryPerformance,
  }) {
    final buffer = StringBuffer()
      ..writeln('BrightBrush Creations — Report summary (${DateTime.now().toLocal()})')
      ..writeln()
      ..writeln('Total order value: ${currencyFormat.format(totalValue)}')
      ..writeln('Collected: ${currencyFormat.format(collected)}')
      ..writeln('Outstanding: ${currencyFormat.format(outstanding)}')
      ..writeln()
      ..writeln('Orders by status:');
    for (final status in OrderStatus.values) {
      buffer.writeln('  ${status.label}: ${statusCounts[status]}');
    }
    buffer.writeln();
    buffer.writeln('Top categories by revenue:');
    for (final entry in topCategories.take(6)) {
      buffer.writeln('  ${entry.key.label}: ${currencyFormat.format(entry.value)}');
    }
    buffer.writeln();
    buffer.writeln('Delivery performance:');
    for (final entry in deliveryPerformance) {
      buffer.writeln('  ${entry.key}: ${entry.value} delivered');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report summary copied to clipboard'), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, this.accent = false});

  final String label;
  final String value;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
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
              color: accent ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
