import 'package:cloud_firestore/cloud_firestore.dart';

class PackageModel {
  const PackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.season,
    required this.price,
    required this.imageUrl,
    required this.itemIds,
    required this.isActive,
    required this.validFrom,
    required this.validTo,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String season;
  final num price;
  final String? imageUrl;
  final List<String> itemIds;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get searchFields => [name, season, description];

  factory PackageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PackageModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      season: d['season'] as String? ?? '',
      price: d['price'] as num? ?? 0,
      imageUrl: d['imageUrl'] as String?,
      itemIds: (d['itemIds'] as List?)?.cast<String>() ?? const [],
      isActive: d['isActive'] as bool? ?? false,
      validFrom: (d['validFrom'] as Timestamp?)?.toDate(),
      validTo: (d['validTo'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String uid}) {
    return {
      'name': name,
      'description': description,
      'season': season,
      'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (itemIds.isNotEmpty) 'itemIds': itemIds,
      'isActive': isActive,
      if (validFrom != null) 'validFrom': Timestamp.fromDate(validFrom!),
      if (validTo != null) 'validTo': Timestamp.fromDate(validTo!),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'name': name,
      'description': description,
      'season': season,
      'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (itemIds.isNotEmpty) 'itemIds': itemIds,
      'isActive': isActive,
      if (validFrom != null) 'validFrom': Timestamp.fromDate(validFrom!),
      if (validTo != null) 'validTo': Timestamp.fromDate(validTo!),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
