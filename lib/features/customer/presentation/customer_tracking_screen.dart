import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_orders_map.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_status.dart';
import '../../../core/l10n/l10n_ext.dart';

/// Live map view of the customer's own delivery — reuses [LiveOrdersMap],
/// the same widget the Delivery Staff Route Map and Admin Deliveries screen
/// use, scoped to just this customer's out-for-delivery order(s).
class CustomerTrackingScreen extends ConsumerWidget {
  const CustomerTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return ordersAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(semanticsLabel: context.l10n.loading),
      ),
      error: (error, stack) {
        appLogger.e(
          '[tracking] Failed to load orders',
          error: error,
          stackTrace: stack,
        );
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: context.l10n.couldntLoadYourOrders,
          message: friendlyError(error),
          action: TextButton.icon(
            onPressed: () => ref.invalidate(myOrdersProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.retry),
          ),
        );
      },
      data: (orders) {
        final outForDelivery = orders
            .where((o) => o.status == OrderStatus.outForDelivery)
            .toList();
        return LiveOrdersMap(
          orders: outForDelivery,
          emptyIcon: Icons.local_shipping_outlined,
          emptyTitle: context.l10n.nothingOutForDelivery,
          emptyMessage: context.l10n.onceAnOrderIsOutFor,
        );
      },
    );
  }
}
