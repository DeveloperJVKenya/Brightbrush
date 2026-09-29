import 'package:cloud_firestore/cloud_firestore.dart';

import '../../catalog/domain/catalog_item.dart';
import 'customization_options.dart';

class MethodPricing {
  const MethodPricing({
    required this.enabled,
    required this.setupFee,
    required this.small,
    required this.medium,
    required this.large,
    this.per1000Stitches = 0,
  });

  final bool enabled;
  final num setupFee;
  final num small;
  final num medium;
  final num large;
  final num per1000Stitches;

  num perUnit(SizeClass size) => switch (size) {
    SizeClass.small => small,
    SizeClass.medium => medium,
    SizeClass.large => large,
  };

  MethodPricing copyWith({
    bool? enabled,
    num? setupFee,
    num? small,
    num? medium,
    num? large,
    num? per1000Stitches,
  }) => MethodPricing(
    enabled: enabled ?? this.enabled,
    setupFee: setupFee ?? this.setupFee,
    small: small ?? this.small,
    medium: medium ?? this.medium,
    large: large ?? this.large,
    per1000Stitches: per1000Stitches ?? this.per1000Stitches,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'setupFee': setupFee,
    'perUnit': {'small': small, 'medium': medium, 'large': large},
    'per1000Stitches': per1000Stitches,
  };
}

/// Settings/decoration — admin-editable decoration rates. Defaults match
/// DEFAULT_DECORATION_PRICING in functions/src/customization/pricing.ts.
class DecorationPricing {
  const DecorationPricing({
    required this.methods,
    required this.personalisationFee,
  });

  final Map<DecorationMethod, MethodPricing> methods;
  final num personalisationFee;

  static const defaults = DecorationPricing(
    personalisationFee: 200,
    methods: {
      DecorationMethod.embroidery: MethodPricing(
        enabled: true,
        setupFee: 1500,
        small: 150,
        medium: 300,
        large: 600,
        per1000Stitches: 40,
      ),
      DecorationMethod.screenPrint: MethodPricing(
        enabled: true,
        setupFee: 2000,
        small: 80,
        medium: 150,
        large: 250,
      ),
      DecorationMethod.dtf: MethodPricing(
        enabled: true,
        setupFee: 0,
        small: 120,
        medium: 200,
        large: 350,
      ),
      DecorationMethod.heatTransfer: MethodPricing(
        enabled: true,
        setupFee: 0,
        small: 100,
        medium: 180,
        large: 300,
      ),
      DecorationMethod.sublimation: MethodPricing(
        enabled: true,
        setupFee: 0,
        small: 150,
        medium: 250,
        large: 400,
      ),
      DecorationMethod.laserEngraving: MethodPricing(
        enabled: true,
        setupFee: 500,
        small: 100,
        medium: 150,
        large: 250,
      ),
    },
  );

  MethodPricing of(DecorationMethod m) => methods[m] ?? defaults.methods[m]!;

  factory DecorationPricing.fromMap(Map<String, dynamic>? d) {
    if (d == null) return defaults;
    num n(Object? v, num fallback) =>
        v is num && v >= 0 && v <= 1e7 ? v : fallback;
    final raw = Map<String, dynamic>.from((d['methods'] as Map?) ?? const {});
    return DecorationPricing(
      personalisationFee: n(
        d['personalisationFee'],
        defaults.personalisationFee,
      ),
      methods: {
        for (final m in DecorationMethod.values)
          m: () {
            final f = defaults.methods[m]!;
            final r = Map<String, dynamic>.from(
              (raw[m.name] as Map?) ?? const {},
            );
            final unit = Map<String, dynamic>.from(
              (r['perUnit'] as Map?) ?? const {},
            );
            return MethodPricing(
              enabled: r['enabled'] as bool? ?? f.enabled,
              setupFee: n(r['setupFee'], f.setupFee),
              small: n(unit['small'], f.small),
              medium: n(unit['medium'], f.medium),
              large: n(unit['large'], f.large),
              per1000Stitches: n(r['per1000Stitches'], f.per1000Stitches),
            );
          }(),
      },
    );
  }

  Map<String, dynamic> toFirestore({required String uid}) => {
    'methods': {for (final e in methods.entries) e.key.name: e.value.toMap()},
    'personalisationFee': personalisationFee,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };
}

/// One decoration on a customised line (a logo or text at a placement).
class DecorationChoice {
  const DecorationChoice({
    required this.method,
    required this.placement,
    this.sizeClass = SizeClass.small,
    this.artworkId,
    this.artworkName,
    this.artworkUrl,
    this.text,
    this.threadColours = const [],
    this.offsetX,
    this.offsetY,
    this.stitchCount,
    this.digitized = false,
  });

  final DecorationMethod method;
  final Placement placement;
  final SizeClass sizeClass;
  final String? artworkId;

