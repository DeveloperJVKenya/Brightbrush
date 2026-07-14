import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalog_category.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
    required this.moq,
    required this.leadTimeDays,
    required this.imageUrls,
    required this.tags,
    required this.isActive,
    required this.isFeatured,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final CatalogCategory category;
  final String description;
  final num basePrice;
  final int moq;
  final int leadTimeDays;
  final List<String> imageUrls;
  final List<String> tags;
  final bool isActive;
  final bool isFeatured;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Fields checked by search — spans name, category label, description and
  /// tags, so a query matches whether it's a product name, a material, or a
  /// style keyword tucked into the description.
  List<String> get searchFields => [name, category.label, description, ...tags];

  factory CatalogItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CatalogItem(
      id: doc.id,
      name: d['name'] as String? ?? '',
      category: CatalogCategory.fromName(d['category'] as String? ?? 'other'),
      description: d['description'] as String? ?? '',
      basePrice: d['basePrice'] as num? ?? 0,
      moq: (d['moq'] as num?)?.toInt() ?? 1,
      leadTimeDays: (d['leadTimeDays'] as num?)?.toInt() ?? 0,
      imageUrls: (d['imageUrls'] as List?)?.cast<String>() ?? const [],
      tags: (d['tags'] as List?)?.cast<String>() ?? const [],
      isActive: d['isActive'] as bool? ?? false,
      isFeatured: d['isFeatured'] as bool? ?? false,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String uid}) {
    return {
      'name': name,
      'category': category.name,
      'description': description,
      'basePrice': basePrice,
      'moq': moq,
      'leadTimeDays': leadTimeDays,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (tags.isNotEmpty) 'tags': tags,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'name': name,
      'category': category.name,
      'description': description,
      'basePrice': basePrice,
      'moq': moq,
      'leadTimeDays': leadTimeDays,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (tags.isNotEmpty) 'tags': tags,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
