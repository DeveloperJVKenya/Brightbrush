import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/currency.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/search/search_utils.dart';
import '../../../../shared/widgets/catalog_image.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/catalog_category.dart';
import '../../../catalog/domain/catalog_item.dart';
import 'ai_search_dialog.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/l10n/enum_l10n.dart';

String catalogSortLabel(AppLocalizations l10n, CatalogSort s) => switch (s) {
  CatalogSort.recommended => l10n.sortRecommended,
  CatalogSort.priceLow => l10n.sortPriceLow,
  CatalogSort.priceHigh => l10n.sortPriceHigh,
  CatalogSort.newest => l10n.sortNewest,
  CatalogSort.topRated => l10n.sortTopRated,
  CatalogSort.bulkSaving => l10n.sortBulkSaving,
};

/// The marketplace search box: suggestions while typing (matching products
/// with photo and price, recent searches, categories), full-screen on
/// phones and a dropdown on desktop. Submitting shows the results page.
class CatalogSearchBar extends ConsumerStatefulWidget {
  const CatalogSearchBar({super.key, required this.onOpenItem});

  final void Function(CatalogItem) onOpenItem;

  @override
  ConsumerState<CatalogSearchBar> createState() => _CatalogSearchBarState();
}

class _CatalogSearchBarState extends ConsumerState<CatalogSearchBar> {
  late final SearchController _controller = SearchController()
    ..text = ref.read(catalogSearchQueryProvider);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final v = value.trim();
    ref.read(catalogSearchQueryProvider.notifier).state = v;
    if (v.isNotEmpty) ref.read(recentSearchesProvider.notifier).add(v);
    if (_controller.isOpen) _controller.closeView(v);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Keep the box in step when the query changes elsewhere (reset, AI).
    ref.listen<String>(catalogSearchQueryProvider, (_, next) {
      if (_controller.text != next) _controller.text = next;
    });
    final query = ref.watch(catalogSearchQueryProvider);

    return SearchAnchor(
      searchController: _controller,
      viewHintText: l10n.homeSearchHint,
      viewOnSubmitted: _submit,
      viewConstraints: const BoxConstraints(maxHeight: 520),
      builder: (context, controller) => SearchBar(
        controller: controller,
        hintText: l10n.homeSearchHint,
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        constraints: const BoxConstraints(minHeight: 46, maxHeight: 46),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        leading: const Icon(Icons.search_rounded),
        onTap: controller.openView,
        onChanged: (_) => controller.openView(),
        onSubmitted: _submit,
        trailing: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: context.l10n.clearSearch,
              onPressed: () {
                controller.clear();
                _submit('');
              },
              icon: const Icon(Icons.close_rounded),
            ),
          Tooltip(
            message: l10n.askAi,
            child: IconButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AiSearchDialog(),
              ),
              icon: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
            ),
          ),
        ],
      ),
      suggestionsBuilder: (context, controller) =>
          _suggestions(context, controller.text),
    );
  }

  List<Widget> _suggestions(BuildContext context, String text) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.read(activeCatalogItemsProvider).valueOrNull ?? const [];
    if (text.trim().isEmpty) {
      final recent = ref.read(recentSearchesProvider);
      return [
        if (recent.isNotEmpty) ...[
          ListTile(
            dense: true,
            title: Text(l10n.recentSearches, style: theme.textTheme.labelLarge),
            trailing: TextButton(
              onPressed: () {
                ref.read(recentSearchesProvider.notifier).clear();
                _controller.text = '';
              },
              child: Text(l10n.clearAll),
            ),
          ),
          for (final r in recent)
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(r),
              trailing: const Icon(Icons.north_west_rounded, size: 18),
              onTap: () {
                _controller.text = r;
                _submit(r);
              },
            ),
          const Divider(),
        ],
        ListTile(
          dense: true,
          title: Text(l10n.shopByCategory, style: theme.textTheme.labelLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in CatalogCategory.values)
                ActionChip(
                  avatar: Icon(c.icon, size: 16),
                  label: Text(c.tr(context)),
                  onPressed: () {
                    _controller.closeView('');
                    ref.read(catalogCategoryFilterProvider.notifier).state = c;
                  },
                ),
            ],
          ),
        ),
      ];
    }
    final matches = filterBySearch(
      items,
      text,
      (i) => i.searchFields,
    ).take(6).toList();
    return [
      ListTile(
        leading: const Icon(Icons.search_rounded),
        title: Text(l10n.searchFor(text.trim())),
        onTap: () => _submit(text),
      ),
      for (final item in matches)
        ListTile(
          leading: SizedBox.square(
            dimension: 44,
            child: CatalogImage(
              imageUrls: item.imageUrls,
              placeholderIcon: item.category.icon,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${item.category.tr(context)} · ${currencyFormat.format(item.fromPrice)}',
          ),
          onTap: () {
            ref.read(recentSearchesProvider.notifier).add(text);
            _controller.closeView(_controller.text);
            widget.onOpenItem(item);
          },
        ),
    ];
  }
}

