import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.isActive,
    required this.validFrom,
    required this.validTo,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get searchFields => [title, message];

  factory AnnouncementModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AnnouncementModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      message: d['message'] as String? ?? '',
      imageUrl: d['imageUrl'] as String?,
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
      'title': title,
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
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
      'title': title,
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isActive': isActive,
      if (validFrom != null) 'validFrom': Timestamp.fromDate(validFrom!),
      if (validTo != null) 'validTo': Timestamp.fromDate(validTo!),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
