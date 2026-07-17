import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_orders_map.dart';
import '../../auth/domain/user_profile.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../../staff/presentation/widgets/delivery_order_card.dart';

/// Company-wide delivery oversight: every active drop across every staff
/// member, live on one map, plus a plain list view of the same data.
class AdminDeliveriesScreen extends ConsumerWidget {
  const AdminDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(allOrdersProvider);
    final staffAsync = ref.watch(deliveryStaffDirectoryProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[delivery] Failed to load deliveries', error: error, stackTrace: stack);
        return EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Couldn\'t load deliveries', message: friendlyError(error));
      },
      data: (orders) {
        final staffByUid = {for (final s in staffAsync.valueOrNull ?? const <UserProfile>[]) s.uid: s};

        final unassigned = orders.where((o) => o.status == OrderStatus.readyForDelivery && o.assignedStaffId == null).length;
        final active = orders.where((o) => o.status == OrderStatus.outForDelivery).toList();
        final now = DateTime.now();
        final deliveredToday = orders
            .where((o) =>
                o.status == OrderStatus.completed &&
                o.updatedAt.year == now.year &&
                o.updatedAt.month == now.month &&
                o.updatedAt.day == now.day)
            .length;

        String? labelFor(OrderModel order) {
          final staff = order.assignedStaffId == null ? null : staffByUid[order.assignedStaffId];
          if (staff == null) return null;
          return staff.displayName.isEmpty ? staff.email : staff.displayName;
        }

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
                      Text('Deliveries', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Live fleet position and delivery plans across every staff member.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatChip(label: 'Awaiting assignment', value: '$unassigned', icon: Icons.assignment_late_outlined),
                          _StatChip(label: 'Active deliveries', value: '${active.length}', icon: Icons.local_shipping_outlined),
                          _StatChip(label: 'Delivered today', value: '$deliveredToday', icon: Icons.check_circle_outline_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(text: 'Live map'),
                    Tab(text: 'Active list'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: LiveOrdersMap(
                            orders: active,
                            emptyIcon: Icons.map_outlined,
                            emptyTitle: 'No active deliveries',
                            emptyMessage: 'Once staff start a delivery, it\'ll show up here on the map.',
                            markerLabel: (order) {
                              final staffLabel = labelFor(order);
                              return staffLabel == null ? order.deliveryAddress : 'Assigned to $staffLabel';
                            },
                            onMarkerTap: (context, order) => _showDeliverySheet(context, ref, order, labelFor(order)),
                          ),
                        ),
                      ),
                      active.isEmpty
                          ? const EmptyState(
                              icon: Icons.local_shipping_outlined,
                              title: 'No active deliveries',
                              message: 'Once staff start a delivery, it\'ll show up here.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: active.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  DeliveryOrderCard(order: active[index], assignedLabel: labelFor(active[index])),
                            ),
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

  void _showDeliverySheet(BuildContext context, WidgetRef ref, OrderModel order, String? staffLabel) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.contactName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(order.contactPhone, style: theme.textTheme.bodyMedium),
              if (staffLabel != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('Assigned to $staffLabel', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ],
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
                child: OutlinedButton.icon(
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
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
