import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatting/currency.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/catalog_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../application/cart_providers.dart';

class CatalogItemDetailScreen extends ConsumerWidget {
  const CatalogItemDetailScreen({super.key, required this.itemId});

  final String itemId;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeCatalogItemsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Item details'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          appLogger.e('[catalog] Failed to load catalog item detail', error: error, stackTrace: stack);
          return EmptyState(icon: Icons.cloud_off_rounded, title: 'Failed to load', message: friendlyError(error));
        },
        data: (items) {
          final matches = items.where((i) => i.id == itemId);
          final item = matches.isEmpty ? null : matches.first;
          if (item == null) {
            return const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Item not found',
              message: 'It may have been removed or is no longer active.',
            );
          }
          return _DetailBody(item: item);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final image = Hero(
      tag: 'catalog-item-${item.id}',
      child: AspectRatio(
        aspectRatio: 1,
        child: CatalogImage(imageUrls: item.imageUrls, placeholderIcon: item.category.icon),
      ),
    );

    final info = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text(item.category.label)),
              if (item.isFeatured) ...[const SizedBox(width: 8), const BrandBadge(label: 'Featured')],
            ],
          ),
          const SizedBox(height: 12),
          Text(item.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(item.basePrice),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.numbers_rounded, label: 'MOQ ${item.moq}'),
              _MetaChip(icon: Icons.schedule_rounded, label: '${item.leadTimeDays} day lead time'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            item.description.isEmpty ? 'No description provided yet.' : item.description,
            style: theme.textTheme.bodyMedium,
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tag in item.tags) Chip(label: Text(tag), visualDensity: VisualDensity.compact)],
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(cartProvider.notifier).add(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.name} added to cart'), behavior: SnackBarBehavior.floating),
                );
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Add to cart'),
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: image),
          Expanded(child: SingleChildScrollView(child: info)),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(children: [image, info]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ],
    );
  }
}
