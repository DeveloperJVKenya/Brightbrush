import 'dart:io';

import 'package:brightbrush/core/firebase/firebase_providers.dart';
import 'package:brightbrush/core/settings/shared_preferences_provider.dart';
import 'package:brightbrush/core/theme/app_theme.dart';
import 'package:brightbrush/features/catalog/application/catalog_providers.dart';
import 'package:brightbrush/features/catalog/domain/catalog_category.dart';
import 'package:brightbrush/features/catalog/domain/catalog_item.dart';
import 'package:brightbrush/features/customer/application/cart_providers.dart';
import 'package:brightbrush/features/customer/presentation/customer_catalog_screen.dart';
import 'package:brightbrush/features/customization/domain/customization_options.dart';
import 'package:brightbrush/features/growth/companies.dart';
import 'package:brightbrush/features/growth/growth_providers.dart';
import 'package:brightbrush/features/marketing/application/marketing_providers.dart';
import 'package:brightbrush/features/payments/application/payments_providers.dart';
import 'package:brightbrush/features/payments/domain/business_settings.dart';
import 'package:brightbrush/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.now();

CatalogItem _item(
  int i, {
  CatalogCategory category = CatalogCategory.tshirts,
  bool featured = false,
  bool customisable = false,
  List<PriceTier> tiers = const [],
  double rating = 0,
  int reviews = 0,
  int ageDays = 90,
  String? name,
}) => CatalogItem(
  id: 'item$i',
  name: name ?? 'Premium branded item number $i with a long name',
  category: category,
  description: 'Quality cotton',
  basePrice: 500 + i * 150,
  moq: 12,
  leadTimeDays: 3 + i % 10,
  imageUrls: const [],
  tags: const ['cotton'],
  isActive: true,
  isFeatured: featured,
  createdBy: 'admin',
  createdAt: _now.subtract(Duration(days: ageDays)),
  updatedAt: _now,
  priceTiers: tiers,
  decorationMethods: customisable
      ? const [DecorationMethod.embroidery]
      : const [],
  placements: customisable ? const [Placement.leftChest] : const [],
  ratingAvg: rating,
  ratingCount: reviews,
);

final sampleItems = [
  _item(
    1,
    featured: true,
    customisable: true,
    rating: 4.5,
    reviews: 12,
    name: 'Embroidered cap',
  ),
  _item(
    2,
    category: CatalogCategory.hoodies,
    tiers: const [PriceTier(minQty: 50, unitPrice: 600)],
    ageDays: 5,
  ),
  _item(3, category: CatalogCategory.waterBottles, rating: 3.8, reviews: 4),
  _item(
    4,
    featured: true,
    category: CatalogCategory.caps,
    tiers: const [PriceTier(minQty: 100, unitPrice: 700)],
  ),
  for (var i = 5; i < 16; i++)
    _item(
      i,
      category: CatalogCategory.values[i % CatalogCategory.values.length],
      ageDays: i * 4,
      customisable: i.isEven,
    ),
];

Future<void> pumpHome(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  List<CatalogItem>? items,
  Locale? locale,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUidProvider.overrideWith((ref) => null),
        activeCatalogItemsProvider.overrideWith(
          (ref) => Stream.value(items ?? sampleItems),
        ),
        activeAnnouncementsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        activePackagesProvider.overrideWith((ref) => Stream.value(const [])),
        businessSettingsProvider.overrideWith(
          (ref) => Stream.value(
            const BusinessSettings(freeDeliveryThreshold: 20000),
          ),
        ),
        wishlistProvider.overrideWith((ref) => Stream.value(const <String>{})),
        cartItemCountProvider.overrideWith((ref) => 3),
        myCompanyProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const CustomerCatalogScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

final _outer = find.byWidgetPredicate((w) => w is CustomScrollView);

Future<void> scrollThrough(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(_outer, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(
    find.byType(SearchBar),
    findsNothing,
    reason: 'search bar hides while scrolling down',
  );
  // A finger moving back up brings the search bar back.
  final g = await tester.startGesture(tester.getCenter(_outer));
  for (var i = 0; i < 12; i++) {
    await g.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(SearchBar), findsOneWidget);
}

/// Real Roboto and Material Icons from the Flutter SDK, so text is
/// measured as on a device (the default test font draws wide squares).
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('$dir/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

/// Set CATALOG_SHOTS=1 to also write PNG screenshots (test/goldens/).
final _shots = Platform.environment['CATALOG_SHOTS'] == '1';

void main() {
  setUpAll(() async {
    if (Platform.environment['NO_REAL_FONTS'] != '1') await loadRealFonts();
  });
  for (final (label, size, scale) in [
    ('small phone', const Size(340, 720), 1.0),
    ('phone, large text', const Size(390, 844), 1.3),
    ('tablet', const Size(820, 1180), 1.0),
    ('desktop', const Size(1440, 900), 1.0),
    ('wide desktop', const Size(2200, 1200), 1.0),
  ]) {
    testWidgets('home lays out and scrolls without overflow on $label', (
      tester,
    ) async {
      await pumpHome(tester, size: size, textScale: scale);
      expect(find.text('Shop by category'), findsOneWidget);
      expect(find.text('Featured'), findsWidgets);
      if (_shots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/home_${label.replaceAll(RegExp('[^a-z]+'), '_')}.png',
          ),
        );
      }
      await scrollThrough(tester);
      if (_shots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/home_${label.replaceAll(RegExp('[^a-z]+'), '_')}_scrolled.png',
          ),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  // Kiswahili strings run longer than English: same layout checks in sw.
  for (final (label, size) in [
    ('small phone', const Size(340, 720)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('home in Kiswahili lays out without overflow on $label', (
      tester,
    ) async {
      await pumpHome(tester, size: size, locale: const Locale('sw'));
      expect(find.text('Nunua kwa aina'), findsOneWidget);
      if (_shots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/home_sw_${label.replaceAll(RegExp('[^a-z]+'), '_')}.png',
          ),
        );
      }
      await scrollThrough(tester);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('choosing a category switches to results and back', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(390, 844));
    await tester.tap(find.text('Hoodies').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Shop by category'), findsNothing);
    expect(find.byTooltip('Back to home'), findsOneWidget);

    await tester.tap(find.byTooltip('List view'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Back to home'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Shop by category'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('filter sheet opens and shows a live count', (tester) async {
    await pumpHome(tester, size: const Size(390, 844));
    await tester.scrollUntilVisible(
      find.text('Filter'),
      400,
      scrollable: find
          .descendant(of: _outer, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Filter').first);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.textContaining('Show'), findsOneWidget);
    await tester.tap(find.text('Can add my logo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('empty catalog shows the empty state', (tester) async {
    await pumpHome(tester, size: const Size(390, 844), items: const []);
    expect(find.text('No items in the catalog yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  test('bulk saving and sort', () {
    final tiered = sampleItems[1]; // 800 → 600
    expect(tiered.bulkSavingPercent, 25);
    final byPrice = sortCatalog(sampleItems, CatalogSort.priceLow);
    expect(byPrice.first.fromPrice <= byPrice.last.fromPrice, isTrue);
    final rec = sortCatalog(sampleItems, CatalogSort.recommended);
    expect(rec.first.isFeatured, isTrue);
  });
}
