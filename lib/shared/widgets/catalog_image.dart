import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Displays the first of a list of Storage download URLs, or a branded
/// placeholder tile (gradient + icon) when there's no image yet — every
/// item is presentable from the moment it's created, before any photo is
/// uploaded.
class CatalogImage extends StatelessWidget {
  const CatalogImage({
    super.key,
    required this.imageUrls,
    required this.placeholderIcon,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.semanticLabel,
  });

  final List<String> imageUrls;
  final IconData placeholderIcon;
  final BorderRadius borderRadius;

  /// Screen-reader description of what's pictured — typically the item's
  /// name. Left null on small thumbnails where an adjacent name label
  /// already covers it (avoids double-announcing the same text).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: imageUrls.isEmpty
          ? _placeholder(context)
          : Image(
              image: CachedNetworkImageProvider(imageUrls.first),
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _placeholder(context, loading: true);
              },
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            ),
    );
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
      ),
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          : Icon(
              placeholderIcon,
              size: 36,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
    );
  }
}

/// Small brand-gradient badge, used for "Featured" / seasonal tags on
/// catalog and package cards.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: BrandColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
