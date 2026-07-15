import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/live_orders_map.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';

/// Shows the signed-in delivery staff member's active drops as pins on a
/// real Google Map.
class RouteMapScreen extends ConsumerWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myActiveDeliveriesProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Couldn\'t load your route: $error', textAlign: TextAlign.center)),
      data: (orders) => LiveOrdersMap(
        orders: orders,
        emptyIcon: Icons.map_outlined,
        emptyTitle: 'No active route',
        emptyMessage: 'Claim a delivery from My Deliveries and its stop will show up here.',
        onMarkerTap: _showStopSheet,
      ),
    );
  }

  void _showStopSheet(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Consumer(
          builder: (context, ref, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.contactName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(order.contactPhone, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(order.deliveryAddress)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('${order.itemCount} item(s)', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await ref.read(ordersRepositoryProvider).markDelivered(order.id);
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark delivered'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
