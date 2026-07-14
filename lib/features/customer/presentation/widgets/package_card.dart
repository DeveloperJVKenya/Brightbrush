import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/catalog_image.dart';
import '../../../catalog/domain/package_model.dart';

class PackageCard extends StatelessWidget {
  const PackageCard({super.key, required this.package, required this.onTap});

  final PackageModel package;
  final VoidCallback onTap;

  static final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CatalogImage(
                    imageUrls: package.imageUrl == null ? const [] : [package.imageUrl!],
                    placeholderIcon: Icons.card_giftcard_rounded,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(top: 10, left: 10, child: BrandBadge(label: package.season)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currency.format(package.price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
