import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import 'widgets/delivery_order_card.dart';

class MyDeliveriesScreen extends StatelessWidget {
  const MyDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My deliveries',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Claim ready orders and run your active drops.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Available'),
                Tab(text: 'Active'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _AvailableTab(),
                  _ActiveTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableTab extends ConsumerWidget {
  const _AvailableTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(availableForDeliveryProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[delivery] Failed to load available orders', error: error, stackTrace: stack);
        return EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: friendlyError(error));
      },
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nothing ready yet',
            message: 'Orders the System Manager marks "Ready for Delivery" will show up here to claim.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _ClaimableCard(order: orders[index]),
        );
      },
    );
  }
}

class _ClaimableCard extends ConsumerStatefulWidget {
  const _ClaimableCard({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_ClaimableCard> createState() => _ClaimableCardState();
}

class _ClaimableCardState extends ConsumerState<_ClaimableCard> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        appLogger.i('[delivery] uid=$uid claiming order ${widget.order.id}');
        await ref.read(ordersRepositoryProvider).claimForDelivery(widget.order.id, staffUid: uid);
      } else {
        appLogger.w('[delivery] Claim attempted with no signed-in uid — ignoring');
      }
    } catch (error, stack) {
      appLogger.e('[delivery] Failed to claim order ${widget.order.id}', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t claim: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeliveryOrderCard(
      order: widget.order,
      actionLabel: 'Claim & start delivery',
      busy: _busy,
      onAction: _claim,
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myActiveDeliveriesProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[delivery] Failed to load active deliveries', error: error, stackTrace: stack);
        return EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: friendlyError(error));
      },
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'No active deliveries',
            message: 'Claim an order from the Available tab to start a delivery.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _ActiveCard(order: orders[index]),
        );
      },
    );
  }
}

class _ActiveCard extends ConsumerStatefulWidget {
  const _ActiveCard({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends ConsumerState<_ActiveCard> {
  bool _busy = false;

  Future<void> _markDelivered() async {
    setState(() => _busy = true);
    try {
      appLogger.i('[delivery] Marking order ${widget.order.id} delivered');
      await ref.read(ordersRepositoryProvider).markDelivered(widget.order.id);
    } catch (error, stack) {
      appLogger.e('[delivery] Failed to mark order ${widget.order.id} delivered', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t update: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeliveryOrderCard(
      order: widget.order,
      actionLabel: 'Mark delivered',
      busy: _busy,
      onAction: _markDelivered,
    );
  }
}
