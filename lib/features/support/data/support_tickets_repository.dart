import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/support_ticket.dart';

class SupportTicketsRepository {
  SupportTicketsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _tickets => _db.collection('SupportTickets');

  /// The signed-in customer's own tickets, newest first.
  Stream<List<SupportTicket>> streamForCustomer(String customerId) {
    appLogger.d('[support] streamForCustomer($customerId)');
    return _tickets
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SupportTicket.fromFirestore).toList())
        .transform(logStreamErrors('[support] streamForCustomer() failed'));
  }

  /// Every ticket — the Admin/Developer Support Inbox.
  Stream<List<SupportTicket>> streamAll() {
    appLogger.d('[support] streamAll()');
    return _tickets
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SupportTicket.fromFirestore).toList())
        .transform(logStreamErrors('[support] streamAll() failed — likely signed in as a role without isAdminOrDeveloper()'));
  }

  Future<void> create(SupportTicket ticket, {required String customerId, required String customerName}) async {
    appLogger.i('[support] create() subject="${ticket.subject}" customerId=$customerId');
    try {
      final doc = await _tickets.add(ticket.toFirestoreCreate(customerId: customerId, customerName: customerName));
      appLogger.i('[support] created ${doc.id}');
    } catch (error, stack) {
      appLogger.e('[support] create() failed for subject="${ticket.subject}"', error: error, stackTrace: stack);
      rethrow;
    }
  }

  /// Staff-only triage: change status and/or write a response.
  Future<void> triage(SupportTicket ticket) async {
    appLogger.i('[support] triage(${ticket.id}) status=${ticket.status.name}');
    try {
      await _tickets.doc(ticket.id).update(ticket.toFirestoreTriageUpdate());
    } catch (error, stack) {
      appLogger.e('[support] triage(${ticket.id}) failed', error: error, stackTrace: stack);
      rethrow;
    }
  }
}
