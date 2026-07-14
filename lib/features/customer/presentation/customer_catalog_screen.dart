import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/staggered_entrance.dart';
import '../../catalog/application/catalog_providers.dart';
import '../application/cart_providers.dart';
import 'widgets/ai_search_dialog.dart';
import 'widgets/catalog_item_card.dart';
import 'widgets/category_filter_bar.dart';

class CustomerCatalogScreen extends ConsumerWidget {
  const CustomerCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredCatalogItemsProvider);
    final category = ref.watch(catalogCategoryFilterProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: cartCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/customer/cart'),
              icon: const Icon(Icons.shopping_cart_rounded),
              label: Text('Cart · $cartCount'),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(offset: Offset(0, (1 - value) * 8), child: child),
                  );
                },
                child: Text(
                  'Browse the catalog',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Caps, tees, hoodies, embroidery and every other branding form we offer.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LiveSearchField(
                      hintText: 'Search items, e.g. "hoodie" or "cotton"',
                      onChanged: (value) => ref.read(catalogSearchQueryProvider.notifier).state = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Ask AI what you need',
                    child: FilledButton.tonalIcon(
                      onPressed: () => showDialog(context: context, builder: (_) => const AiSearchDialog()),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Ask AI'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CategoryFilterBar(
                selected: category,
                onSelected: (value) => ref.read(catalogCategoryFilterProvider.notifier).state = value,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.when(
                  loading: () => const _CatalogGridSkeleton(),
                  error: (error, stack) => EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Couldn\'t load the catalog',
                    message: '$error',
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: ref.read(catalogSearchQueryProvider).isEmpty && category == null
                            ? 'No items in the catalog yet'
                            : 'No matches',
                        message: ref.read(catalogSearchQueryProvider).isEmpty && category == null
                            ? 'Once the System Manager adds branding items, they\'ll show up here live.'
                            : 'Try a different search term or clear the category filter.',
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.66,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return StaggeredEntrance(
                              index: index,
                              child: CatalogItemCard(
                                item: item,
                                onTap: () => context.push('/customer/catalog/${item.id}'),
                                onAddToCart: () {
                                  ref.read(cartProvider.notifier).add(item.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${item.name} added to cart'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogGridSkeleton extends StatelessWidget {
  const _CatalogGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.66,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _Shimmer(color: scheme.surfaceContainerHigh);
      },
    );
  }
}

/// Simple shimmer without a package dependency: an opacity pulse over a
/// rounded placeholder card, shown while Firestore streams their first
/// snapshot.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.color});

  final Color color;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + _controller.value * 0.3,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
