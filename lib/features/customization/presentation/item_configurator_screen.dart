import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../shared/widgets/auth_required_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../customer/application/cart_providers.dart';
import '../../growth/companies.dart';
import '../application/customization_providers.dart';
import '../domain/artwork.dart';
import '../domain/customization_options.dart';
import '../domain/customization_pricing.dart';
import 'widgets/artwork_picker.dart';
import 'widgets/mockup_preview.dart';

/// Configure a customisable item: colour, quantities per size, logo/text
/// decorations on a live mockup, optional names, and a live price. With
/// [lineId] it edits an existing cart line instead of adding a new one.
class ItemConfiguratorScreen extends ConsumerWidget {
  const ItemConfiguratorScreen({
    super.key,
    required this.itemId,
    this.lineId,
    this.programKey,
  });

  final String itemId;
  final String? lineId;

  /// "companyId/programId/index" — start from a uniform program item
  /// (approved artwork and placements); the buyer just adds sizes.
  final String? programKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeCatalogItemsProvider);
    final item = itemsAsync.valueOrNull
        ?.where((i) => i.id == itemId)
        .firstOrNull;
    final fromProgram = programKey == null
        ? null
        : ref.watch(programItemProvider(programKey!)).valueOrNull;
    final existing = lineId == null
        ? fromProgram
        : ref.watch(cartStateProvider).valueOrNull?.lines[lineId];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/customer/catalog/$itemId'),
        ),
        title: Text(item == null ? 'Customise' : 'Customise ${item.name}'),
      ),
      body: itemsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : item == null
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Item not available',
              message: 'It may have been removed from the catalog.',
            )
          : !item.isCustomizable
          ? const EmptyState(
              icon: Icons.block_rounded,
              title: 'Not customisable',
              message: 'This item is sold as-is. Add it from its page.',
            )
          : _Configurator(
              key: ValueKey('${item.id}-$lineId-${existing != null}'),
              item: item,
              lineId: lineId,
              initial: existing,
            ),
    );
  }
}

class _Configurator extends ConsumerStatefulWidget {
  const _Configurator({
    super.key,
    required this.item,
    required this.lineId,
    required this.initial,
  });

  final CatalogItem item;
  final String? lineId;
  final CustomLineConfig? initial;

  @override
  ConsumerState<_Configurator> createState() => _ConfiguratorState();
}

class _ConfiguratorState extends ConsumerState<_Configurator> {
  late CustomLineConfig _config;
  final Map<String, TextEditingController> _qty = {};
  late final TextEditingController _names;
  bool _saving = false;

  CatalogItem get item => widget.item;

  List<String> get _sizeLabels => item.sizes.isEmpty
      ? const [oneSizeLabel]
      : item.sizes.map((s) => s.label).toList();

  @override
  void initState() {
    super.initState();
    _config =
        widget.initial ??
        CustomLineConfig(
          itemId: item.id,
          colour: item.colours.isEmpty ? null : item.colours.first.name,
          sizeQuantities: {if (item.sizes.isEmpty) oneSizeLabel: item.moq},
          decorations: [
            DecorationChoice(
              method: item.decorationMethods.first,
              placement: item.placements.first,
            ),
          ],
        );
    for (final label in _sizeLabels) {
      final q = _config.sizeQuantities[label] ?? 0;
      _qty[label] = TextEditingController(text: q > 0 ? '$q' : '');
    }
    _names = TextEditingController(text: _config.names.join('\n'));
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _names.dispose();
    super.dispose();
  }

  void _update(CustomLineConfig next) => setState(() => _config = next);

  void _updateDecoration(int i, DecorationChoice d) {
    final list = [..._config.decorations];
    list[i] = d;
    _update(_config.copyWith(decorations: list));
  }

  bool _requireSignIn(String message) {
    if (ref.read(currentUidProvider) != null) return false;
    showAuthRequiredSheet(context, message: message);
    return true;
  }

  Future<void> _pickArtwork(int i) async {
    if (_requireSignIn(
      'Sign in to upload your logo and save it to your library.',
    )) {
      return;
    }
    final Artwork? art = await showArtworkPicker(context);
    if (art == null) return;
    _updateDecoration(
      i,
      _config.decorations[i].copyWith(
        artworkId: art.id,
        artworkName: art.name,
        artworkUrl: art.fileUrl,
        stitchCount: art.stitchCount,
        digitized: art.digitized,
      ),
    );
  }

