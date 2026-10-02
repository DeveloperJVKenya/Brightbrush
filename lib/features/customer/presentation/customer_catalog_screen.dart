import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/monitoring/monitoring.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/auth_required_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/staggered_entrance.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../growth/companies.dart';
import '../../marketing/application/marketing_providers.dart';
import '../application/cart_providers.dart';
import 'widgets/catalog_home_sections.dart';
import 'widgets/catalog_item_card.dart';
import 'widgets/catalog_search_and_filters.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/l10n/enum_l10n.dart';

/// Grid (false) or list (true) on the product listing.
final catalogListViewProvider = StateProvider<bool>((ref) => false);

/// Widest the page content gets on big screens before it centres.
const double _maxContentWidth = 1280;

/// Customer Home. One scroll view in the style of Jumia/Kilimall: only the
/// slim search bar floats back when you scroll up; the promo carousel,
/// category shortcuts and product rails scroll away, and a sort/filter bar
/// pins above the product grid. Searching, picking a category, filtering
/// or "See all" switches the same page into a results listing.
class CustomerCatalogScreen extends ConsumerStatefulWidget {
  const CustomerCatalogScreen({super.key});

  @override
  ConsumerState<CustomerCatalogScreen> createState() =>
      _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends ConsumerState<CustomerCatalogScreen> {
  final _scroll = ScrollController();

  /// Drives only the back-to-top button: flipping it never rebuilds the
  /// page (a full rebuild mid-scroll caused a visible hitch).
  final _showBackToTop = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      _showBackToTop.value = _scroll.offset > 1200;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _showBackToTop.dispose();
    super.dispose();
  }

