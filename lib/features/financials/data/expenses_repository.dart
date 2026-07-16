import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/expense_model.dart';

class ExpensesRepository {
  ExpensesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _expenses => _db.collection('Expenses');

  Stream<List<ExpenseModel>> streamAll() {
    appLogger.d('[expenses] streamAll()');
    return _expenses
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ExpenseModel.fromFirestore).toList())
        .transform(logStreamErrors('[expenses] streamAll() failed — likely signed in as a role without isAdminOrDeveloper()'));
  }

  Future<String> create(ExpenseModel expense, {required String uid}) async {
    appLogger.i('[expenses] create() category=${expense.category.name} amount=${expense.amount} createdBy=$uid');
    try {
      final doc = await _expenses.add(expense.toFirestoreCreate(uid: uid));
      appLogger.i('[expenses] created ${doc.id}');
      return doc.id;
    } catch (error, stack) {
      appLogger.e('[expenses] create() failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> update(ExpenseModel expense) async {
    appLogger.i('[expenses] update(${expense.id})');
    try {
      await _expenses.doc(expense.id).update(expense.toFirestoreUpdate());
    } catch (error, stack) {
      appLogger.e('[expenses] update(${expense.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    appLogger.i('[expenses] delete($id)');
    try {
      await _expenses.doc(id).delete();
    } catch (error, stack) {
      appLogger.e('[expenses] delete($id) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
