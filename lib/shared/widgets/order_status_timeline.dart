import 'package:flutter/material.dart';

import '../../features/orders/domain/order_status.dart';

/// Horizontal progress timeline through [OrderStatus.pipeline], with a
/// separate "cancelled" treatment when that's the terminal state. Each
/// completed/current step animates its fill so status changes (arriving
/// live from Firestore) feel like progress, not a flat state swap.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel_rounded, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Text('Cancelled', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
      );
    }

    final currentIndex = OrderStatus.pipeline.indexOf(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < OrderStatus.pipeline.length; i++) ...[
              _StepDot(reached: i <= currentIndex, current: i == currentIndex),
              if (i != OrderStatus.pipeline.length - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: i < currentIndex ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          OrderStatus.pipeline[currentIndex].label,
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.reached, required this.current});

  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: current ? 16 : 12,
      height: current ? 16 : 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? scheme.primary : scheme.surfaceContainerHigh,
        border: Border.all(color: reached ? scheme.primary : scheme.outlineVariant, width: 2),
      ),
    );
  }
}
