import 'package:cloud_firestore/cloud_firestore.dart';

class GuideArticle {
  const GuideArticle({
    required this.id,
    required this.question,
    required this.answer,
    required this.roles,
    required this.section,
    required this.keywords,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String question;
  final String answer;

  /// AppRole names this article applies to (e.g. ['systemManager', 'admin']).
  final List<String> roles;

  /// The route path this is most relevant to, e.g. '/manager/staff'.
  final String? section;
  final List<String> keywords;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get searchFields => [question, ...keywords];

  factory GuideArticle.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return GuideArticle(
      id: doc.id,
      question: d['question'] as String? ?? '',
      answer: d['answer'] as String? ?? '',
      roles: (d['roles'] as List?)?.cast<String>() ?? const [],
      section: d['section'] as String?,
      keywords: (d['keywords'] as List?)?.cast<String>() ?? const [],
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String uid}) {
    return {
      'question': question,
      'answer': answer,
      'roles': roles,
      if (section != null && section!.isNotEmpty) 'section': section,
      if (keywords.isNotEmpty) 'keywords': keywords,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Plain-JSON shape (no [Timestamp]) for local on-device caching, so the
  /// role's predefined Q&A still work while offline.
  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'roles': roles,
      'section': section,
      'keywords': keywords,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GuideArticle.fromCacheJson(Map<String, dynamic> json) {
    return GuideArticle(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      roles: (json['roles'] as List?)?.cast<String>() ?? const [],
      section: json['section'] as String?,
      keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'question': question,
      'answer': answer,
      'roles': roles,
      if (section != null && section!.isNotEmpty) 'section': section,
      if (keywords.isNotEmpty) 'keywords': keywords,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
