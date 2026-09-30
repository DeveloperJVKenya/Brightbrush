import 'package:cloud_firestore/cloud_firestore.dart';

import '../../customization/domain/customization_options.dart';
import 'catalog_category.dart';

/// One bill-of-materials row: stock material consumed per piece.
class MaterialUse {
  const MaterialUse({required this.materialId, required this.perUnit});

  final String materialId;
  final num perUnit;

  Map<String, dynamic> toMap() => {
    'materialId': materialId,
    'perUnit': perUnit,
  };
}

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
    this.priceTiers = const [],
    this.sizes = const [],
    this.colours = const [],
    this.decorationMethods = const [],
    this.placements = const [],
    this.materials = const [],
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

  /// Volume pricing for the blank: the highest tier reached replaces
  /// [basePrice].
  final List<PriceTier> priceTiers;

  /// Garment sizes (with optional surcharges, e.g. XXL +100). Empty = one
  /// size.
  final List<SizeOption> sizes;
  final List<ColourOption> colours;

  /// Decoration methods and placements offered. An item with at least one
  /// method is customisable: customers configure it before adding to cart.
  final List<DecorationMethod> decorationMethods;
  final List<Placement> placements;

  /// Deducted from stock by the server when an order goes into production.
  final List<MaterialUse> materials;

  bool get isCustomizable =>
      decorationMethods.isNotEmpty && placements.isNotEmpty;

  /// Lowest unit price any tier offers — "from KES x" on catalog cards.
  num get fromPrice => priceTiers.fold<num>(
    basePrice,
    (low, t) => t.unitPrice > 0 && t.unitPrice < low ? t.unitPrice : low,
  );

  CatalogItem copyWith({
    String? id,
    List<String>? imageUrls,
    bool? isActive,
    DateTime? updatedAt,
  }) => CatalogItem(
    id: id ?? this.id,
    name: name,
    category: category,
    description: description,
    basePrice: basePrice,
    moq: moq,
    leadTimeDays: leadTimeDays,
    imageUrls: imageUrls ?? this.imageUrls,
    tags: tags,
    isActive: isActive ?? this.isActive,
    isFeatured: isFeatured,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    priceTiers: priceTiers,
    sizes: sizes,
    colours: colours,
    decorationMethods: decorationMethods,
    placements: placements,
    materials: materials,
  );

  /// Fields checked by search — spans name, category label, description and
  /// tags, so a query matches whether it's a product name, a material, or a
  /// style keyword tucked into the description.
  List<String> get searchFields => [name, category.label, description, ...tags];

  factory CatalogItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      priceTiers: [
        for (final t in (d['priceTiers'] as List? ?? const []))
          PriceTier.fromMap(Map<String, dynamic>.from(t as Map)),
      ]..sort((a, b) => a.minQty.compareTo(b.minQty)),
      sizes: [
        for (final sz in (d['sizes'] as List? ?? const []))
          SizeOption.fromMap(Map<String, dynamic>.from(sz as Map)),
      ],
      colours: [
        for (final c in (d['colours'] as List? ?? const []))
          ColourOption.fromMap(c),
      ],
      decorationMethods: [
        for (final m in (d['decorationMethods'] as List? ?? const []))
          ?DecorationMethod.fromName(m as String?),
      ],
      placements: [
        for (final pl in (d['placements'] as List? ?? const []))
          ?Placement.fromName(pl as String?),
      ],
      materials: [
        for (final m in (d['materials'] as List? ?? const []))
          if (m is Map && m['materialId'] is String)
            MaterialUse(
              materialId: m['materialId'] as String,
              perUnit: m['perUnit'] as num? ?? 0,
            ),
      ],
    );
  }

  Map<String, dynamic> get _customizationFields => {
    'priceTiers': [for (final t in priceTiers) t.toMap()],
    'sizes': [for (final sz in sizes) sz.toMap()],
    'colours': [for (final c in colours) c.toMap()],
    'decorationMethods': [for (final m in decorationMethods) m.name],
    'placements': [for (final pl in placements) pl.name],
    'materials': [for (final m in materials) m.toMap()],
  };

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
      ..._customizationFields,
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
      ..._customizationFields,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