  /// Display-only copies of the artwork (the server re-reads the Artworks
  /// doc when pricing).
  final String? artworkName;
  final String? artworkUrl;
  final String? text;
  final List<String> threadColours;

  /// Where the customer dragged the design on the mockup (0..1).
  final double? offsetX;
  final double? offsetY;

  /// Preview-only: from the artwork doc, used to mirror server pricing.
  final int? stitchCount;
  final bool digitized;

  DecorationChoice copyWith({
    DecorationMethod? method,
    Placement? placement,
    SizeClass? sizeClass,
    String? artworkId,
    String? artworkName,
    String? artworkUrl,
    String? text,
    List<String>? threadColours,
    double? offsetX,
    double? offsetY,
    int? stitchCount,
    bool? digitized,
    bool clearArtwork = false,
  }) => DecorationChoice(
    method: method ?? this.method,
    placement: placement ?? this.placement,
    sizeClass: sizeClass ?? this.sizeClass,
    artworkId: clearArtwork ? null : artworkId ?? this.artworkId,
    artworkName: clearArtwork ? null : artworkName ?? this.artworkName,
    artworkUrl: clearArtwork ? null : artworkUrl ?? this.artworkUrl,
    text: text ?? this.text,
    threadColours: threadColours ?? this.threadColours,
    offsetX: offsetX ?? this.offsetX,
    offsetY: offsetY ?? this.offsetY,
    stitchCount: clearArtwork ? null : stitchCount ?? this.stitchCount,
    digitized: clearArtwork ? false : digitized ?? this.digitized,
  );

  static DecorationChoice? fromMap(Map<String, dynamic> d) {
    final method = DecorationMethod.fromName(d['method'] as String?);
    final placement = Placement.fromName(d['placement'] as String?);
    if (method == null || placement == null) return null;
    return DecorationChoice(
      method: method,
      placement: placement,
      sizeClass: SizeClass.fromName(d['sizeClass'] as String?),
      artworkId: d['artworkId'] as String?,
      artworkName: d['artworkName'] as String?,
      artworkUrl: d['artworkUrl'] as String?,
      text: d['text'] as String?,
      threadColours: (d['threadColours'] as List?)?.cast<String>() ?? const [],
      offsetX: (d['offsetX'] as num?)?.toDouble(),
      offsetY: (d['offsetY'] as num?)?.toDouble(),
      stitchCount: (d['stitchCount'] as num?)?.toInt(),
      digitized: d['digitized'] as bool? ?? false,
    );
  }

  /// What's stored in the cart (never stitch count / digitized — the
  /// server looks those up itself).
  Map<String, dynamic> toCartMap() => {
    'method': method.name,
    'placement': placement.name,
    'sizeClass': sizeClass.name,
    'artworkId': ?artworkId,
    'artworkName': ?artworkName,
    'artworkUrl': ?artworkUrl,
    if ((text ?? '').trim().isNotEmpty) 'text': text!.trim(),
    'threadColours': threadColours,
    'offsetX': ?offsetX,
    'offsetY': ?offsetY,
  };
}

/// A customised catalog line: colour, quantities per size, decorations and
/// optional per-piece names.
class CustomLineConfig {
  const CustomLineConfig({
    required this.itemId,
    this.colour,
    this.sizeQuantities = const {},
    this.decorations = const [],
    this.names = const [],
  });

  final String itemId;
  final String? colour;
  final Map<String, int> sizeQuantities;
  final List<DecorationChoice> decorations;
  final List<String> names;

  int get quantity =>
      sizeQuantities.values.fold(0, (s, q) => s + (q > 0 ? q : 0));

  CustomLineConfig copyWith({
    String? colour,
    Map<String, int>? sizeQuantities,
    List<DecorationChoice>? decorations,
    List<String>? names,
  }) => CustomLineConfig(
    itemId: itemId,
    colour: colour ?? this.colour,
    sizeQuantities: sizeQuantities ?? this.sizeQuantities,
    decorations: decorations ?? this.decorations,
    names: names ?? this.names,
  );

