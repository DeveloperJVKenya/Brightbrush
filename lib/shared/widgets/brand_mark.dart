import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The brand's small graphic signature: a gradient roundel with the brush
/// glyph. Used anywhere the app needs a "we are a design studio, not a
/// spreadsheet" moment — splash, login, and nav headers — without ever
/// flooding a whole surface in red.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: BrandColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: BrandColors.brushRed.withValues(alpha: 0.28),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(Icons.brush_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}
