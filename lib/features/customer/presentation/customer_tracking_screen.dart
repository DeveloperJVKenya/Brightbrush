import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_orders_map.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_status.dart';

/// Live map view of the customer's own delivery — reuses [LiveOrdersMap],
/// the same widget the Delivery Staff Route Map and Admin Deliveries screen
/// use, scoped to just this customer's out-for-delivery order(s).
class CustomerTrackingScreen extends ConsumerWidget {
  const CustomerTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[tracking] Failed to load orders', error: error, stackTrace: stack);
        return EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Couldn\'t load your orders', message: friendlyError(error));
      },
      data: (orders) {
        final outForDelivery = orders.where((o) => o.status == OrderStatus.outForDelivery).toList();
        return LiveOrdersMap(
          orders: outForDelivery,
          emptyIcon: Icons.local_shipping_outlined,
          emptyTitle: 'Nothing out for delivery',
          emptyMessage: 'Once an order is out for delivery, track it live here.',
        );
      },
    );
  }
}
