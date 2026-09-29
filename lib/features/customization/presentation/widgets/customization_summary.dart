import 'package:flutter/material.dart';

import '../../domain/customization_options.dart';
import '../../domain/customization_pricing.dart';

/// Compact read-only description of a customised line: colour, size
/// breakdown, each decoration (method, placement, size, artwork/text,
/// threads) and names. Used in the cart, on orders and by production.
class CustomizationSummary extends StatelessWidget {
  const CustomizationSummary({
    super.key,
    required this.config,
    this.showArtworkThumbnails = true,
  });

  final CustomLineConfig config;
  final bool showArtworkThumbnails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final sizes = config.sizeQuantities.entries
        .where((e) => e.value > 0)
        .map(
          (e) =>
              e.key == oneSizeLabel ? '${e.value} pcs' : '${e.key}×${e.value}',
        )
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            if (config.colour != null) config.colour!,
            sizes,
          ].where((s) => s.isNotEmpty).join(' · '),
          style: small,
        ),
        for (final d in config.decorations)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showArtworkThumbnails && d.artworkUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        d.artworkUrl!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) =>
                            Icon(d.method.icon, size: 20),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(d.method.icon, size: 18),
                  ),
                Expanded(
                  child: Text(
                    [
                      '${d.placement.label}: ${d.method.label}, ${d.sizeClass.label.toLowerCase()}',
                      if (d.artworkName != null) d.artworkName!,
                      if ((d.text ?? '').isNotEmpty) '"${d.text}"',
                      if (d.threadColours.isNotEmpty)
                        'threads ${d.threadColours.join('/')}',
                    ].join(' · '),
                    style: small,
                  ),
                ),
              ],
            ),
          ),
        if (config.names.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Names (${config.names.length}): ${config.names.take(6).join(', ')}${config.names.length > 6 ? '…' : ''}',
              style: small,
            ),
          ),
      ],
    );
  }
}
