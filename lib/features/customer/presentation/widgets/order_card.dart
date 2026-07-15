import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/formatting/currency.dart';

import '../../../../shared/widgets/order_status_timeline.dart';
import '../../../orders/domain/order_model.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  static final _date = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.id.substring(0, order.id.length.clamp(0, 6))}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _date.format(order.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${order.itemCount} item(s) · ${currencyFormat.format(order.total)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              OrderStatusTimeline(status: order.status),
            ],
          ),
        ),
      ),
    );
  }
}
