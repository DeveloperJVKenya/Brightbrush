import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryMaterial {
  const InventoryMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantityOnHand,
    required this.reorderPoint,
    required this.supplierName,
    required this.supplierContact,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final int quantityOnHand;
  final int reorderPoint;
  final String supplierName;
  final String supplierContact;
  final String notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => quantityOnHand <= reorderPoint;

  List<String> get searchFields => [name, category, supplierName];

  factory InventoryMaterial.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return InventoryMaterial(
      id: doc.id,
      name: d['name'] as String? ?? '',
      category: d['category'] as String? ?? '',
      unit: d['unit'] as String? ?? '',
      quantityOnHand: (d['quantityOnHand'] as num?)?.toInt() ?? 0,
      reorderPoint: (d['reorderPoint'] as num?)?.toInt() ?? 0,
      supplierName: d['supplierName'] as String? ?? '',
      supplierContact: d['supplierContact'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String uid}) {
    return {
      'name': name,
      'category': category,
      'unit': unit,
      'quantityOnHand': quantityOnHand,
      'reorderPoint': reorderPoint,
      if (supplierName.isNotEmpty) 'supplierName': supplierName,
      if (supplierContact.isNotEmpty) 'supplierContact': supplierContact,
      if (notes.isNotEmpty) 'notes': notes,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'name': name,
      'category': category,
      'unit': unit,
      'quantityOnHand': quantityOnHand,
      'reorderPoint': reorderPoint,
      if (supplierName.isNotEmpty) 'supplierName': supplierName,
      if (supplierContact.isNotEmpty) 'supplierContact': supplierContact,
      if (notes.isNotEmpty) 'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