/// Bottom sheet listing the sort orders.
Future<void> showCatalogSortSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (context) {
      final current = ref.read(catalogSortProvider);
      return SafeArea(
        child: RadioGroup<CatalogSort>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) ref.read(catalogSortProvider.notifier).state = v;
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.sortLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              for (final s in CatalogSort.values)
                RadioListTile<CatalogSort>(
                  value: s,
                  title: Text(catalogSortLabel(l10n, s)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// Filter sheet: category, price range, "can add my logo", rating and
/// how soon it's ready, with a live count on the apply button.
Future<void> showCatalogFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late CatalogFilters _f = ref.read(catalogFiltersProvider);
  late CatalogCategory? _category = ref.read(catalogCategoryFilterProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.watch(activeCatalogItemsProvider).valueOrNull ?? const [];
    final query = ref.watch(catalogSearchQueryProvider);
    final prices = items.map((i) => i.fromPrice.toDouble()).toList()..sort();
    final lo = prices.isEmpty ? 0.0 : prices.first.floorToDouble();
    final hi = prices.isEmpty ? 0.0 : prices.last.ceilToDouble();
    final range = RangeValues(
      (_f.minPrice?.toDouble() ?? lo).clamp(lo, hi),
      (_f.maxPrice?.toDouble() ?? hi).clamp(lo, hi),
    );
    final count = filterBySearch(
      items
          .where((i) => _category == null || i.category == _category)
          .where(_f.matches)
          .toList(),
      query,
      (i) => i.searchFields,
    ).length;

    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        t,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.filterLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _f = const CatalogFilters();
                    _category = null;
                  }),
                  child: Text(l10n.clearAll),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading(l10n.filterCategory),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.allCategories),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                        for (final c in CatalogCategory.values)
                          ChoiceChip(
                            avatar: Icon(c.icon, size: 16),
                            label: Text(c.tr(context)),
                            selected: _category == c,
                            onSelected: (s) =>
                                setState(() => _category = s ? c : null),
                          ),
                      ],
                    ),
                    if (hi > lo) ...[
                      heading(l10n.filterPrice),
                      RangeSlider(
                        values: range,
                        min: lo,
                        max: hi,
                        divisions: 20,
                        labels: RangeLabels(
                          currencyFormat.format(range.start),
                          currencyFormat.format(range.end),
                        ),
                        onChanged: (v) => setState(() {
                          _f = CatalogFilters(
                            minPrice: v.start <= lo ? null : v.start,
                            maxPrice: v.end >= hi ? null : v.end,
                            customisableOnly: _f.customisableOnly,
                            minRating: _f.minRating,
                            maxLeadDays: _f.maxLeadDays,
                          );
                        }),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currencyFormat.format(range.start),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            currencyFormat.format(range.end),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.brush_rounded),
                      title: Text(l10n.filterCustomisable),
                      value: _f.customisableOnly,
                      onChanged: (v) =>
                          setState(() => _f = _copy(customisable: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF5A623),
                      ),
                      title: Text(l10n.filterRating),
                      value: _f.minRating >= 4,
                      onChanged: (v) =>
                          setState(() => _f = _copy(minRating: v ? 4 : 0)),
                    ),
                    heading(l10n.filterLeadTime),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final d in const <int?>[null, 3, 7, 14])
                          ChoiceChip(
                            label: Text(
                              d == null ? l10n.anyTime : l10n.daysCount(d),
                            ),
                            selected: _f.maxLeadDays == d,
                            onSelected: (_) => setState(
                              () => _f = _copy(maxLead: d, setLead: true),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: count == 0
                  ? null
                  : () {
                      ref.read(catalogFiltersProvider.notifier).state = _f;
                      ref.read(catalogCategoryFilterProvider.notifier).state =
                          _category;
                      Navigator.of(context).pop();
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.showResults(count)),
            ),
          ],
        ),
      ),
    );
  }

  CatalogFilters _copy({
    bool? customisable,
    double? minRating,
    int? maxLead,
    bool setLead = false,
  }) => CatalogFilters(
    minPrice: _f.minPrice,
    maxPrice: _f.maxPrice,
    customisableOnly: customisable ?? _f.customisableOnly,
    minRating: minRating ?? _f.minRating,
    maxLeadDays: setLead ? maxLead : _f.maxLeadDays,
  );
}
