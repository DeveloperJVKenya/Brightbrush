import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  materials('Materials'),
  utilities('Utilities'),
  wages('Wages'),
  delivery('Delivery'),
  misc('Miscellaneous');

  const ExpenseCategory(this.label);
  final String label;

  static ExpenseCategory fromName(String name) {
    return ExpenseCategory.values.firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.misc);
  }
}

class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ExpenseCategory category;
  final num amount;
  final String note;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ExpenseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ExpenseModel(
      id: doc.id,
      category: ExpenseCategory.fromName(d['category'] as String? ?? 'misc'),
      amount: d['amount'] as num? ?? 0,
      note: d['note'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String uid}) {
    return {
      'category': category.name,
      'amount': amount,
      if (note.isNotEmpty) 'note': note,
      'date': Timestamp.fromDate(date),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'category': category.name,
      'amount': amount,
      if (note.isNotEmpty) 'note': note,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
