import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting/currency.dart';
import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';

final _historySearchProvider = StateProvider<String>((ref) => '');

/// Archive of completed and cancelled jobs — reference for reprints and
/// client history lookups. Read-only: status changes happen from the
/// Orders screen while a job is still in flight.
class ManagerHistoryScreen extends ConsumerWidget {
  const ManagerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final query = ref.watch(_historySearchProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service history', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Completed and cancelled jobs, for reference and reprints.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: 'Search by customer, phone, order id, or item',
              onChanged: (v) => ref.read(_historySearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load history', message: '$error'),
                data: (orders) {
                  final done = orders
                      .where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled)
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  final filtered = filterBySearch(done, query, (o) => o.searchFields);
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: done.isEmpty ? 'Nothing archived yet' : 'No matches',
                      message: done.isEmpty
                          ? 'Completed and cancelled orders will show up here.'
                          : 'Try a different search term.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _HistoryRow(order: filtered[index]),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order});

  final OrderModel order;

  static final _date = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = order.status == OrderStatus.completed;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
          color: completed ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
        title: Text(order.contactName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${order.items.map((i) => '${i.quantity}× ${i.name}').join(', ')}\n${_date.format(order.updatedAt)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(order.total),
              style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            Text(order.status.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
