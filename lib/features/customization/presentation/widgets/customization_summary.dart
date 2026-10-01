import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/customization_options.dart';
import '../../domain/customization_pricing.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/l10n/enum_l10n.dart';

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
          (e) => e.key == oneSizeLabel
              ? context.l10n.pcs2(e.value)
              : '${e.key}×${e.value}',
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
                      child: Image(
                        image: CachedNetworkImageProvider(d.artworkUrl!),
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
                      '${d.placement.tr(context)}: ${d.method.tr(context)}, ${d.sizeClass.tr(context).toLowerCase()}',
                      if (d.artworkName != null) d.artworkName!,
                      if ((d.text ?? '').isNotEmpty) '"${d.text}"',
                      if (d.threadColours.isNotEmpty)
                        context.l10n.threadsList(d.threadColours.join('/')),
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
              context.l10n.namesList(
                config.names.length,
                config.names.take(6).join(', ') +
                    (config.names.length > 6 ? '…' : ''),
              ),
              style: small,
            ),
          ),
      ],
    );
  }
}