  void _toTop() {
    if (!_scroll.hasClients || _scroll.offset == 0) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _open(CatalogItem item) => context.push('/customer/catalog/${item.id}');

  void _designYourOwn() {
    ref.read(catalogFiltersProvider.notifier).state = const CatalogFilters(
      customisableOnly: true,
    );
  }

  void _seeAll(CatalogSort sort) {
    ref.read(catalogSortProvider.notifier).state = sort;
    ref.read(catalogViewAllProvider.notifier).state = true;
  }

  Future<void> _add(CatalogItem item) async {
    // Branded items need colour, sizes and artwork first.
    if (item.isCustomizable) {
      await context.push('/customer/catalog/${item.id}/customize');
      return;
    }
    if (ref.read(currentUidProvider) == null) {
      showAuthRequiredSheet(
        context,
        message: context.l10n.signInOrCreateAnAccount(item.name),
      );
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final qty = await ref.read(cartActionsProvider).addCatalogItem(item);
      Monitoring.addToCart(
        id: item.id,
        name: item.name,
        quantity: qty,
        value: item.basePrice * qty,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.addedToCart(item.name, qty)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l10n.cartCount(ref.read(cartItemCountProvider)),
              onPressed: () {
                if (mounted) context.go('/customer/cart');
              },
            ),
          ),
        );
    } catch (error, stack) {
      appLogger.e(
        '[catalog] Failed to add ${item.id} to cart',
        error: error,
        stackTrace: stack,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.couldntAddToCart(friendlyError(error))),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final browsing = ref.watch(catalogBrowsingProvider);
    final listedAsync = ref.watch(filteredCatalogItemsProvider);

    // Any change to what's listed starts the results from the top.
    void jump(Object? _, Object? _) =>
        WidgetsBinding.instance.addPostFrameCallback((_) => _toTop());
    ref.listen<Object?>(catalogSearchQueryProvider, jump);
    ref.listen<Object?>(catalogCategoryFilterProvider, jump);
    ref.listen<Object?>(catalogFiltersProvider, jump);
    ref.listen<Object?>(catalogSortProvider, jump);
    ref.listen<Object?>(catalogViewAllProvider, jump);

    return PopScope(
      // Back from results returns to the home page, like the big stores.
      canPop: !browsing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) resetCatalogBrowsing(ref);
      },
      child: Scaffold(
        floatingActionButton: _CatalogFabs(
          showBackToTop: _showBackToTop,
          onBackToTop: _toTop,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = math.max(
              12.0,
              (constraints.maxWidth - _maxContentWidth) / 2,
            );
            final pad = EdgeInsets.symmetric(horizontal: gutter);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeCatalogItemsProvider);
                ref.invalidate(activeAnnouncementsProvider);
                ref.invalidate(activePackagesProvider);
                await ref
                    .read(activeCatalogItemsProvider.future)
                    .catchError((_) => <CatalogItem>[]);
              },
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 62,
                    titleSpacing: gutter,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 1,
                    title: CatalogSearchBar(onOpenItem: _open),
                  ),
                  if (!browsing)
                    ..._homeSlivers(pad)
                  else
                    _ResultsHeader(padding: pad),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ToolbarDelegate(
                      padding: pad,
                      browsing: browsing,
                      count: listedAsync.valueOrNull?.length,
                      textScale: MediaQuery.textScalerOf(
                        context,
                      ).scale(1).clamp(1.0, 1.3),
                    ),
                  ),
                  ..._listingSlivers(pad, listedAsync),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Home sections, each its own sliver: the scroll view only lays out and
  /// paints the ones near the screen (one big Column had to do all of them
  /// on every frame). Each rail reads its own slice of [homeRailsProvider].
  List<Widget> _homeSlivers(EdgeInsets pad) {
    final l10n = AppLocalizations.of(context);
    Widget section(Widget child, {double top = 0}) => SliverPadding(
      padding: pad.copyWith(top: top),
      sliver: SliverToBoxAdapter(child: child),
    );
    Widget rail(
      String title,
      IconData icon,
      List<CatalogItem> Function(HomeRails r) pick, {
      CatalogSort? seeAll,
      Color? accent,
    }) => section(
      _HomeRail(
        title: title,
        icon: icon,
        pick: pick,
        accent: accent,
        onOpen: _open,
        onAdd: _add,
        onSeeAll: seeAll == null ? null : () => _seeAll(seeAll),
      ),
    );

    return [
      // The carousel animates on its own; a repaint boundary keeps that
      // from repainting the rest of the page.
      section(
        RepaintBoundary(child: HomeHeroSection(onDesign: _designYourOwn)),
        top: 4,
      ),
      section(const TrustStrip()),
      section(
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: MyUniformProgramsCard(),
        ),
      ),
      section(const CategoryTilesSection()),
      rail(l10n.sectionRecentlyViewed, Icons.history_rounded, (r) => r.recent),
      rail(
        l10n.sectionFeatured,
        Icons.bolt_rounded,
        (r) => r.featured,
        seeAll: CatalogSort.recommended,
        accent: const Color(0xFFF79009),
      ),
      rail(
        l10n.sectionBulkDeals,
        Icons.local_offer_rounded,
        (r) => r.deals,
        seeAll: CatalogSort.bulkSaving,
        accent: const Color(0xFFD92D20),
      ),
      section(DesignYourOwnBanner(onTap: _designYourOwn)),
      rail(
        l10n.sectionTopRated,
        Icons.star_rounded,
        (r) => r.topRated,
        seeAll: CatalogSort.topRated,
        accent: const Color(0xFFF5A623),
      ),
      rail(
        l10n.sectionNewArrivals,
        Icons.fiber_new_rounded,
        (r) => r.newArrivals,
        seeAll: CatalogSort.newest,
        accent: const Color(0xFF12B76A),
      ),
      section(const PackagesRail()),
      section(const SizedBox(height: 20)),
    ];
  }

  List<Widget> _listingSlivers(
    EdgeInsets pad,
    AsyncValue<List<CatalogItem>> listed,
  ) {
    final l10n = AppLocalizations.of(context);
    final browsing = ref.read(catalogBrowsingProvider);
    return listed.when(
      loading: () => [
        SliverPadding(
          padding: pad.copyWith(top: 12),
          sliver: const _SkeletonGrid(),
        ),
      ],
      error: (error, stack) {
        appLogger.e(
          '[catalog] Failed to load catalog',
          error: error,
          stackTrace: stack,
        );
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.couldNotLoadCatalog,
                message: friendlyError(error),
                action: TextButton.icon(
                  onPressed: () => ref.invalidate(activeCatalogItemsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              ),
            ),
          ),
        ];
      },
      data: (items) {
        if (items.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: EmptyState(
                  icon: browsing
                      ? Icons.search_off_rounded
                      : Icons.inventory_2_outlined,
                  title: browsing
                      ? l10n.noMatchesTitle
                      : l10n.catalogEmptyTitle,
                  message: browsing
                      ? l10n.noMatchesBody
                      : l10n.catalogEmptyBody,
                  action: browsing
                      ? FilledButton.tonal(
                          onPressed: () => resetCatalogBrowsing(ref),
                          child: Text(l10n.clearAll),
                        )
                      : null,
                ),
              ),
            ),
          ];
        }
        if (ref.watch(catalogListViewProvider)) {
          return [
            SliverPadding(
              padding: pad.copyWith(top: 12),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => StaggeredEntrance(
                  index: i,
                  id: 'list-${items[i].id}',
                  child: CatalogItemListTile(
                    item: items[i],
                    onTap: () => _open(items[i]),
                    onAddToCart: () => _add(items[i]),
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: pad.copyWith(top: 12),
            sliver: _ProductGrid(items: items, onOpen: _open, onAdd: _add),
          ),
        ];
      },
    );
  }
}

