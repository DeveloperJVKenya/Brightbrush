import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/quotes_repository.dart';
import '../domain/quote_request.dart';

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

final myQuotesProvider = StreamProvider<List<QuoteRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(quotesRepositoryProvider).streamForCustomer(uid);
});

/// Manager/Admin quote inbox. Watches auth so the listener is rebuilt on
/// account switches (same reasoning as allOrdersProvider).
final allQuotesProvider = StreamProvider<List<QuoteRequest>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(quotesRepositoryProvider).streamAll();
});
