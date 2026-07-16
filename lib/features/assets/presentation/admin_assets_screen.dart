import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../application/assets_providers.dart';
import '../domain/company_asset.dart';
import 'widgets/asset_form_sheet.dart';

class AdminAssetsScreen extends ConsumerWidget {
  const AdminAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filtered = ref.watch(filteredAssetsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAssetFormSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add asset'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Company assets', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'In-house machines and equipment used across the branding process.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LiveSearchField(
                hintText: 'Search by name, category, or condition',
                onChanged: (v) => ref.read(assetsSearchQueryProvider.notifier).state = v,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load assets', message: '$error'),
                  data: (assets) {
                    if (assets.isEmpty) {
                      return const EmptyState(
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'No assets recorded yet',
                        message: 'Add machines, equipment and vehicles to track their condition.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: assets.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _AssetRow(asset: assets[index]),
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

class _AssetRow extends ConsumerWidget {
  const _AssetRow({required this.asset});

  final CompanyAsset asset;

  static final _date = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conditionColor = switch (asset.condition) {
      AssetCondition.operational => theme.colorScheme.primary,
      AssetCondition.needsRepair => Colors.orange,
      AssetCondition.retired => theme.colorScheme.error,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          asset.category.label,
          if (asset.purchaseDate != null) 'Purchased ${_date.format(asset.purchaseDate!)}',
        ].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: conditionColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(asset.condition.label, style: TextStyle(color: conditionColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showAssetFormSheet(context, ref, existing: asset),
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
        title: const Text('Delete asset?'),
        content: Text('This removes "${asset.name}" from the asset list.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(assetsRepositoryProvider).delete(asset.id);
    }
  }
}
