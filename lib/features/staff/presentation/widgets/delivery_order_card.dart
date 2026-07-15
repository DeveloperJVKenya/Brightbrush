import 'package:flutter/material.dart';
import '../../../../core/formatting/currency.dart';

import '../../../orders/domain/order_model.dart';

/// One order in a Delivery Staff list — available to claim, currently
/// active, or historical — with an optional trailing action button that
/// varies by which list it's shown in.
class DeliveryOrderCard extends StatelessWidget {
  const DeliveryOrderCard({
    super.key,
    required this.order,
    this.actionLabel,
    this.onAction,
    this.busy = false,
    this.assignedLabel,
  });

  final OrderModel order;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  /// Optional "Assigned to: `staff name`" line — orders only ever store a
  /// staff uid, so callers that need the name (e.g. Admin Deliveries,
  /// looking across every staff member at once) resolve and pass it in.
  final String? assignedLabel;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.contactName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(order.contactPhone, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(order.total),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(order.deliveryAddress, style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${order.itemCount} item(s) · ${order.items.map((i) => i.name).join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (assignedLabel != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Assigned to $assignedLabel',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onAction,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