  factory CustomLineConfig.fromMap(Map<String, dynamic> d) {
    return CustomLineConfig(
      itemId: d['itemId'] as String? ?? '',
      colour: d['colour'] as String?,
      sizeQuantities: {
        for (final e in Map<String, dynamic>.from(
          (d['sizeQuantities'] as Map?) ?? const {},
        ).entries)
          e.key: (e.value as num).toInt(),
      },
      decorations: [
        for (final raw in (d['decorations'] as List? ?? const []))
          ?DecorationChoice.fromMap(Map<String, dynamic>.from(raw as Map)),
      ],
      names: (d['names'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toCartMap() => {
    'itemId': itemId,
    'colour': ?colour,
    'sizeQuantities': {
      for (final e in sizeQuantities.entries)
        if (e.value > 0) e.key: e.value,
    },
    'decorations': [for (final d in decorations) d.toCartMap()],
    'names': [
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim(),
    ],
  };
}

class LinePrice {
  const LinePrice({
    required this.quantity,
    required this.tierUnitPrice,
    required this.blankTotal,
    required this.decorationPerUnit,
    required this.decorationTotal,
    required this.setupFees,
    required this.personalisationTotal,
    required this.lineTotal,
  });

  final int quantity;
  final num tierUnitPrice;
  final num blankTotal;
  final num decorationPerUnit;
  final num decorationTotal;
  final num setupFees;
  final num personalisationTotal;
  final num lineTotal;

  num get unitPrice => quantity == 0 ? 0 : lineTotal / quantity;
}

/// Checkout-preview mirror of priceLine/validateLine in
/// functions/src/customization/pricing.ts — keep the two in step (see
/// test/customization_pricing_test.dart). The server price is final.
class CustomizationPricing {
  const CustomizationPricing._();

  static num tierPrice(CatalogItem item, int quantity) {
    num price = item.basePrice;
    var best = 0;
    for (final tier in item.priceTiers) {
      if (quantity >= tier.minQty &&
          tier.minQty >= best &&
          tier.unitPrice > 0) {
        best = tier.minQty;
        price = tier.unitPrice;
      }
    }
    return price;
  }

  static num decorationUnitPrice(DecorationChoice d, DecorationPricing p) {
    final m = p.of(d.method);
    if (d.method == DecorationMethod.embroidery &&
        (d.stitchCount ?? 0) > 0 &&
        m.per1000Stitches > 0) {
      return (d.stitchCount! / 1000).ceil() * m.per1000Stitches;
    }
    return m.perUnit(d.sizeClass);
  }

  static String? validate(
    CatalogItem item,
    CustomLineConfig c,
    DecorationPricing p,
  ) {
    final quantity = c.quantity;
    if (quantity <= 0) return 'Enter how many pieces you need.';
    if (quantity < item.moq) {
      return 'The minimum order is ${item.moq} pieces (you have $quantity).';
    }
    final allowedSizes = item.sizes.isEmpty
        ? const [oneSizeLabel]
        : item.sizes.map((s) => s.label).toList();
    for (final e in c.sizeQuantities.entries) {
      if (e.value > 0 && !allowedSizes.contains(e.key)) {
        return 'Size "${e.key}" isn\'t available for this item.';
      }
    }
    if (item.colours.isNotEmpty &&
        !item.colours.any((col) => col.name == c.colour)) {
      return 'Choose one of the available colours.';
    }
    if (c.decorations.length > 6) return 'At most 6 decorations per item.';
    final used = <Placement>{};
    for (final d in c.decorations) {
      if (!item.decorationMethods.contains(d.method)) {
        return 'That decoration method isn\'t offered on this item.';
      }
      if (!p.of(d.method).enabled) {
        return '${d.method.label} is currently unavailable.';
      }
      if (!item.placements.contains(d.placement)) {
        return 'That placement isn\'t offered on this item.';
      }
      if (!used.add(d.placement)) {
        return 'Each placement can only be used once.';
      }
      if (d.artworkId == null && (d.text ?? '').trim().isEmpty) {
        return '${d.placement.label}: add artwork or text.';
      }
    }
    if (c.names.where((n) => n.trim().isNotEmpty).length > quantity) {
      return 'You have more names than pieces.';
    }
    return null;
  }

  static LinePrice price(
    CatalogItem item,
    CustomLineConfig c,
    DecorationPricing p,
  ) {
    final quantity = c.quantity;
    final tier = tierPrice(item, quantity);
    final surcharge = {for (final s in item.sizes) s.label: s.surcharge};
    num blankTotal = 0;
    c.sizeQuantities.forEach((size, qty) {
      if (qty > 0) blankTotal += qty * (tier + (surcharge[size] ?? 0));
    });
    num perUnit = 0;
    num setup = 0;
    final charged = <String>{};
    for (final d in c.decorations) {
      perUnit += decorationUnitPrice(d, p);
      final key =
          '${d.method.name}:${d.artworkId ?? 'text:${(d.text ?? '').trim()}'}';
      final waived = d.method == DecorationMethod.embroidery && d.digitized;
      if (!waived && charged.add(key)) setup += p.of(d.method).setupFee;
    }
    final decorationTotal = perUnit * quantity;
    final personalisation =
        c.names.where((n) => n.trim().isNotEmpty).length * p.personalisationFee;
    return LinePrice(
      quantity: quantity,
      tierUnitPrice: tier,
      blankTotal: blankTotal.round(),
      decorationPerUnit: perUnit,
      decorationTotal: decorationTotal.round(),
      setupFees: setup.round(),
      personalisationTotal: personalisation.round(),
      lineTotal: (blankTotal + decorationTotal + setup + personalisation)
          .round(),
    );
  }
}
