import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(firestoreProvider));
});

final allExpensesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(expensesRepositoryProvider).streamAll();
});