/// Responsive product grid: 2 columns on phones up to 6 on wide desktops,
/// rows sized to the card (square photo + info) so nothing overflows.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.items,
    required this.onOpen,
    required this.onAdd,
  });

  final List<CatalogItem> items;
  final void Function(CatalogItem) onOpen;
  final Future<void> Function(CatalogItem) onAdd;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final layout = _gridLayout(constraints.crossAxisExtent, ts);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.$1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: layout.$2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => StaggeredEntrance(
              index: i,
              id: 'grid-${items[i].id}',
              child: CatalogItemCard(
                item: items[i],
                heroTag: 'catalog-item-${items[i].id}',
                onTap: () => onOpen(items[i]),
                onAddToCart: () => onAdd(items[i]),
              ),
            ),
            childCount: items.length,
          ),
        );
      },
    );
  }
}

(int, double) _gridLayout(double width, double textScale) {
  const gap = 12.0;
  final minTile = width < 600 ? 150.0 : 190.0;
  final cols = ((width + gap) / (minTile + gap)).floor().clamp(2, 6);
  final tile = (width - gap * (cols - 1)) / cols;
  return (cols, tile + catalogCardInfoHeight * textScale);
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final layout = _gridLayout(constraints.crossAxisExtent, 1);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.$1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: layout.$2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _Shimmer(color: color),
            childCount: layout.$1 * 3,
          ),
        );
      },
    );
  }
}

/// Opacity pulse over a rounded placeholder while the catalog loads.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.color});

  final Color color;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: 0.4 + _controller.value * 0.3, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Results page heading: what's being shown, quick category switching and
/// removable chips for each active filter.
class _ResultsHeader extends ConsumerWidget {
  const _ResultsHeader({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = ref.watch(catalogSearchQueryProvider).trim();
    final category = ref.watch(catalogCategoryFilterProvider);
    final filters = ref.watch(catalogFiltersProvider);
    final title = query.isNotEmpty
        ? '"$query"'
        : category?.tr(context) ??
              (filters.customisableOnly
                  ? l10n.filterCustomisable
                  : l10n.sectionAllProducts);

    final chips = <Widget>[
      if (query.isNotEmpty)
        InputChip(
          avatar: const Icon(Icons.search_rounded, size: 16),
          label: Text(query),
          onDeleted: () =>
              ref.read(catalogSearchQueryProvider.notifier).state = '',
        ),
      if (category != null)
        InputChip(
          avatar: Icon(category.icon, size: 16),
          label: Text(category.tr(context)),
          onDeleted: () =>
              ref.read(catalogCategoryFilterProvider.notifier).state = null,
        ),
      if (filters.minPrice != null || filters.maxPrice != null)
        InputChip(
          label: Text(l10n.filterPrice),
          onDeleted: () =>
              ref.read(catalogFiltersProvider.notifier).state = CatalogFilters(
                customisableOnly: filters.customisableOnly,
                minRating: filters.minRating,
                maxLeadDays: filters.maxLeadDays,
              ),
        ),
      if (filters.customisableOnly)
        InputChip(
          avatar: const Icon(Icons.brush_rounded, size: 16),
          label: Text(l10n.filterCustomisable),
          onDeleted: () =>
              ref.read(catalogFiltersProvider.notifier).state = CatalogFilters(
                minPrice: filters.minPrice,
                maxPrice: filters.maxPrice,
                minRating: filters.minRating,
                maxLeadDays: filters.maxLeadDays,
              ),
        ),
      if (filters.minRating > 0)
        InputChip(
          label: Text(l10n.filterRating),
          onDeleted: () =>
              ref.read(catalogFiltersProvider.notifier).state = CatalogFilters(
                minPrice: filters.minPrice,
                maxPrice: filters.maxPrice,
                customisableOnly: filters.customisableOnly,
                maxLeadDays: filters.maxLeadDays,
              ),
        ),
      if (filters.maxLeadDays != null)
        InputChip(
          label: Text(
            '${l10n.filterLeadTime} ${l10n.daysCount(filters.maxLeadDays!)}',
          ),
          onDeleted: () =>
              ref.read(catalogFiltersProvider.notifier).state = CatalogFilters(
                minPrice: filters.minPrice,
                maxPrice: filters.maxPrice,
                customisableOnly: filters.customisableOnly,
                minRating: filters.minRating,
              ),
        ),
    ];

    return SliverPadding(
      padding: padding.copyWith(top: 4),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n.backToHome,
                  onPressed: () => resetCatalogBrowsing(ref),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 8, runSpacing: 6, children: chips),
              ),
          ],
        ),
      ),
    );
  }
}

