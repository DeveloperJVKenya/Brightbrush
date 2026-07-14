import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/staggered_entrance.dart';
import '../../../shared/search/search_utils.dart';
import '../../orders/application/orders_providers.dart';
import 'widgets/order_card.dart';

final _myOrdersSearchProvider = StateProvider<String>((ref) => '');

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(myOrdersProvider);
    final query = ref.watch(_myOrdersSearchProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My orders', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Every order you\'ve placed, with live status as it moves through production.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: 'Search your orders',
              onChanged: (v) => ref.read(_myOrdersSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: '$error'),
                data: (orders) {
                  final filtered = filterBySearch(orders, query, (o) => o.searchFields);
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: orders.isEmpty ? 'No orders yet' : 'No matches',
                      message: orders.isEmpty
                          ? 'Orders you place from the catalog will show up here with live status.'
                          : 'Try a different search term.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return StaggeredEntrance(
                        index: index,
                        child: OrderCard(
                          order: order,
                          onTap: () => context.push('/customer/orders/${order.id}'),
                        ),
                      );
                    },
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
