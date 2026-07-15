import 'package:flutter/material.dart';

class BarDatum {
  const BarDatum({required this.label, required this.value, required this.valueLabel});

  final String label;
  final num value;
  final String valueLabel;
}

/// A dependency-free horizontal bar chart — just sized [Container]s, no
/// charting package needed for a handful of report rows.
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({super.key, required this.data});

  final List<BarDatum> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.fold<num>(0, (m, d) => d.value > m ? d.value : m);

    return Column(
      children: [
        for (final datum in data)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(datum.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text(datum.valueLabel, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fraction = maxValue <= 0 ? 0.0 : (datum.value / maxValue).clamp(0.02, 1.0);
                    return Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 10,
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
