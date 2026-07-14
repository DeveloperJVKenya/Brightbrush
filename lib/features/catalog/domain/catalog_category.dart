import 'package:flutter/material.dart';

/// Branding forms BrightBrush Creations offers. Kept as a closed enum (not
/// free text) so the catalog, filters, and Firestore validation all agree
/// on the same set of values — matches `isValidCategory` in firestore.rules.
enum CatalogCategory {
  caps(label: 'Caps', icon: Icons.sports_baseball_outlined),
  tshirts(label: 'T-Shirts', icon: Icons.checkroom_outlined),
  hoodies(label: 'Hoodies', icon: Icons.dry_cleaning_outlined),
  twoPiece(label: 'Two-Piece Sets', icon: Icons.checkroom),
  waterBottles(label: 'Water Bottles', icon: Icons.local_drink_outlined),
  cutlery(label: 'Cutlery', icon: Icons.restaurant_outlined),
  embroidery(label: 'Embroidery', icon: Icons.auto_awesome_outlined),
  other(label: 'Other', icon: Icons.category_outlined);

  const CatalogCategory({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static CatalogCategory fromName(String name) {
    return CatalogCategory.values.firstWhere((c) => c.name == name, orElse: () => CatalogCategory.other);
  }
}
