import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/monitoring/monitoring.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/auth_required_sheet.dart';
import '../../../shared/widgets/catalog_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../growth/growth_settings.dart';
import '../../growth/social_widgets.dart';
import '../../quotes/presentation/request_quote_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/whatsapp.dart';
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
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Item details'),
        actions: [
          Builder(
            builder: (context) {
              final name =
                  ref
                      .watch(activeCatalogItemsProvider)
                      .valueOrNull
                      ?.where((i) => i.id == itemId)
                      .firstOrNull
                      ?.name ??
                  '';
              return WhatsAppUsButton(
                compact: true,
                label: AppLocalizations.of(context).whatsappUs,
                message: AppLocalizations.of(context).waItemMessage(name),
              );
            },
          ),
          WishlistButton(itemId: itemId),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        ),
        error: (error, stack) {
          appLogger.e(
            '[catalog] Failed to load catalog item detail',
            error: error,
            stackTrace: stack,
          );
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Failed to load',
            message: friendlyError(error),
            action: TextButton.icon(
              onPressed: () => ref.invalidate(activeCatalogItemsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
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
          return _RecordView(
            item: item,
            child: _DetailBody(item: item),
          );
        },
      ),
    );
  }
}

/// Remembers the item for "Recently viewed" on Home and logs the view.
class _RecordView extends ConsumerStatefulWidget {
  const _RecordView({required this.item, required this.child});

  final CatalogItem item;
  final Widget child;

  @override
  ConsumerState<_RecordView> createState() => _RecordViewState();
}

class _RecordViewState extends ConsumerState<_RecordView> {
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    Future.microtask(() {
      if (!mounted) return;
      ref.read(recentlyViewedProvider.notifier).add(item.id);
      Monitoring.viewItem(id: item.id, name: item.name, price: item.fromPrice);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
        child: CatalogImage(
          imageUrls: item.imageUrls,
          placeholderIcon: item.category.icon,
          semanticLabel: item.name,
        ),
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
              if (item.isFeatured) ...[
                const SizedBox(width: 8),
                const BrandBadge(label: 'Featured'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.fromPrice < item.basePrice
                ? 'From ${currencyFormat.format(item.fromPrice)}'
                : currencyFormat.format(item.basePrice),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          ApproxPrice(kes: item.fromPrice),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.numbers_rounded, label: 'MOQ ${item.moq}'),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: '${item.leadTimeDays} day lead time',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            item.description.isEmpty
                ? 'No description provided yet.'
                : item.description,
            style: theme.textTheme.bodyMedium,
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in item.tags)
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          if (item.priceTiers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Volume pricing: ${item.priceTiers.map((t) => '${t.minQty}+ pcs ${currencyFormat.format(t.unitPrice)}').join(' · ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (item.isCustomizable) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in item.decorationMethods)
                  Chip(
                    avatar: Icon(m.icon, size: 16),
                    label: Text(m.label),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          if (item.isCustomizable)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/customer/catalog/${item.id}/customize'),
                icon: const Icon(Icons.design_services_rounded),
                label: Text(AppLocalizations.of(context).customiseAndOrder),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (ref.read(currentUidProvider) == null) {
                    showAuthRequiredSheet(
                      context,
                      message:
                          'Sign in or create an account to add "${item.name}" to your cart.',
                    );
                    return;
                  }
                  try {
                    final qty = await ref
                        .read(cartActionsProvider)
                        .addCatalogItem(item);
                    Monitoring.addToCart(
                      id: item.id,
                      name: item.name,
                      quantity: qty,
                      value: item.basePrice * qty,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            qty == item.moq && item.moq > 1
                                ? '${item.name} added (minimum order ${item.moq})'
                                : '${item.name} added to cart ($qty)',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (error, stack) {
                    appLogger.e(
                      '[catalog] Failed to add ${item.id} to cart',
                      error: error,
                      stackTrace: stack,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Couldn\'t add to cart: ${friendlyError(error)}',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(AppLocalizations.of(context).addToCart),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showRequestQuoteSheet(
                context,
                title: item.name,
                itemId: item.id,
                initialQuantity: item.moq < 1 ? 1 : item.moq,
              ),
              icon: const Icon(Icons.request_quote_outlined),
              label: Text(AppLocalizations.of(context).requestQuote),
            ),
          ),
          ItemReviewsSection(itemId: item.id),
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
    return SingleChildScrollView(child: Column(children: [image, info]));
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
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }
}
