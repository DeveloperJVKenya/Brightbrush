import 'package:brightbrush/features/catalog/domain/catalog_category.dart';
import 'package:brightbrush/features/catalog/domain/catalog_item.dart';
import 'package:brightbrush/features/customization/domain/customization_options.dart';
import 'package:brightbrush/features/customization/domain/customization_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same cases as functions/src/customization/pricing.test.ts — the
/// configurator preview must agree with what placeOrder charges.
void main() {
  const p = DecorationPricing.defaults;
  final polo = CatalogItem(
    id: 'polo',
    name: 'Polo',
    category: CatalogCategory.tshirts,
    description: '',
    basePrice: 800,
    moq: 10,
    leadTimeDays: 5,
    imageUrls: const [],
    tags: const [],
    isActive: true,
    isFeatured: false,
    createdBy: 'm',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    priceTiers: const [
      PriceTier(minQty: 50, unitPrice: 700),
      PriceTier(minQty: 100, unitPrice: 650),
    ],
    sizes: const [
      SizeOption(label: 'M'),
      SizeOption(label: 'L'),
      SizeOption(label: 'XXL', surcharge: 100),
    ],
    colours: const [
      ColourOption(name: 'Navy', hex: '#1F2A44'),
      ColourOption(name: 'White', hex: '#FFFFFF'),
    ],
    decorationMethods: const [
      DecorationMethod.embroidery,
      DecorationMethod.dtf,
    ],
    placements: const [
      Placement.leftChest,
      Placement.fullBack,
      Placement.leftSleeve,
      Placement.rightSleeve,
    ],
  );

  DecorationChoice logo({
    Placement placement = Placement.leftChest,
    DecorationMethod method = DecorationMethod.embroidery,
    String? artworkId = 'art1',
    bool digitized = false,
    int? stitchCount,
  }) => DecorationChoice(
    method: method,
    placement: placement,
    artworkId: artworkId,
    threadColours: const ['White'],
    digitized: digitized,
    stitchCount: stitchCount,
  );

  test('tier price uses the highest tier reached', () {
    expect(CustomizationPricing.tierPrice(polo, 10), 800);
    expect(CustomizationPricing.tierPrice(polo, 50), 700);
    expect(CustomizationPricing.tierPrice(polo, 250), 650);
  });

  test('blanks + surcharges + per-piece branding + one-off setup', () {
    final price = CustomizationPricing.price(
      polo,
      CustomLineConfig(
        itemId: 'polo',
        colour: 'Navy',
        sizeQuantities: const {'M': 20, 'XXL': 5},
        decorations: [logo()],
      ),
      p,
    );
    expect(price.quantity, 25);
    expect(price.blankTotal, 20 * 800 + 5 * 900);
    expect(price.decorationPerUnit, 150);
    expect(price.setupFees, 1500);
    expect(price.lineTotal, 20500 + 25 * 150 + 1500);
  });

  test('digitized logos: no setup, stitch-based price', () {
    final price = CustomizationPricing.price(
      polo,
      CustomLineConfig(
        itemId: 'polo',
        colour: 'Navy',
        sizeQuantities: const {'M': 10},
        decorations: [logo(digitized: true, stitchCount: 8200)],
      ),
      p,
    );
    expect(price.setupFees, 0);
    expect(price.decorationPerUnit, 9 * 40);
  });

  test('same design on two placements is set up once', () {
    final price = CustomizationPricing.price(
      polo,
      CustomLineConfig(
        itemId: 'polo',
        colour: 'White',
        sizeQuantities: const {'L': 10},
        decorations: [
          logo(placement: Placement.leftSleeve),
          logo(placement: Placement.rightSleeve),
        ],
      ),
      p,
    );
    expect(price.setupFees, 1500);
    expect(price.decorationPerUnit, 300);
  });

  test('personalisation per named piece', () {
    final price = CustomizationPricing.price(
      polo,
      const CustomLineConfig(
        itemId: 'polo',
        colour: 'Navy',
        sizeQuantities: {'M': 10},
        names: ['Ann', 'Joe', ' '],
      ),
      p,
    );
    expect(price.personalisationTotal, 400);
  });

  test('validation mirrors the server', () {
    final ok = CustomLineConfig(
      itemId: 'polo',
      colour: 'Navy',
      sizeQuantities: const {'M': 10},
      decorations: [logo()],
    );
    expect(CustomizationPricing.validate(polo, ok, p), isNull);
    expect(
      CustomizationPricing.validate(
        polo,
        ok.copyWith(sizeQuantities: {'M': 5, 'L': 4}),
        p,
      ),
      contains('minimum'),
    );
    expect(
      CustomizationPricing.validate(polo, ok.copyWith(colour: 'Pink'), p),
      isNotNull,
    );
    expect(
      CustomizationPricing.validate(
        polo,
        ok.copyWith(decorations: [logo(method: DecorationMethod.screenPrint)]),
        p,
      ),
      isNotNull,
    );
    expect(
      CustomizationPricing.validate(
        polo,
        ok.copyWith(decorations: [logo(artworkId: null)]),
        p,
      ),
      isNotNull,
    );
  });

  test('cart map round-trips without server-only facts', () {
    final config = CustomLineConfig(
      itemId: 'polo',
      colour: 'Navy',
      sizeQuantities: const {'M': 10, 'L': 0},
      decorations: [logo(digitized: true, stitchCount: 5000)],
    );
    final map = config.toCartMap();
    expect(map['sizeQuantities'], {'M': 10});
    final decoration = (map['decorations'] as List).first as Map;
    expect(decoration.containsKey('stitchCount'), isFalse);
    expect(decoration.containsKey('digitized'), isFalse);
    final back = CustomLineConfig.fromMap(map);
    expect(back.quantity, 10);
    expect(back.decorations.single.placement, Placement.leftChest);
  });
}
