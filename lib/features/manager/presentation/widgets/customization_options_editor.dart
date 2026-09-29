import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../catalog/domain/catalog_category.dart';
import '../../../customization/domain/customization_options.dart';

/// Everything a manager sets to make an item customisable.
class CustomizationOptionsValue {
  const CustomizationOptionsValue({
    this.priceTiers = const [],
    this.sizes = const [],
    this.colours = const [],
    this.decorationMethods = const [],
    this.placements = const [],
  });

  final List<PriceTier> priceTiers;
  final List<SizeOption> sizes;
  final List<ColourOption> colours;
  final List<DecorationMethod> decorationMethods;
  final List<Placement> placements;

  CustomizationOptionsValue copyWith({
    List<PriceTier>? priceTiers,
    List<SizeOption>? sizes,
    List<ColourOption>? colours,
    List<DecorationMethod>? decorationMethods,
    List<Placement>? placements,
  }) => CustomizationOptionsValue(
    priceTiers: priceTiers ?? this.priceTiers,
    sizes: sizes ?? this.sizes,
    colours: colours ?? this.colours,
    decorationMethods: decorationMethods ?? this.decorationMethods,
    placements: placements ?? this.placements,
  );
}

const _garmentSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];

const _paletteColours = [
  ColourOption(name: 'Black', hex: '#111111'),
  ColourOption(name: 'White', hex: '#FFFFFF'),
  ColourOption(name: 'Navy', hex: '#1F2A44'),
  ColourOption(name: 'Royal blue', hex: '#2750B8'),
  ColourOption(name: 'Red', hex: '#C62828'),
  ColourOption(name: 'Maroon', hex: '#6D1B2B'),
  ColourOption(name: 'Bottle green', hex: '#1B5E20'),
  ColourOption(name: 'Grey', hex: '#9E9E9E'),
  ColourOption(name: 'Yellow', hex: '#F9D71C'),
  ColourOption(name: 'Orange', hex: '#EF6C00'),
  ColourOption(name: 'Pink', hex: '#EC6FA6'),
  ColourOption(name: 'Beige', hex: '#D9C7A7'),
  ColourOption(name: 'Silver', hex: '#C0C0C0'),
];

/// Sensible starting placements per category, so a manager can switch an
/// item to customisable in one tap and then fine-tune.
List<Placement> suggestedPlacements(CatalogCategory category) =>
    switch (category) {
      CatalogCategory.caps => [
        Placement.capFront,
        Placement.capSide,
        Placement.capBack,
      ],
      CatalogCategory.tshirts ||
      CatalogCategory.hoodies ||
      CatalogCategory.twoPiece ||
      CatalogCategory.embroidery => [
        Placement.leftChest,
        Placement.centerChest,
        Placement.fullFront,
        Placement.upperBack,
        Placement.fullBack,
        Placement.leftSleeve,
        Placement.rightSleeve,
      ],
      CatalogCategory.waterBottles => [
        Placement.productFront,
        Placement.productBack,
        Placement.wrapAround,
      ],
      CatalogCategory.cutlery ||
      CatalogCategory.other => [Placement.productFront, Placement.productBack],
    };

List<DecorationMethod> suggestedMethods(CatalogCategory category) =>
    switch (category) {
      CatalogCategory.caps => [
        DecorationMethod.embroidery,
        DecorationMethod.heatTransfer,
      ],
      CatalogCategory.waterBottles => [
        DecorationMethod.laserEngraving,
        DecorationMethod.sublimation,
      ],
      CatalogCategory.cutlery => [DecorationMethod.laserEngraving],
      CatalogCategory.other => [DecorationMethod.dtf],
      _ => [
        DecorationMethod.embroidery,
        DecorationMethod.screenPrint,
        DecorationMethod.dtf,
        DecorationMethod.heatTransfer,
      ],
    };

class CustomizationOptionsEditor extends StatelessWidget {
  const CustomizationOptionsEditor({
    super.key,
    required this.value,
    required this.category,
    required this.onChanged,
  });

  final CustomizationOptionsValue value;
  final CatalogCategory category;
  final ValueChanged<CustomizationOptionsValue> onChanged;

