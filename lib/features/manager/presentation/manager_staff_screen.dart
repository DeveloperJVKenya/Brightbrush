import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_profile.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/domain/order_status.dart';
import '../../staff/presentation/widgets/delivery_order_card.dart';

/// Lets the System Manager push-assign a ready order to a specific delivery
/// staff member (rather than waiting for staff to self-claim from their own
/// Available queue), and see each staff member's current workload.
class ManagerStaffScreen extends StatelessWidget {
  const ManagerStaffScreen({super.key});

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
                  Text('Staff assignment', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Assign ready orders to a delivery staff member and see who\'s carrying what.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Unassigned'),
                Tab(text: 'Staff roster'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_UnassignedTab(), _RosterTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnassignedTab extends ConsumerWidget {
  const _UnassignedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(availableForDeliveryProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[staff] Failed to load unassigned orders', error: error, stackTrace: stack);
        return EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load orders', message: friendlyError(error));
      },
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nothing waiting on assignment',
            message: 'Orders marked "Ready for Delivery" that nobody has claimed yet will show up here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _AssignableCard(order: orders[index]),
        );
      },
    );
  }
}

class _AssignableCard extends ConsumerStatefulWidget {
  const _AssignableCard({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_AssignableCard> createState() => _AssignableCardState();
}

class _AssignableCardState extends ConsumerState<_AssignableCard> {
  bool _busy = false;

  Future<void> _pickStaffAndAssign() async {
    final staffAsync = ref.read(deliveryStaffDirectoryProvider);
    final staff = staffAsync.valueOrNull ?? const <UserProfile>[];
    if (staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No delivery staff accounts yet.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final picked = await showModalBottomSheet<UserProfile>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign to', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...staff.map(
                  (member) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                    title: Text(member.displayName.isEmpty ? member.email : member.displayName),
                    subtitle: Text(member.email),
                    onTap: () => Navigator.of(context).pop(member),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).claimForDelivery(widget.order.id, staffUid: picked.uid);
    } catch (error, stack) {
      appLogger.e('[staff] Failed to assign order ${widget.order.id}', error: error, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t assign: ${friendlyError(error)}'), behavior: SnackBarBehavior.floating),
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
      actionLabel: 'Assign to…',
      busy: _busy,
      onAction: _pickStaffAndAssign,
    );
  }
}

class _RosterTab extends ConsumerWidget {
  const _RosterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(deliveryStaffDirectoryProvider);
    final ordersAsync = ref.watch(allOrdersProvider);

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        appLogger.e('[staff] Failed to load staff roster', error: error, stackTrace: stack);
        return EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load staff', message: friendlyError(error));
      },
      data: (staff) {
        if (staff.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_2_outlined,
            title: 'No delivery staff accounts yet',
            message: 'Create a Delivery Staff account and it will show up here.',
          );
        }
        final orders = ordersAsync.valueOrNull ?? const <OrderModel>[];
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: staff.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final member = staff[index];
            final active = orders.where((o) => o.assignedStaffId == member.uid && o.status == OrderStatus.outForDelivery).toList();
            final completed = orders.where((o) => o.assignedStaffId == member.uid && o.status == OrderStatus.completed).length;
            return _StaffRosterCard(staff: member, activeOrders: active, completedCount: completed);
          },
        );
      },
    );
  }
}

class _StaffRosterCard extends StatelessWidget {
  const _StaffRosterCard({required this.staff, required this.activeOrders, required this.completedCount});

  final UserProfile staff;
  final List<OrderModel> activeOrders;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
        title: Text(staff.displayName.isEmpty ? staff.email : staff.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${staff.email} · ${activeOrders.length} active · $completedCount completed'),
        children: [
          if (activeOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(alignment: Alignment.centerLeft, child: Text('No active deliveries right now.')),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  for (final order in activeOrders) ...[
                    DeliveryOrderCard(order: order),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
