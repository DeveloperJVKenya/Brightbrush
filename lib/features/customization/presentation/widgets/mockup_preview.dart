import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_image.dart';
import '../../domain/customization_options.dart';
import '../../domain/customization_pricing.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/l10n/enum_l10n.dart';

/// Live mockup: the product photo with each front-view decoration drawn at
/// its placement (sized by design size). Designs can be dragged to
/// fine-tune the position; back/side placements are listed underneath as
/// chips since the product photo only shows the front.
class MockupPreview extends StatelessWidget {
  const MockupPreview({
    super.key,
    required this.productImageUrls,
    required this.placeholderIcon,
    required this.decorations,
    this.garmentColour,
    this.onMoved,
  });

  final List<String> productImageUrls;
  final IconData placeholderIcon;
  final List<DecorationChoice> decorations;
  final Color? garmentColour;

  /// Called with the decoration index and its new centre (0..1). Null makes
  /// the mockup read-only.
  final void Function(int index, double x, double y)? onMoved;

  static Rect boxFor(DecorationChoice d) {
    final base = d.placement.rect;
    final scale = d.sizeClass.mockupScale;
    final w = (base.width * scale).clamp(0.05, 0.9);
    final h = (base.height * scale).clamp(0.05, 0.9);
    final cx = d.offsetX ?? base.center.dx;
    final cy = d.offsetY ?? base.center.dy;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offView = [
      for (final d in decorations)
        if (d.placement.view != MockupView.front) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: productImageUrls.isEmpty
                          ? ColoredBox(
                              color:
                                  garmentColour ??
                                  theme.colorScheme.surfaceContainerHigh,
                              child: Icon(
                                placeholderIcon,
                                size: size.shortestSide * 0.6,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            )
                          : CatalogImage(
                              imageUrls: productImageUrls,
                              placeholderIcon: placeholderIcon,
                              borderRadius: BorderRadius.zero,
                            ),
                    ),
                    for (final (i, d) in decorations.indexed)
                      if (d.placement.view == MockupView.front)
                        _DesignBox(
                          key: ValueKey('${d.placement.name}-$i'),
                          decoration: d,
                          rect: boxFor(d),
                          canvas: size,
                          onMoved: onMoved == null
                              ? null
                              : (x, y) => onMoved!(i, x, y),
                        ),
                    if (garmentColour != null && productImageUrls.isNotEmpty)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.surface,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: garmentColour,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (offView.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in offView)
                Chip(
                  avatar: _Thumb(decoration: d),
                  label: Text(
                    '${d.placement.tr(context)}: ${d.artworkName ?? d.text ?? 'design'}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        if (onMoved != null &&
            decorations.any((d) => d.placement.view == MockupView.front))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.l10n.dragADesignToAdjustIts,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _DesignBox extends StatelessWidget {
  const _DesignBox({
    super.key,
    required this.decoration,
    required this.rect,
    required this.canvas,
    required this.onMoved,
  });

  final DecorationChoice decoration;
  final Rect rect;
  final Size canvas;
  final void Function(double x, double y)? onMoved;

  @override
  Widget build(BuildContext context) {
    final left = rect.left * canvas.width;
    final top = rect.top * canvas.height;
    final width = rect.width * canvas.width;
    final height = rect.height * canvas.height;
    final content = _DesignContent(decoration: decoration);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: onMoved == null
          ? content
          : MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final cx = (rect.center.dx + details.delta.dx / canvas.width)
                      .clamp(rect.width / 2, 1 - rect.width / 2);
                  final cy = (rect.center.dy + details.delta.dy / canvas.height)
                      .clamp(rect.height / 2, 1 - rect.height / 2);
                  onMoved!(cx, cy);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _DesignContent extends StatelessWidget {
  const _DesignContent({required this.decoration});

  final DecorationChoice decoration;

  bool get _isRaster {
    final url = (decoration.artworkUrl ?? '').toLowerCase();
    return url.contains('.png') ||
        url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.webp') ||
        url.contains('.gif');
  }

  @override
  Widget build(BuildContext context) {
    final threadColour = decoration.threadColours.isNotEmpty
        ? _namedColour(decoration.threadColours.first)
        : Colors.white;
    if (decoration.artworkUrl != null && _isRaster) {
      return Image(
        image: CachedNetworkImageProvider(decoration.artworkUrl!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            _label(context, context.l10n.logo),
      );
    }
    if ((decoration.text ?? '').trim().isNotEmpty) {
      return FittedBox(
        child: Text(
          decoration.text!.trim(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: threadColour,
            shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
      );
    }
    return _label(context, decoration.artworkName ?? context.l10n.yourDesign);
  }

  Widget _label(BuildContext context, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white70),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.decoration});

  final DecorationChoice decoration;

  @override
  Widget build(BuildContext context) {
    final url = decoration.artworkUrl;
    if (url == null) return Icon(decoration.method.icon, size: 16);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image(
        image: CachedNetworkImageProvider(url),
        width: 20,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            Icon(decoration.method.icon, size: 16),
      ),
    );
  }
}

/// Best-effort colour for common thread colour names (mockup text only).
Color _namedColour(String name) => switch (name.toLowerCase()) {
  'black' => Colors.black,
  'white' => Colors.white,
  'red' => Colors.red,
  'navy' => const Color(0xFF1F2A44),
  'blue' || 'royal blue' => Colors.blue,
  'green' => Colors.green,
  'yellow' => Colors.yellow,
  'gold' => const Color(0xFFD4AF37),
  'silver' || 'grey' || 'gray' => Colors.grey,
  'orange' => Colors.orange,
  'pink' => Colors.pink,
  'maroon' => const Color(0xFF6D1B2B),
  _ => Colors.white,
};
