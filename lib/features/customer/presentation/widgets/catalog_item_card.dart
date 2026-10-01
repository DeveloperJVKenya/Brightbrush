import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/formatting/currency.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/auth_required_sheet.dart';
import '../../../../shared/widgets/catalog_image.dart';
import '../../../catalog/domain/catalog_item.dart';
import '../../../growth/growth_providers.dart';
import '../../../growth/growth_settings.dart';
import '../../../../core/l10n/l10n_ext.dart';
import '../../../../core/l10n/enum_l10n.dart';

/// Height of everything under the square image on a grid card, before
/// text scaling. Parents size grid rows as `tileWidth + this * textScale`.
const double catalogCardInfoHeight = 118;

/// Product tile in the style of the big Kenyan marketplaces: square photo
/// with deal/new badges and a wishlist heart, then name, rating, price and
/// minimum order. On desktop, hovering lifts the card and reveals a quick
/// "Add to cart" bar over the photo.
class CatalogItemCard extends StatefulWidget {
  const CatalogItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAddToCart,
    this.heroTag,
  });

  final CatalogItem item;
  final VoidCallback onTap;
  final Future<void> Function() onAddToCart;

  /// Only the main grid passes one: the same item can also appear in a
  /// home section, and two heroes with one tag on a page is an error.
  final String? heroTag;

  @override
  State<CatalogItemCard> createState() => _CatalogItemCardState();
}

class _CatalogItemCardState extends State<CatalogItemCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final l10n = AppLocalizations.of(context);
    final canHover =
        Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    Widget image = CatalogImage(
      imageUrls: item.imageUrls,
      placeholderIcon: item.category.icon,
      borderRadius: BorderRadius.zero,
      semanticLabel: item.name,
    );
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovering
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.12 : 0.04),
              blurRadius: _hovering ? 18 : 6,
              offset: Offset(0, _hovering ? 8 : 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 44,
                        child: _Badges(item: item),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: WishlistHeart(
                          itemId: item.id,
                          itemName: item.name,
                        ),
                      ),
                      if (item.isCustomizable)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Pill(
                              icon: Icons.brush_rounded,
                              label: l10n.badgeCustomisable,
                              background: Colors.black.withValues(alpha: 0.62),
                              foreground: Colors.white,
                            ),
                          ),
                        ),
                      if (canHover)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedSlide(
                            offset: _hovering
                                ? Offset.zero
                                : const Offset(0, 1),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: AnimatedOpacity(
                              opacity: _hovering ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: _QuickAddBar(
                                onAdd: widget.onAddToCart,
                                customise: item.isCustomizable,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    child: _CardInfo(item: item, onAdd: widget.onAddToCart),
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

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.item, required this.onAdd});

  final CatalogItem item;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasTiers = item.fromPrice < item.basePrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        if (item.ratingCount > 0)
          RatingLine(avg: item.ratingAvg, count: item.ratingCount)
        else
          Text(
            item.category.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (hasTiers)
                            TextSpan(
                              text: '${l10n.fromPrice('').trim()} ',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          TextSpan(
                            text: currencyFormat.format(item.fromPrice),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    l10n.minOrderShort(item.moq, item.leadTimeDays),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            AddToCartIconButton(onAdd: onAdd, customise: item.isCustomizable),
          ],
        ),
      ],
    );
  }
}

