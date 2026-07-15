import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatting/currency.dart';

import '../../../shared/widgets/catalog_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/package_model.dart';
import 'widgets/package_form_sheet.dart';

class ManagerPackagesScreen extends ConsumerWidget {
  const ManagerPackagesScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final packagesAsync = ref.watch(allPackagesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPackageFormSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add package'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Packages', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Seasonal & campaign bundles, including drafts not yet visible to customers.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: packagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load packages', message: '$error'),
                  data: (packages) {
                    if (packages.isEmpty) {
                      return const EmptyState(
                        icon: Icons.card_giftcard_outlined,
                        title: 'No packages yet',
                        message: 'Tap "Add package" to create your first seasonal bundle.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: packages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _PackageRow(package: packages[index]),
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

class _PackageRow extends ConsumerWidget {
  const _PackageRow({required this.package});

  final PackageModel package;

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
                imageUrls: package.imageUrl == null ? const [] : [package.imageUrl!],
                placeholderIcon: Icons.card_giftcard_rounded,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(package.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${package.season} · ${currencyFormat.format(package.price)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: package.isActive,
              onChanged: (value) {
                ref.read(packagesRepositoryProvider).update(
                      PackageModel(
                        id: package.id,
                        name: package.name,
                        description: package.description,
                        season: package.season,
                        price: package.price,
                        imageUrl: package.imageUrl,
                        itemIds: package.itemIds,
                        isActive: value,
                        validFrom: package.validFrom,
                        validTo: package.validTo,
                        createdBy: package.createdBy,
                        createdAt: package.createdAt,
                        updatedAt: DateTime.now(),
                      ),
                    );
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete package?'),
                    content: Text('"${package.name}" will be removed permanently.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(packagesRepositoryProvider).delete(package.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
