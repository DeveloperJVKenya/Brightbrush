import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetCategory {
  machine('Machine'),
  vehicle('Vehicle'),
  equipment('Equipment'),
  other('Other');

  const AssetCategory(this.label);
  final String label;

  static AssetCategory fromName(String name) {
    return AssetCategory.values.firstWhere((c) => c.name == name, orElse: () => AssetCategory.other);
  }
}

enum AssetCondition {
  operational('Operational'),
  needsRepair('Needs repair'),
  retired('Retired');

  const AssetCondition(this.label);
  final String label;

  static AssetCondition fromName(String name) {
    return AssetCondition.values.firstWhere((c) => c.name == name, orElse: () => AssetCondition.operational);
  }
}

class CompanyAsset {
  const CompanyAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.condition,
    required this.purchaseDate,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AssetCategory category;
  final AssetCondition condition;
  final DateTime? purchaseDate;
  final String notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get searchFields => [name, category.label, condition.label];

  factory CompanyAsset.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CompanyAsset(
      id: doc.id,
      name: d['name'] as String? ?? '',
      category: AssetCategory.fromName(d['category'] as String? ?? 'other'),
      condition: AssetCondition.fromName(d['condition'] as String? ?? 'operational'),
      purchaseDate: (d['purchaseDate'] as Timestamp?)?.toDate(),
      notes: d['notes'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String uid}) {
    return {
      'name': name,
      'category': category.name,
      'condition': condition.name,
      if (purchaseDate != null) 'purchaseDate': Timestamp.fromDate(purchaseDate!),
      if (notes.isNotEmpty) 'notes': notes,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'name': name,
      'category': category.name,
      'condition': condition.name,
      if (purchaseDate != null) 'purchaseDate': Timestamp.fromDate(purchaseDate!),
      if (notes.isNotEmpty) 'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