/// Compact list row (list view on the results page).
class CatalogItemListTile extends StatelessWidget {
  const CatalogItemListTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAddToCart,
  });

  final CatalogItem item;
  final VoidCallback onTap;
  final Future<void> Function() onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CatalogImage(
                      imageUrls: item.imageUrls,
                      placeholderIcon: item.category.icon,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      right: 4,
                      child: _Badges(item: item),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    if (item.ratingCount > 0)
                      RatingLine(avg: item.ratingAvg, count: item.ratingCount),
                    const SizedBox(height: 4),
                    Text(
                      item.fromPrice < item.basePrice
                          ? l10n.fromPrice(
                              currencyFormat.format(item.fromPrice),
                            )
                          : currencyFormat.format(item.fromPrice),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    ApproxPrice(kes: item.fromPrice),
                    Text(
                      '${item.category.tr(context)} · ${l10n.minOrderShort(item.moq, item.leadTimeDays)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.isCustomizable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _Pill(
                          icon: Icons.brush_rounded,
                          label: l10n.badgeCustomisable,
                          background: scheme.secondaryContainer,
                          foreground: scheme.onSecondaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
              WishlistHeart(
                itemId: item.id,
                itemName: item.name,
                filled: false,
              ),
              AddToCartIconButton(
                onAdd: onAddToCart,
                customise: item.isCustomizable,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "★ 4.6 (23)".
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.avg, required this.count});

  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.starsFromReviews(avg.toStringAsFixed(1), count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                avg >= i
                    ? Icons.star_rounded
                    : avg >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
                size: 13,
                color: const Color(0xFFF5A623),
              ),
            const SizedBox(width: 3),
            Text(
              '($count)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = item.bulkSavingPercent;
    final isNew = item.isNewAt(DateTime.now());
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (saving >= 5)
          Tooltip(
            message: l10n.saveUpTo(saving),
            child: _Pill(
              label: '-$saving%',
              background: const Color(0xFFFFE8D6),
              foreground: const Color(0xFFB54708),
            ),
          ),
        if (item.isFeatured)
          _Pill(
            label: l10n.badgeFeatured,
            background: Theme.of(context).colorScheme.primary,
            foreground: Theme.of(context).colorScheme.onPrimary,
          )
        else if (isNew)
          _Pill(
            label: l10n.badgeNew,
            background: const Color(0xFF12B76A),
            foreground: Colors.white,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heart over the product photo. Guests are asked to sign in.
class WishlistHeart extends ConsumerWidget {
  const WishlistHeart({
    super.key,
    required this.itemId,
    required this.itemName,
    this.filled = true,
  });

  final String itemId;
  final String itemName;

  /// Draw on a white circle (over photos).
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(wishlistProvider).valueOrNull?.contains(itemId) ?? false;
    final icon = Icon(
      saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: 19,
      color: saved ? const Color(0xFFE11D48) : Colors.black87,
    );
    return IconButton(
      tooltip: saved
          ? context.l10n.removeFromWishlist
          : context.l10n.saveToWishlist,
      visualDensity: VisualDensity.compact,
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
            )
          : null,
      onPressed: () {
        if (ref.read(currentUidProvider) == null) {
          showAuthRequiredSheet(
            context,
            message: context.l10n.signInToSaveToYour(itemName),
          );
          return;
        }
        toggleWishlist(ref, itemId, !saved);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: KeyedSubtree(key: ValueKey(saved), child: icon),
      ),
    );
  }
}

/// Round cart button that flashes a tick after adding. Customisable items
/// show a brush: they open the designer instead.
class AddToCartIconButton extends StatefulWidget {
  const AddToCartIconButton({
    super.key,
    required this.onAdd,
    this.customise = false,
  });

  final Future<void> Function() onAdd;
  final bool customise;

  @override
  State<AddToCartIconButton> createState() => _AddToCartIconButtonState();
}

class _AddToCartIconButtonState extends State<AddToCartIconButton> {
  bool _done = false;
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAdd();
      if (!mounted || widget.customise) return;
      setState(() => _done = true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) setState(() => _done = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: widget.customise
          ? AppLocalizations.of(context).badgeCustomisable
          : AppLocalizations.of(context).addToCart,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: _done ? const Color(0xFF12B76A) : scheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(6),
      ),
      onPressed: _tap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: Icon(
          _done
              ? Icons.check_rounded
              : widget.customise
              ? Icons.brush_rounded
              : Icons.add_shopping_cart_rounded,
          key: ValueKey('$_done${widget.customise}'),
          size: 18,
        ),
      ),
    );
  }
}

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({required this.onAdd, required this.customise});

  final Future<void> Function() onAdd;
  final bool customise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.94),
      child: InkWell(
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                customise
                    ? Icons.brush_rounded
                    : Icons.add_shopping_cart_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                customise
                    ? AppLocalizations.of(context).badgeCustomisable
                    : AppLocalizations.of(context).addToCart,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