  bool get _enabled => value.decorationMethods.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String text, [String? hint]) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.labelLarge),
          if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Customisable (logo / text branding)'),
          subtitle: const Text(
            'Customers pick colour, sizes, placements and upload artwork, with a live mockup.',
          ),
          value: _enabled,
          onChanged: (on) => onChanged(
            on
                ? value.copyWith(
                    decorationMethods: suggestedMethods(category),
                    placements: suggestedPlacements(category),
                  )
                : value.copyWith(
                    decorationMethods: const [],
                    placements: const [],
                  ),
          ),
        ),
        if (_enabled) ...[
          heading('Decoration methods'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in DecorationMethod.values)
                FilterChip(
                  avatar: Icon(m.icon, size: 16),
                  label: Text(m.label),
                  selected: value.decorationMethods.contains(m),
                  onSelected: (on) => onChanged(
                    value.copyWith(
                      decorationMethods: on
                          ? [...value.decorationMethods, m]
                          : (value.decorationMethods.toList()..remove(m)),
                    ),
                  ),
                ),
            ],
          ),
          heading('Placements'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in Placement.values)
                FilterChip(
                  label: Text(p.label),
                  selected: value.placements.contains(p),
                  onSelected: (on) => onChanged(
                    value.copyWith(
                      placements: on
                          ? [...value.placements, p]
                          : (value.placements.toList()..remove(p)),
                    ),
                  ),
                ),
            ],
          ),
        ],
        heading(
          'Sizes',
          'Leave empty for one-size items. Tap a size to set a surcharge.',
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in _garmentSizes)
              FilterChip(
                label: Text(() {
                  final s = value.sizes
                      .where((s) => s.label == label)
                      .firstOrNull;
                  return s == null || s.surcharge == 0
                      ? label
                      : '$label +${s.surcharge}';
                }()),
                selected: value.sizes.any((s) => s.label == label),
                onSelected: (on) {
                  if (on) {
                    final sizes = [...value.sizes, SizeOption(label: label)]
                      ..sort(
                        (a, b) => _garmentSizes
                            .indexOf(a.label)
                            .compareTo(_garmentSizes.indexOf(b.label)),
                      );
                    onChanged(value.copyWith(sizes: sizes));
                  } else {
                    onChanged(
                      value.copyWith(
                        sizes: value.sizes
                            .where((s) => s.label != label)
                            .toList(),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
        if (value.sizes.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final next = await _editSurcharges(context, value.sizes);
              if (next != null) onChanged(value.copyWith(sizes: next));
            },
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Size surcharges'),
          ),
        heading('Colours', 'The garment/product colours customers can choose.'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in _paletteColours)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: c.color, radius: 8),
                label: Text(c.name),
                selected: value.colours.any((x) => x.name == c.name),
                onSelected: (on) => onChanged(
                  value.copyWith(
                    colours: on
                        ? [...value.colours, c]
                        : value.colours.where((x) => x.name != c.name).toList(),
                  ),
                ),
              ),
          ],
        ),
        heading(
          'Volume pricing',
          'Lower unit price for bigger orders (replaces the base price).',
        ),
        for (final (i, tier) in value.priceTiers.indexed)
          Row(
            children: [
              Expanded(
                child: Text('${tier.minQty}+ pcs → KES ${tier.unitPrice} each'),
              ),
              IconButton(
                tooltip: 'Remove tier',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => onChanged(
                  value.copyWith(
                    priceTiers: value.priceTiers.toList()..removeAt(i),
                  ),
                ),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: () async {
            final tier = await _addTier(context);
            if (tier == null) return;
            final tiers = [
              ...value.priceTiers.where((t) => t.minQty != tier.minQty),
              tier,
            ]..sort((a, b) => a.minQty.compareTo(b.minQty));
            onChanged(value.copyWith(priceTiers: tiers));
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add price tier'),
        ),
      ],
    );
  }

  Future<PriceTier?> _addTier(BuildContext context) {
    final qty = TextEditingController();
    final price = TextEditingController();
    return showDialog<PriceTier>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Price tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'From quantity'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Unit price (KES)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final q = int.tryParse(qty.text);
              final p = int.tryParse(price.text);
              if (q == null || q < 2 || p == null || p <= 0) return;
              Navigator.pop(context, PriceTier(minQty: q, unitPrice: p));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<List<SizeOption>?> _editSurcharges(
    BuildContext context,
    List<SizeOption> sizes,
  ) {
    final controllers = {
      for (final s in sizes)
        s.label: TextEditingController(text: '${s.surcharge}'),
    };
    return showDialog<List<SizeOption>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Size surcharges (KES per piece)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in sizes)
              TextField(
                controller: controllers[s.label],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: s.label),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              for (final s in sizes)
                SizeOption(
                  label: s.label,
                  surcharge: int.tryParse(controllers[s.label]!.text) ?? 0,
                ),
            ]),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
