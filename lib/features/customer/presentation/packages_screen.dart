import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/staggered_entrance.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/package_model.dart';
import 'widgets/package_card.dart';

void _showPackageSheet(BuildContext context, PackageModel package) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(package.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Chip(label: Text(package.season), visualDensity: VisualDensity.compact),
            const SizedBox(height: 12),
            Text(
              package.description.isEmpty ? 'No description provided yet.' : package.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              package.itemIds.isEmpty
                  ? 'This package doesn\'t list specific catalog items yet.'
                  : 'Includes ${package.itemIds.length} catalog item(s).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Quote request sent for "${package.name}"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Request a quote'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PackagesScreen extends ConsumerWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filtered = ref.watch(filteredPackagesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seasonal packages', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Curated bundles for campaigns and seasons — Valentine\'s, elections, and more.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: 'Search packages, e.g. "valentines"',
              onChanged: (value) => ref.read(packagesSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  appLogger.e('[packages] Failed to load packages', error: error, stackTrace: stack);
                  return EmptyState(
                      icon: Icons.cloud_off_rounded, title: 'Couldn\'t load packages', message: friendlyError(error));
                },
                data: (packages) {
                  if (packages.isEmpty) {
                    return EmptyState(
                      icon: Icons.card_giftcard_outlined,
                      title: ref.read(packagesSearchQueryProvider).isEmpty ? 'No packages yet' : 'No matches',
                      message: ref.read(packagesSearchQueryProvider).isEmpty
                          ? 'Seasonal packages set up by the System Manager will appear here live.'
                          : 'Try a different search term.',
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final package = packages[index];
                      return StaggeredEntrance(
                        index: index,
                        child: PackageCard(
                          package: package,
                          onTap: () => _showPackageSheet(context, package),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
