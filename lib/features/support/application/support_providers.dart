import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/support_tickets_repository.dart';
import '../domain/support_ticket.dart';

final supportTicketsRepositoryProvider = Provider<SupportTicketsRepository>((ref) {
  return SupportTicketsRepository(ref.watch(firestoreProvider));
});

/// The signed-in customer's own ticket history.
final myTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(supportTicketsRepositoryProvider).streamForCustomer(uid);
});

/// Every ticket — the Admin/Developer Support Inbox.
final allTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(supportTicketsRepositoryProvider).streamAll();
});
