import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus {
  open('Open'),
  inProgress('In progress'),
  resolved('Resolved');

  const TicketStatus(this.label);
  final String label;

  static TicketStatus fromName(String name) {
    return TicketStatus.values.firstWhere((s) => s.name == name, orElse: () => TicketStatus.open);
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.response,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String subject;
  final String message;
  final String customerId;
  final String customerName;
  final TicketStatus status;
  final String? response;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportTicket.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SupportTicket(
      id: doc.id,
      subject: d['subject'] as String? ?? '',
      message: d['message'] as String? ?? '',
      customerId: d['customerId'] as String? ?? '',
      customerName: d['customerName'] as String? ?? '',
      status: TicketStatus.fromName(d['status'] as String? ?? 'open'),
      response: d['response'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required String customerId, required String customerName}) {
    return {
      'subject': subject,
      'message': message,
      'customerId': customerId,
      'customerName': customerName,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Staff-only triage update: status + an optional response, never the
  /// original subject/message/customer fields (immutable — enforced in
  /// firestore.rules too).
  Map<String, dynamic> toFirestoreTriageUpdate() {
    return {
      'subject': subject,
      'message': message,
      'customerId': customerId,
      'customerName': customerName,
      'status': status.name,
      if (response != null && response!.isNotEmpty) 'response': response,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
