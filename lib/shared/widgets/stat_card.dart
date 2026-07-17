import 'package:flutter/material.dart';

/// A small metric tile — label, value, icon — used across every dashboard
/// and overview screen (Manager/Admin home, Orders Overview, Reports,
/// Deliveries). [accent] highlights the one number on a row worth calling
/// out (e.g. revenue collected, orders awaiting review).
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.accent = false, this.hint});

  final String label;
  final String value;
  final IconData icon;
  final bool accent;

  /// Optional hover explanation of what this figure means — shown as a
  /// tooltip when provided.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return hint == null ? card : Tooltip(message: hint, waitDuration: const Duration(milliseconds: 400), child: card);
  }
}