/// The pinned bar above the listing: title and count, Sort, Filter and
/// grid/list toggle.
class _ToolbarDelegate extends SliverPersistentHeaderDelegate {
  _ToolbarDelegate({
    required this.padding,
    required this.browsing,
    required this.count,
    required this.textScale,
  });

  final EdgeInsets padding;
  final bool browsing;
  final int? count;
  final double textScale;

  double get _height => 54 * textScale;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_ToolbarDelegate old) =>
      old.browsing != browsing ||
      old.count != count ||
      old.padding != padding ||
      old.textScale != textScale;

  // A pinned header is asked to build on every scroll frame. Handing back
  // the same widget instance lets Flutter skip rebuilding the bar entirely.
  late final Widget _flat = _build(false);
  late final Widget _raised = _build(true);

  Widget _build(bool raised) => SizedBox(
    height: _height,
    child: _Toolbar(
      padding: padding,
      browsing: browsing,
      count: count,
      raised: raised,
    ),
  );

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => overlapsContent || shrinkOffset > 0 ? _raised : _flat;
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.padding,
    required this.browsing,
    required this.count,
    required this.raised,
  });

  final EdgeInsets padding;
  final bool browsing;
  final int? count;
  final bool raised;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sort = ref.watch(catalogSortProvider);
    final filters = ref.watch(catalogFiltersProvider);
    final category = ref.watch(catalogCategoryFilterProvider);
    final filterCount = filters.activeCount + (category != null ? 1 : 0);
    final listView = ref.watch(catalogListViewProvider);
    final compact = MediaQuery.sizeOf(context).width < 420;

    return Material(
      color: scheme.surface,
      elevation: raised ? 1.5 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (!browsing && !compact)
                      TextSpan(
                        text: '${l10n.sectionAllProducts}  ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (count != null)
                      TextSpan(
                        text: l10n.itemsCount(count!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => showCatalogSortSheet(context, ref),
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              label: Text(
                compact ? l10n.sortLabel : catalogSortLabel(l10n, sort),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => showCatalogFilterSheet(context, ref),
              icon: Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: const Icon(Icons.tune_rounded, size: 18),
              ),
              label: Text(l10n.filterLabel),
            ),
            IconButton(
              tooltip: listView ? l10n.gridView : l10n.listView,
              onPressed: () =>
                  ref.read(catalogListViewProvider.notifier).state = !listView,
              icon: Icon(
                listView ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back-to-top and cart buttons. Rebuild only when the cart count or the
/// back-to-top flag changes, never with the page.
class _CatalogFabs extends ConsumerWidget {
  const _CatalogFabs({required this.showBackToTop, required this.onBackToTop});

  final ValueListenable<bool> showBackToTop;
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cartCount = ref.watch(cartItemCountProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: showBackToTop,
          builder: (context, show, child) => AnimatedScale(
            scale: show ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: child,
          ),
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: l10n.backToTop,
            onPressed: onBackToTop,
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ),
        if (cartCount > 0) ...[
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => context.go('/customer/cart'),
            icon: Badge.count(
              count: cartCount,
              child: const Icon(Icons.shopping_cart_rounded),
            ),
            label: Text(l10n.cartCount(cartCount)),
          ),
        ],
      ],
    );
  }
}

/// One home rail, rebuilt only when its own items change.
class _HomeRail extends ConsumerWidget {
  const _HomeRail({
    required this.title,
    required this.icon,
    required this.pick,
    required this.onOpen,
    required this.onAdd,
    this.onSeeAll,
    this.accent,
  });

  final String title;
  final IconData icon;
  final List<CatalogItem> Function(HomeRails r) pick;
  final void Function(CatalogItem) onOpen;
  final Future<void> Function(CatalogItem) onAdd;
  final VoidCallback? onSeeAll;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeRailsProvider.select(pick));
    if (items.isEmpty) return const SizedBox.shrink();
    return ProductRail(
      title: title,
      icon: icon,
      items: items,
      accent: accent,
      onOpen: onOpen,
      onAdd: onAdd,
      onSeeAll: onSeeAll,
    );
  }
}
