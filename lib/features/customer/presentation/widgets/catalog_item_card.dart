import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/catalog_image.dart';
import '../../../catalog/domain/catalog_item.dart';

class CatalogItemCard extends StatefulWidget {
  const CatalogItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAddToCart,
  });

  final CatalogItem item;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  @override
  State<CatalogItemCard> createState() => _CatalogItemCardState();
}

class _CatalogItemCardState extends State<CatalogItemCard> {
  bool _hovering = false;
  bool _justAdded = false;

  static final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Hero(
                    tag: 'catalog-item-${item.id}',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CatalogImage(
                          imageUrls: item.imageUrls,
                          placeholderIcon: item.category.icon,
                          borderRadius: BorderRadius.zero,
                        ),
                        if (item.isFeatured)
                          const Positioned(top: 10, left: 10, child: BrandBadge(label: 'Featured')),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category.label,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currency.format(item.basePrice),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: IconButton(
                              key: ValueKey(_justAdded),
                              tooltip: 'Add to cart',
                              onPressed: () {
                                widget.onAddToCart();
                                setState(() => _justAdded = true);
                                Future.delayed(const Duration(milliseconds: 900), () {
                                  if (mounted) setState(() => _justAdded = false);
                                });
                              },
                              icon: Icon(
                                _justAdded ? Icons.check_circle_rounded : Icons.add_shopping_cart_rounded,
                                color: _justAdded ? Colors.green : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'MOQ ${item.moq} · ${item.leadTimeDays}d lead time',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
