import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formatting/currency.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/catalog_image.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/catalog_category.dart';
import '../../../catalog/domain/catalog_item.dart';
import '../../../marketing/application/marketing_providers.dart';
import '../../../marketing/domain/announcement_model.dart';
import '../../../payments/application/payments_providers.dart';
import 'catalog_item_card.dart';

/// Content width breakpoints shared by the home sections.
bool isWideCatalog(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 900;

// ---------------------------------------------------------------- Hero

/// One slide of the promo carousel.
class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    this.imageUrl,
    this.endsAt,
    this.action,
    this.onTap,
    this.icon = Icons.campaign_rounded,
  });

  final String title;
  final String body;
  final String? imageUrl;
  final DateTime? endsAt;
  final String? action;
  final VoidCallback? onTap;
  final IconData icon;
}

/// Auto-playing promo carousel (Marketing announcements, with a countdown
/// when one ends within a week). With no announcements it shows the two
/// standing offers — design your own and bulk quotes — so the page never
/// opens on a blank band. On desktop, two shortcut tiles sit beside it.
class HomeHeroSection extends ConsumerWidget {
  const HomeHeroSection({super.key, required this.onDesign});

  final VoidCallback onDesign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final showAnnouncements = ref.watch(inAppNotificationsEnabledProvider);
    final announcements = showAnnouncements
        ? (ref.watch(activeAnnouncementsProvider).valueOrNull ??
              const <AnnouncementModel>[])
        : const <AnnouncementModel>[];
    final now = DateTime.now();
    final slides = <_Slide>[
      for (final a in announcements)
        _Slide(
          title: a.title,
          body: a.message,
          imageUrl: a.imageUrl,
          endsAt:
              a.validTo != null &&
                  a.validTo!.isAfter(now) &&
                  a.validTo!.difference(now).inDays < 7
              ? a.validTo
              : null,
        ),
      _Slide(
        title: l10n.customiseCtaTitle,
        body: l10n.customiseCtaBody,
        action: l10n.customiseCtaAction,
        onTap: onDesign,
        icon: Icons.brush_rounded,
      ),
      _Slide(
        title: l10n.bulkQuoteTitle,
        body: l10n.bulkQuoteBody,
        action: l10n.bulkQuoteAction,
        onTap: () => context.push('/customer/quotes'),
        icon: Icons.request_quote_rounded,
      ),
    ];
    final wide = isWideCatalog(context);
    final ts = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final carousel = _Carousel(slides: slides, height: wide ? 300 : 176 * ts);
    if (!wide) return carousel;
    return SizedBox(
      height: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: carousel),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SideTile(
                    icon: Icons.request_quote_rounded,
                    title: l10n.bulkQuoteTitle,
                    body: l10n.bulkQuoteAction,
                    onTap: () => context.push('/customer/quotes'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _SideTile(
                    icon: Icons.local_shipping_rounded,
                    title: l10n.trackOrderTitle,
                    body: l10n.trackOrderBody,
                    onTap: () => context.go('/customer/tracking'),
                    tinted: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({required this.slides, required this.height});

  final List<_Slide> slides;
  final double height;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_paused || !mounted || widget.slides.length < 2) return;
      if (!_controller.hasClients) return;
      final next = (_page + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final n = widget.slides.length;
    _controller.animateToPage(
      (_page + delta + n) % n,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final wide = isWideCatalog(context);
    return MouseRegion(
      onEnter: (_) => _paused = true,
      onExit: (_) => _paused = false,
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Listener(
                onPointerDown: (_) => _paused = true,
                onPointerUp: (_) => _paused = false,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) =>
                      _SlideView(slide: slides[i], wide: wide),
                ),
              ),
              if (wide && slides.length > 1) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _go(-1),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _go(1),
                    ),
                  ),
                ),
              ],
              if (slides.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: i == _page ? 0.95 : 0.5,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        foregroundColor: Colors.black87,
      ),
      icon: Icon(icon),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.wide});

  final _Slide slide;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = (slide.imageUrl ?? '').isNotEmpty;
    return GestureDetector(
      onTap: slide.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CatalogImage(
              imageUrls: [slide.imageUrl!],
              placeholderIcon: slide.icon,
              borderRadius: BorderRadius.zero,
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(gradient: BrandColors.brandGradient),
            ),
          if (!hasImage)
            Positioned(
              right: -24,
              bottom: -24,
              child: Icon(
                slide.icon,
                size: wide ? 260 : 150,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: hasImage ? 0.62 : 0.0),
                  Colors.black.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 64 : 18,
              14,
              wide ? 64 : 18,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (slide.endsAt != null) ...[
                  _Countdown(endsAt: slide.endsAt!),
                  const SizedBox(height: 8),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (wide
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(
                      slide.body,
                      maxLines: wide ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (wide
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.bodySmall)
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                    ),
                  ),
                ),
                if (slide.action != null) ...[
                  SizedBox(height: wide ? 18 : 10),
                  FilledButton(
                    onPressed: slide.onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BrandColors.brushRedDeep,
                      visualDensity: wide ? null : VisualDensity.compact,
                    ),
                    child: Text(slide.action!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ends in 2d 04:13:22", ticking every second.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = widget.endsAt.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final text =
        '${left.inDays > 0 ? '${left.inDays}d ' : ''}${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB020),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).endsIn(text),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.black87,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.tinted = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: tinted ? scheme.secondaryContainer : scheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(icon, size: 40, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Categories

/// Round category shortcuts (Kilimall/Jumia "shop by category").
class CategoryTilesSection extends ConsumerWidget {
  const CategoryTilesSection({super.key});

  static const _tints = [
    Color(0xFFFFE4E6),
    Color(0xFFE0F2FE),
    Color(0xFFFEF3C7),
    Color(0xFFDCFCE7),
    Color(0xFFEDE9FE),
    Color(0xFFFFEDD5),
    Color(0xFFFCE7F3),
    Color(0xFFE2E8F0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(activeCatalogItemsProvider).valueOrNull ?? const [];
    final counts = <CatalogCategory, int>{};
    for (final i in items) {
      counts[i.category] = (counts[i.category] ?? 0) + 1;
    }
    // Categories with products first, empty ones after.
    final categories = [...CatalogCategory.values]
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wide = isWideCatalog(context);

    Widget tile(int i, CatalogCategory c) => _CategoryTile(
      category: c,
      count: counts[c] ?? 0,
      tint: dark
          ? _tints[i % _tints.length].withValues(alpha: 0.16)
          : _tints[i % _tints.length],
      onTap: () {
        ref.read(catalogCategoryFilterProvider.notifier).state = c;
      },
    );

    return _Section(
      title: AppLocalizations.of(context).shopByCategory,
      child: wide
          ? Row(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Expanded(child: tile(i, categories[i])),
              ],
            )
          : SizedBox(
              height:
                  108 *
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, i) =>
                    SizedBox(width: 78, child: tile(i, categories[i])),
              ),
            ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.category,
    required this.count,
    required this.tint,
    required this.onTap,
  });

  final CatalogCategory category;
  final int count;
  final Color tint;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${widget.category.label}, ${widget.count} items',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hover = h),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _hover ? 1.08 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.category.icon,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.category.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Trust

/// Slim strip of reasons to buy here.
class TrustStrip extends ConsumerWidget {
  const TrustStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(businessSettingsProvider).valueOrNull;
    final threshold = settings?.freeDeliveryThreshold ?? 0;
    final entries = <(IconData, String)>[
      if (threshold > 0)
        (
          Icons.local_shipping_outlined,
          l10n.trustFreeDelivery(currencyFormat.format(threshold)),
        ),
      (Icons.phone_iphone_rounded, l10n.trustPayments),
      (Icons.fact_check_outlined, l10n.trustProof),
      (Icons.trending_down_rounded, l10n.trustBulk),
    ];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget chip((IconData, String) e) => Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(e.$1, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            e.$2,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: isWideCatalog(context)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [for (final e in entries) chip(e)],
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final e in entries) Center(child: chip(e))],
            ),
    );
  }
}

