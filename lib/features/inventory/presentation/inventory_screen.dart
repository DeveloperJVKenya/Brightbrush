import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/stat_card.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_material.dart';
import 'widgets/inventory_material_form_sheet.dart';

/// Shared between `/manager/inventory` and `/admin/inventory` — System
/// Manager and Admin/Developer have identical `isManagerOrAdmin()` access to
/// `InventoryMaterials`, so one screen serves both nav entries.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filtered = ref.watch(filteredInventoryMaterialsProvider);
    final lowStockOnly = ref.watch(lowStockOnlyProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInventoryMaterialFormSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add material'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Materials, stock levels and reorder points.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LiveSearchField(
                hintText: 'Search by name, category, or supplier',
                onChanged: (v) => ref.read(inventorySearchQueryProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),
              FilterChip(
                label: const Text('Low stock only'),
                selected: lowStockOnly,
                avatar: lowStockOnly ? null : const Icon(Icons.warning_amber_rounded, size: 18),
                onSelected: (v) => ref.read(lowStockOnlyProvider.notifier).state = v,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) {
                    appLogger.e('[inventory] Failed to load inventory', error: error, stackTrace: stack);
                    return EmptyState(
                        icon: Icons.cloud_off_rounded, title: 'Couldn\'t load inventory', message: friendlyError(error));
                  },
                  data: (materials) {
                    if (materials.isEmpty) {
                      return EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: lowStockOnly ? 'Nothing low on stock' : 'No materials yet',
                        message: lowStockOnly
                            ? 'Everything is above its reorder point.'
                            : 'Add paint, blanks, thread and other materials to track stock.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: materials.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _MaterialRow(material: materials[index]),
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

class _MaterialRow extends ConsumerWidget {
  const _MaterialRow({required this.material});

  final InventoryMaterial material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(material.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            material.category,
            if (material.supplierName.isNotEmpty) material.supplierName,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatCard(
              label: 'On hand',
              value: '${material.quantityOnHand} ${material.unit}',
              icon: material.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
              accent: material.isLowStock,
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showInventoryMaterialFormSheet(context, ref, existing: material),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete material?'),
        content: Text('This removes "${material.name}" from inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(inventoryRepositoryProvider).delete(material.id);
    }
  }
}
