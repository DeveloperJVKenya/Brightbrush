import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/widgets/auth_required_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/live_search_field.dart';
import '../../../shared/widgets/staggered_entrance.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/package_model.dart';
import '../../quotes/presentation/request_quote_sheet.dart';
import '../application/cart_providers.dart';
import 'widgets/package_card.dart';
import '../../../core/l10n/l10n_ext.dart';

void _showPackageSheet(BuildContext context, PackageModel package) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              package.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(package.season),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 12),
            Text(
              package.description.isEmpty
                  ? context.l10n.noDescriptionProvidedYet
                  : package.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              package.itemIds.isEmpty
                  ? context.l10n.thisPackageDoesntListSpecificCatalog
                  : context.l10n.includesCatalogItemS(package.itemIds.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              currencyFormat.format(package.price),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Consumer(
                builder: (_, ref, _) => FilledButton.icon(
                  onPressed: () async {
                    // The sheet is popped before the snackbar shows, so the
                    // follow-ups use the screen's context, not the sheet's.
                    final messenger = ScaffoldMessenger.of(context);
                    final l10n = context.l10n;
                    final navigator = Navigator.of(sheetContext);
                    if (ref.read(currentUidProvider) == null) {
                      navigator.pop();
                      showAuthRequiredSheet(
                        context,
                        message: context.l10n.signInOrCreateAnAccount2(
                          package.name,
                        ),
                      );
                      return;
                    }
                    try {
                      await ref.read(cartActionsProvider).addPackage(package);
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.addedToCart2(package.name)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(friendlyError(error)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(context.l10n.addToCart),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  showRequestQuoteSheet(
                    context,
                    title: package.name,
                    packageId: package.id,
                  );
                },
                icon: const Icon(Icons.request_quote_outlined),
                label: Text(context.l10n.customiseItRequestAQuote),
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
            Text(
              context.l10n.seasonalPackages,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.curatedBundlesForCampaignsAndSeasons,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LiveSearchField(
              hintText: context.l10n.searchPackagesEGValentines,
              onChanged: (value) =>
                  ref.read(packagesSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: context.l10n.loading,
                  ),
                ),
                error: (error, stack) {
                  appLogger.e(
                    '[packages] Failed to load packages',
                    error: error,
                    stackTrace: stack,
                  );
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: context.l10n.couldntLoadPackages,
                    message: friendlyError(error),
                    action: TextButton.icon(
                      onPressed: () => ref.invalidate(filteredPackagesProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.retry),
                    ),
                  );
                },
                data: (packages) {
                  if (packages.isEmpty) {
                    return EmptyState(
                      icon: Icons.card_giftcard_outlined,
                      title: ref.read(packagesSearchQueryProvider).isEmpty
                          ? context.l10n.noPackagesYet
                          : context.l10n.noMatches,
                      message: ref.read(packagesSearchQueryProvider).isEmpty
                          ? context.l10n.seasonalPackagesSetUpByThe
                          : context.l10n.tryADifferentSearchTerm,
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
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
