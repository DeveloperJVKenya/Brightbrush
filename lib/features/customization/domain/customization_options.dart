import 'package:flutter/material.dart';

/// Ways BrightBrush can brand an item. Names match DECORATION_METHODS in
/// functions/src/customization/pricing.ts.
enum DecorationMethod {
  embroidery(
    'Embroidery',
    Icons.gesture_rounded,
    'Stitched thread — durable, premium look.',
  ),
  screenPrint(
    'Screen print',
    Icons.format_paint_outlined,
    'Best value for big runs of simple artwork.',
  ),
  dtf(
    'DTF print',
    Icons.print_outlined,
    'Full-colour prints, photos and gradients.',
  ),
  heatTransfer(
    'Heat transfer',
    Icons.local_fire_department_outlined,
    'Vinyl names and numbers.',
  ),
  sublimation(
    'Sublimation',
    Icons.water_drop_outlined,
    'All-over colour on polyester and mugs.',
  ),
  laserEngraving(
    'Laser engraving',
    Icons.flare_outlined,
    'Permanent marks on bottles and cutlery.',
  );

  const DecorationMethod(this.label, this.icon, this.description);

  final String label;
  final IconData icon;
  final String description;

  /// Only embroidery uses thread colours.
  bool get usesThreadColours => this == DecorationMethod.embroidery;

  static DecorationMethod? fromName(String? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

enum MockupView { front, back, side }

/// Where a design goes. [rect] is the design's default box on the product
/// photo as fractions (left, top, width, height) — used by the mockup
/// preview. Placements on a view other than front are listed beside the
/// mockup rather than drawn on the (front) product photo.
enum Placement {
  leftChest(
    'Left chest',
    MockupView.front,
    Rect.fromLTWH(0.56, 0.28, 0.16, 0.12),
  ),
  rightChest(
    'Right chest',
    MockupView.front,
    Rect.fromLTWH(0.28, 0.28, 0.16, 0.12),
  ),
  centerChest(
    'Centre chest',
    MockupView.front,
    Rect.fromLTWH(0.38, 0.28, 0.24, 0.14),
  ),
  fullFront('Full front', MockupView.front, Rect.fromLTWH(0.3, 0.3, 0.4, 0.34)),
  upperBack('Upper back', MockupView.back, Rect.fromLTWH(0.34, 0.2, 0.32, 0.1)),
  fullBack('Full back', MockupView.back, Rect.fromLTWH(0.3, 0.26, 0.4, 0.38)),
  leftSleeve('Left sleeve', MockupView.side, Rect.fromLTWH(0.8, 0.3, 0.1, 0.1)),
  rightSleeve(
    'Right sleeve',
    MockupView.side,
    Rect.fromLTWH(0.1, 0.3, 0.1, 0.1),
  ),
  capFront('Cap front', MockupView.front, Rect.fromLTWH(0.35, 0.32, 0.3, 0.2)),
  capSide('Cap side', MockupView.side, Rect.fromLTWH(0.66, 0.42, 0.14, 0.12)),
  capBack('Cap back', MockupView.back, Rect.fromLTWH(0.4, 0.5, 0.2, 0.08)),
  productFront('Front', MockupView.front, Rect.fromLTWH(0.35, 0.35, 0.3, 0.26)),
  productBack('Back', MockupView.back, Rect.fromLTWH(0.35, 0.35, 0.3, 0.26)),
  wrapAround(
    'Wrap-around',
    MockupView.front,
    Rect.fromLTWH(0.2, 0.35, 0.6, 0.3),
  );

  const Placement(this.label, this.view, this.rect);

  final String label;
  final MockupView view;
  final Rect rect;

  static Placement? fromName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Design size bands used for per-piece pricing.
enum SizeClass {
  small('Small', 'up to 10 cm', 0.75),
  medium('Medium', 'up to 20 cm', 1.0),
  large('Large', 'up to 30 cm', 1.3);

  const SizeClass(this.label, this.hint, this.mockupScale);

  final String label;
  final String hint;

  /// How much bigger/smaller than the placement's default box the mockup
  /// draws the design.
  final double mockupScale;

  static SizeClass fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => SizeClass.small);
}

class PriceTier {
  const PriceTier({required this.minQty, required this.unitPrice});

  final int minQty;
  final num unitPrice;

  factory PriceTier.fromMap(Map<String, dynamic> d) => PriceTier(
    minQty: (d['minQty'] as num?)?.toInt() ?? 1,
    unitPrice: d['unitPrice'] as num? ?? 0,
  );

  Map<String, dynamic> toMap() => {'minQty': minQty, 'unitPrice': unitPrice};
}

class SizeOption {
  const SizeOption({required this.label, this.surcharge = 0});

  final String label;
  final num surcharge;

  factory SizeOption.fromMap(Map<String, dynamic> d) => SizeOption(
    label: d['label'] as String? ?? '',
    surcharge: d['surcharge'] as num? ?? 0,
  );

  Map<String, dynamic> toMap() => {'label': label, 'surcharge': surcharge};
}

class ColourOption {
  const ColourOption({required this.name, required this.hex});

  final String name;

  /// '#RRGGBB'.
  final String hex;

  Color get color {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? Colors.grey : Color(0xFF000000 | v);
  }

  factory ColourOption.fromMap(Object? raw) {
    if (raw is String) return ColourOption(name: raw, hex: '#9E9E9E');
    final d = Map<String, dynamic>.from(raw as Map);
    return ColourOption(
      name: d['name'] as String? ?? '',
      hex: d['hex'] as String? ?? '#9E9E9E',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'hex': hex};
}

/// Key used in size quantities for items that don't come in sizes. Must
/// match ONE_SIZE in functions/src/customization/pricing.ts.
const String oneSizeLabel = 'One size';
