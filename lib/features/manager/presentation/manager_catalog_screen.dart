import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/search/search_utils.dart';
import '../../../shared/widgets/catalog_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import 'widgets/catalog_item_form_sheet.dart';

final _managerCatalogSearchProvider = StateProvider<String>((ref) => '');

class ManagerCatalogScreen extends ConsumerWidget {
  const ManagerCatalogScreen({super.key});

  static final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(allCatalogItemsProvider);
    final query = ref.watch(_managerCatalogSearchProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCatalogItemFormSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catalog', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Everything customers can browse — including drafts (inactive) not yet visible to them.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LiveSearchField(
                hintText: 'Search your catalog',
                onChanged: (v) => ref.read(_managerCatalogSearchProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load catalog', message: '$error'),
                  data: (items) {
                    final filtered = filterBySearch(items, query, (i) => i.searchFields);
                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: items.isEmpty ? 'No catalog items yet' : 'No matches',
                        message: items.isEmpty
                            ? 'Tap "Add item" to create the first branding item customers will see.'
                            : 'Try a different search term.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ManagerCatalogRow(item: filtered[index]),
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

class _ManagerCatalogRow extends ConsumerWidget {
  const _ManagerCatalogRow({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CatalogImage(
                imageUrls: item.imageUrls,
                placeholderIcon: item.category.icon,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${item.category.label} · ${ManagerCatalogScreen._currency.format(item.basePrice)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: item.isActive,
              onChanged: (value) {
                ref.read(catalogRepositoryProvider).update(
                      CatalogItem(
                        id: item.id,
                        name: item.name,
                        category: item.category,
                        description: item.description,
                        basePrice: item.basePrice,
                        moq: item.moq,
                        leadTimeDays: item.leadTimeDays,
                        imageUrls: item.imageUrls,
                        tags: item.tags,
                        isActive: value,
                        isFeatured: item.isFeatured,
                        createdBy: item.createdBy,
                        createdAt: item.createdAt,
                        updatedAt: DateTime.now(),
                      ),
                    );
              },
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showCatalogItemFormSheet(context, ref, existing: item),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete item?'),
                    content: Text('"${item.name}" will be removed permanently.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(catalogRepositoryProvider).delete(item.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