// -------------------------------------------------------------- Rails

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.icon,
    this.onSeeAll,
    this.accent,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onSeeAll;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: accent ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context).seeAll),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A titled horizontal row of product cards with "See all".
class ProductRail extends StatefulWidget {
  const ProductRail({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.onOpen,
    required this.onAdd,
    this.onSeeAll,
    this.accent,
  });

  final String title;
  final IconData icon;
  final List<CatalogItem> items;
  final void Function(CatalogItem) onOpen;
  final Future<void> Function(CatalogItem) onAdd;
  final VoidCallback? onSeeAll;
  final Color? accent;

  @override
  State<ProductRail> createState() => _ProductRailState();
}

class _ProductRailState extends State<ProductRail> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideCatalog(context);
    final w = wide ? 196.0 : 150.0;
    final ts = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final h = w + catalogCardInfoHeight * ts;
    final list = ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      itemCount: widget.items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final item = widget.items[i];
        return SizedBox(
          width: w,
          child: CatalogItemCard(
            item: item,
            onTap: () => widget.onOpen(item),
            onAddToCart: () => widget.onAdd(item),
          ),
        );
      },
    );
    return _Section(
      title: widget.title,
      icon: widget.icon,
      accent: widget.accent,
      onSeeAll: widget.onSeeAll,
      child: SizedBox(
        height: h + 8,
        child: wide
            ? Stack(
                children: [
                  Positioned.fill(child: list),
                  _RailArrow(
                    controller: _scroll,
                    left: true,
                    step: (w + 10) * 3,
                  ),
                  _RailArrow(
                    controller: _scroll,
                    left: false,
                    step: (w + 10) * 3,
                  ),
                ],
              )
            : list,
      ),
    );
  }
}

