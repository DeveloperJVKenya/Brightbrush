import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/staggered_entrance.dart';
import '../../../shared/search/search_utils.dart';
import '../../orders/application/orders_providers.dart';
import 'widgets/order_card.dart';
import '../../../core/l10n/l10n_ext.dart';

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.myOrders,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/customer/quotes'),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: Text(context.l10n.myQuotes),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.everyOrderYouvePlacedWithLive,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: context.l10n.searchYourOrders,
              onChanged: (v) =>
                  ref.read(_myOrdersSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ordersAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: context.l10n.loading,
                  ),
                ),
                error: (error, stack) {
                  appLogger.e(
                    '[orders] Failed to load my orders',
                    error: error,
                    stackTrace: stack,
                  );
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: context.l10n.couldntLoadOrders,
                    message: friendlyError(error),
                    action: TextButton.icon(
                      onPressed: () => ref.invalidate(myOrdersProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.retry),
                    ),
                  );
                },
                data: (orders) {
                  final filtered = filterBySearch(
                    orders,
                    query,
                    (o) => o.searchFields,
                  );
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: orders.isEmpty
                          ? context.l10n.noOrdersYet
                          : context.l10n.noMatches,
                      message: orders.isEmpty
                          ? context.l10n.ordersYouPlaceFromTheCatalog
                          : context.l10n.tryADifferentSearchTerm,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return StaggeredEntrance(
                        index: index,
                        id: 'order-${order.id}',
                        child: OrderCard(
                          order: order,
                          onTap: () =>
                              context.push('/customer/orders/${order.id}'),
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
