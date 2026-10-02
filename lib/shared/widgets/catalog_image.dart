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

  /// Decode widths are rounded up to these so cards of slightly different
  /// sizes share one decoded copy in the image cache.
  static const _decodeBuckets = [160, 240, 320, 480, 640, 960, 1280];

  static int _decodeWidth(double logicalWidth, double dpr) {
    final px = (logicalWidth * dpr).ceil();
    for (final b in _decodeBuckets) {
      if (px <= b) return b;
    }
    return _decodeBuckets.last;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: _placeholder(context),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : (constraints.hasBoundedHeight ? constraints.maxHeight : 400.0);
          // Decode at the size it's shown, not the photo's full size: much
          // less decoding work and memory, so scrolling stays smooth.
          final provider = ResizeImage(
            CachedNetworkImageProvider(imageUrls.first),
            width: _decodeWidth(w, dpr),
            policy: ResizeImagePolicy.fit,
            allowUpscaling: false,
          );
          return Image(
            image: provider,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            semanticLabel: semanticLabel,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return _placeholder(context, loading: true);
            },
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );
        },
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
