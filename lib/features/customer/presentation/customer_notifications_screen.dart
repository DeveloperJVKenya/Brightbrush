import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../marketing/application/marketing_providers.dart';
import '../../orders/application/orders_providers.dart';

enum _FeedKind { orderUpdate, announcement }

class _FeedItem {
  const _FeedItem({required this.kind, required this.title, required this.message, required this.timestamp});

  final _FeedKind kind;
  final String title;
  final String message;
  final DateTime timestamp;
}

/// A real activity feed — one entry per order's current status (no stored
/// status-change history exists yet, so this shows the latest state rather
/// than fabricating a timeline) merged with active Marketing announcements.
/// Zero hardcoded data, matching the rest of the app's "sticks to what's
/// real" approach.
class CustomerNotificationsScreen extends ConsumerWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(myOrdersProvider);
    final announcementsAsync = ref.watch(activeAnnouncementsProvider);

    if (ordersAsync.isLoading || announcementsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ordersAsync.hasError) {
      appLogger.e('[notifications] Failed to load orders', error: ordersAsync.error, stackTrace: ordersAsync.stackTrace);
      return EmptyState(
          icon: Icons.cloud_off_rounded, title: 'Couldn\'t load notifications', message: friendlyError(ordersAsync.error!));
    }
    if (announcementsAsync.hasError) {
      appLogger.e('[notifications] Failed to load announcements',
          error: announcementsAsync.error, stackTrace: announcementsAsync.stackTrace);
      return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load notifications',
          message: friendlyError(announcementsAsync.error!));
    }

    final orders = ordersAsync.requireValue;
    final announcements = announcementsAsync.requireValue;

    final items = <_FeedItem>[
      for (final order in orders)
        _FeedItem(
          kind: _FeedKind.orderUpdate,
          title: 'Order for ${order.contactName}',
          message: '${order.itemCount} item(s) — now ${order.status.label}',
          timestamp: order.updatedAt,
        ),
      for (final a in announcements)
        _FeedItem(kind: _FeedKind.announcement, title: a.title, message: a.message, timestamp: a.createdAt),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_outlined,
        title: 'Nothing yet',
        message: 'Order status changes, delivery updates and seasonal offers will show up here.',
      );
    }

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                item.kind == _FeedKind.orderUpdate ? Icons.receipt_long_outlined : Icons.campaign_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(item.message),
              trailing: Text(
                DateFormat('MMM d').format(item.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        },
      ),
    );
  }
}