/// Desktop scroll arrows on a rail; hidden at either end.
class _RailArrow extends StatefulWidget {
  const _RailArrow({
    required this.controller,
    required this.left,
    required this.step,
  });

  final ScrollController controller;
  final bool left;
  final double step;

  @override
  State<_RailArrow> createState() => _RailArrowState();
}

class _RailArrowState extends State<_RailArrow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final visible =
        c.hasClients &&
        c.position.hasContentDimensions &&
        (widget.left
            ? c.offset > 4
            : c.offset < c.position.maxScrollExtent - 4);
    return Positioned(
      left: widget.left ? 4 : null,
      right: widget.left ? null : 4,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: _Arrow(
              icon: widget.left
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              onTap: () => c.animateTo(
                (c.offset + (widget.left ? -widget.step : widget.step)).clamp(
                  0,
                  c.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bundles (Packages) as a rail of wide cards.
class PackagesRail extends ConsumerWidget {
  const PackagesRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(activePackagesProvider).valueOrNull ?? const [];
    if (packages.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final wide = isWideCatalog(context);
    return _Section(
      title: AppLocalizations.of(context).sectionBundles,
      icon: Icons.inventory_2_rounded,
      onSeeAll: () => context.go('/customer/packages'),
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: packages.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final p = packages[i];
            return SizedBox(
              width: wide ? 340 : 280,
              child: Material(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/customer/packages'),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 112,
                        child: CatalogImage(
                          imageUrls: [
                            if ((p.imageUrl ?? '').isNotEmpty) p.imageUrl!,
                          ],
                          placeholderIcon: Icons.inventory_2_outlined,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p.itemIds.length} items · ${currencyFormat.format(p.price)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Embroidery-specific call to action between the rails.
class DesignYourOwnBanner extends StatelessWidget {
  const DesignYourOwnBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: BrandColors.brandGradient),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.brush_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.customiseCtaTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.customiseCtaBody,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