  /// Artwork facts (digitized / stitch count) come from the library so the
  /// preview price matches what the server will charge.
  CustomLineConfig _withArtworkFacts(List<Artwork> library) {
    final byId = {for (final a in library) a.id: a};
    return _config.copyWith(
      decorations: [
        for (final d in _config.decorations)
          if (d.artworkId != null && byId[d.artworkId] != null)
            d.copyWith(
              stitchCount: byId[d.artworkId]!.stitchCount,
              digitized: byId[d.artworkId]!.digitized,
            )
          else
            d,
      ],
    );
  }

  Future<void> _save() async {
    if (_requireSignIn(
      'Sign in or create an account to add this to your cart.',
    )) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(cartActionsProvider)
          .saveCustomLine(_config, lineId: widget.lineId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      if (widget.lineId != null) {
        router.pop();
      } else {
        router.go('/customer/cart');
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.lineId != null
                ? 'Cart updated'
                : '${item.name} added to your cart',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pricing =
        ref.watch(decorationPricingProvider).valueOrNull ??
        DecorationPricing.defaults;
    final library = ref.watch(myArtworksProvider).valueOrNull ?? const [];
    final priced = _withArtworkFacts(library);
    final problem = CustomizationPricing.validate(item, priced, pricing);
    final price = CustomizationPricing.price(item, priced, pricing);
    final colour = item.colours
        .where((c) => c.name == _config.colour)
        .firstOrNull
        ?.color;
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    final mockup = MockupPreview(
      productImageUrls: item.imageUrls,
      placeholderIcon: item.category.icon,
      decorations: _config.decorations,
      garmentColour: colour,
      onMoved: (i, x, y) => _updateDecoration(
        i,
        _config.decorations[i].copyWith(offsetX: x, offsetY: y),
      ),
    );

    final options = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.colours.isNotEmpty) ...[
          _Heading('Colour', _config.colour),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in item.colours)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: c.color, radius: 9),
                  label: Text(c.name),
                  selected: _config.colour == c.name,
                  onSelected: (_) => _update(_config.copyWith(colour: c.name)),
                ),
            ],
          ),
        ],
        _Heading(
          'Quantity',
          'Minimum ${item.moq} pcs${item.priceTiers.isEmpty ? '' : ' · ${item.priceTiers.map((t) => '${t.minQty}+ @ ${currencyFormat.format(t.unitPrice)}').join(' · ')}'}',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final label in _sizeLabels)
              SizedBox(
                width: item.sizes.isEmpty ? 160 : 86,
                child: TextField(
                  controller: _qty[label],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: item.sizes.isEmpty ? 'Pieces' : label,
                    helperText: () {
                      final s = item.sizes
                          .where((s) => s.label == label)
                          .firstOrNull;
                      return s != null && s.surcharge > 0
                          ? '+${s.surcharge}'
                          : null;
                    }(),
                  ),
                  onChanged: (v) => _update(
                    _config.copyWith(
                      sizeQuantities: {
                        ..._config.sizeQuantities,
                        label: int.tryParse(v) ?? 0,
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        _Heading('Branding', 'Add a logo or text at each placement'),
        for (final (i, d) in _config.decorations.indexed)
          _DecorationCard(
            key: ValueKey('dec-$i'),
            item: item,
            pricing: pricing,
            decoration: d,
            usedPlacements: {
              for (final (j, other) in _config.decorations.indexed)
                if (j != i) other.placement,
            },
            onChanged: (next) => _updateDecoration(i, next),
            onPickArtwork: () => _pickArtwork(i),
            onRemove: () => _update(
              _config.copyWith(
                decorations: [..._config.decorations]..removeAt(i),
              ),
            ),
          ),
        if (_config.decorations.length < 6 &&
            item.placements.any(
              (p) => !_config.decorations.any((d) => d.placement == p),
            ))
          TextButton.icon(
            onPressed: () {
              final free = item.placements.firstWhere(
                (p) => !_config.decorations.any((d) => d.placement == p),
              );
              _update(
                _config.copyWith(
                  decorations: [
                    ..._config.decorations,
                    DecorationChoice(
                      method: item.decorationMethods.first,
                      placement: free,
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another placement'),
          ),
        _Heading(
          'Names (optional)',
          'One per line, e.g. staff names — ${currencyFormat.format(pricing.personalisationFee)} per piece',
        ),
        TextField(
          controller: _names,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Jane W.\nOtieno K.'),
          onChanged: (v) => _update(
            _config.copyWith(
              names: v
                  .split('\n')
                  .map((n) => n.trim())
                  .where((n) => n.isNotEmpty)
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _PriceBreakdown(price: price, pricing: pricing),
      ],
    );

    final bottomBar = Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currencyFormat.format(price.lineTotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      problem ??
                          '${price.quantity} pcs · ${currencyFormat.format(price.unitPrice)} each',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: problem == null ? null : theme.colorScheme.error,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: problem != null || _saving ? null : _save,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(
                  widget.lineId == null ? 'Add to cart' : 'Update cart',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: mockup,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 12, 20, 20),
                        child: options,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: mockup,
                    ),
                    options,
                  ],
                ),
        ),
        bottomBar,
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, [this.hint]);

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DecorationCard extends StatefulWidget {
  const _DecorationCard({
    super.key,
    required this.item,
    required this.pricing,
    required this.decoration,
    required this.usedPlacements,
    required this.onChanged,
    required this.onPickArtwork,
    required this.onRemove,
  });

  final CatalogItem item;
  final DecorationPricing pricing;
  final DecorationChoice decoration;
  final Set<Placement> usedPlacements;
  final ValueChanged<DecorationChoice> onChanged;
  final VoidCallback onPickArtwork;
  final VoidCallback onRemove;

  @override
  State<_DecorationCard> createState() => _DecorationCardState();
}

class _DecorationCardState extends State<_DecorationCard> {
  late final _text = TextEditingController(text: widget.decoration.text ?? '');
  late final _threads = TextEditingController(
    text: widget.decoration.threadColours.join(', '),
  );

  @override
  void dispose() {
    _text.dispose();
    _threads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.decoration;
    final methods = widget.item.decorationMethods
        .where((m) => widget.pricing.of(m).enabled)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Placement>(
                    value: d.placement,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final p in widget.item.placements)
                        if (p == d.placement ||
                            !widget.usedPlacements.contains(p))
                          DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) => widget.onChanged(
                      DecorationChoice(
                        method: d.method,
                        placement: p!,
                        sizeClass: d.sizeClass,
                        artworkId: d.artworkId,
                        artworkName: d.artworkName,
                        artworkUrl: d.artworkUrl,
                        text: d.text,
                        threadColours: d.threadColours,
                        stitchCount: d.stitchCount,
                        digitized: d.digitized,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove placement',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in methods)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 16),
                    label: Text(m.label),
                    tooltip: m.description,
                    selected: d.method == m,
                    onSelected: (_) => widget.onChanged(d.copyWith(method: m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final s in SizeClass.values)
                  ChoiceChip(
                    label: Text('${s.label} (${s.hint})'),
                    selected: d.sizeClass == s,
                    onSelected: (_) =>
                        widget.onChanged(d.copyWith(sizeClass: s)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onPickArtwork,
                    icon: Icon(
                      d.artworkId == null
                          ? Icons.upload_rounded
                          : Icons.image_outlined,
                    ),
                    label: Text(
                      d.artworkName ?? 'Upload / choose logo',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (d.artworkId != null)
                  IconButton(
                    tooltip: 'Remove logo',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () =>
                        widget.onChanged(d.copyWith(clearArtwork: true)),
                  ),
              ],
            ),
            if (d.digitized && d.method == DecorationMethod.embroidery)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Already digitized — no digitizing fee.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: d.artworkId == null
                    ? 'Or text to print/stitch'
                    : 'Extra text (optional)',
                isDense: true,
              ),
              onChanged: (v) => widget.onChanged(d.copyWith(text: v)),
            ),
            if (d.method.usesThreadColours)
              TextField(
                controller: _threads,
                decoration: const InputDecoration(
                  labelText: 'Thread colours (comma separated)',
                  hintText: 'e.g. White, Gold',
                  isDense: true,
                ),
                onChanged: (v) => widget.onChanged(
                  d.copyWith(
                    threadColours: v
                        .split(',')
                        .map((c) => c.trim())
                        .where((c) => c.isNotEmpty)
                        .take(15)
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.price, required this.pricing});

  final LinePrice price;
  final DecorationPricing pricing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, num value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(currencyFormat.format(value), style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            row(
              'Blanks (${price.quantity} × ${currencyFormat.format(price.tierUnitPrice)}${price.blankTotal != price.quantity * price.tierUnitPrice ? ' + size surcharges' : ''})',
              price.blankTotal,
            ),
            if (price.decorationTotal > 0)
              row(
                'Branding (${currencyFormat.format(price.decorationPerUnit)} per piece)',
                price.decorationTotal,
              ),
            if (price.setupFees > 0)
              row('One-off setup / digitizing', price.setupFees),
            if (price.personalisationTotal > 0)
              row('Names', price.personalisationTotal),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Item total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  currencyFormat.format(price.lineTotal),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Delivery and VAT are added at checkout. You\'ll approve a digital proof before we produce anything.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
