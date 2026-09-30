import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();

/// Production stages a job card moves through.
const jobStages = <String, String>{
  'queued': 'Queued',
  'digitizing': 'Digitizing / setup',
  'inProduction': 'On the machine',
  'finishing': 'Finishing & packing',
  'qc': 'Quality check',
  'rework': 'Rework',
  'done': 'Done',
  'cancelled': 'Cancelled',
};

class ProductionJob {
  const ProductionJob({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.itemsSummary,
    required this.stage,
    required this.priority,
    required this.machineId,
    required this.machineName,
    required this.operatorName,
    required this.scheduledDate,
    required this.estimatedMinutes,
    required this.dueDate,
    required this.notes,
  });

  final String orderId;
  final String orderNumber;
  final String customerName;
  final String itemsSummary;
  final String stage;
  final String priority;
  final String? machineId;
  final String machineName;
  final String operatorName;
  final DateTime? scheduledDate;
  final int estimatedMinutes;
  final DateTime? dueDate;
  final String notes;

  bool get isRush => priority == 'rush';
  bool get isOpen => stage != 'done' && stage != 'cancelled';
  bool get isLate =>
      isOpen && dueDate != null && DateTime.now().isAfter(dueDate!);

  factory ProductionJob.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ProductionJob(
      orderId: doc.id,
      orderNumber: d['orderNumber'] as String? ?? doc.id,
      customerName: d['customerName'] as String? ?? '',
      itemsSummary: d['itemsSummary'] as String? ?? '',
      stage: d['stage'] as String? ?? 'queued',
      priority: d['priority'] as String? ?? 'normal',
      machineId: d['machineId'] as String?,
      machineName: d['machineName'] as String? ?? '',
      operatorName: d['operatorName'] as String? ?? '',
      scheduledDate: _date(d['scheduledDate']),
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 0,
      dueDate: _date(d['dueDate']),
      notes: d['notes'] as String? ?? '',
    );
  }
}

class OrderEvent {
  const OrderEvent({
    required this.field,
    required this.from,
    required this.to,
    required this.by,
    required this.at,
  });

  final String field;
  final Object? from;
  final Object? to;
  final String by;
  final DateTime at;

  factory OrderEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return OrderEvent(
      field: d['field'] as String? ?? '',
      from: d['from'],
      to: d['to'],
      by: d['by'] as String? ?? '',
      at: _date(d['at']) ?? DateTime.now(),
    );
  }
}

class InventoryMovement {
  const InventoryMovement({
    required this.materialName,
    required this.change,
    required this.shortfall,
    required this.reason,
    required this.reference,
    required this.at,
  });

  final String materialName;
  final num change;
  final num shortfall;
  final String reason;
  final String reference;
  final DateTime at;

  factory InventoryMovement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return InventoryMovement(
      materialName: d['materialName'] as String? ?? '',
      change: d['change'] as num? ?? 0,
      shortfall: d['shortfall'] as num? ?? 0,
      reason: d['reason'] as String? ?? '',
      reference: (d['orderNumber'] ?? d['poNumber'] ?? '') as String,
      at: _date(d['at']) ?? DateTime.now(),
    );
  }
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.materialId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitCost,
  });

  final String materialId;
  final String name;
  final String unit;
  final int quantity;
  final num unitCost;

  Map<String, dynamic> toMap() => {
    'materialId': materialId,
    'name': name,
    'unit': unit,
    'quantity': quantity,
    'unitCost': unitCost,
  };

  factory PurchaseOrderLine.fromMap(Map<String, dynamic> d) =>
      PurchaseOrderLine(
        materialId: d['materialId'] as String? ?? '',
        name: d['name'] as String? ?? '',
        unit: d['unit'] as String? ?? '',
        quantity: (d['quantity'] as num?)?.toInt() ?? 0,
        unitCost: d['unitCost'] as num? ?? 0,
      );
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierName,
    required this.supplierContact,
    required this.status,
    required this.total,
    required this.lines,
    required this.expectedDate,
    required this.createdAt,
  });

  final String id;
  final String poNumber;
  final String supplierName;
  final String supplierContact;
  final String status;
  final num total;
  final List<PurchaseOrderLine> lines;
  final DateTime? expectedDate;
  final DateTime createdAt;

  factory PurchaseOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return PurchaseOrder(
      id: doc.id,
      poNumber: d['poNumber'] as String? ?? '',
      supplierName: d['supplierName'] as String? ?? '',
      supplierContact: d['supplierContact'] as String? ?? '',
      status: d['status'] as String? ?? 'draft',
      total: d['total'] as num? ?? 0,
      lines: [
        for (final l in (d['lines'] as List? ?? const []))
          PurchaseOrderLine.fromMap(Map<String, dynamic>.from(l as Map)),
      ],
      expectedDate: _date(d['expectedDate']),
      createdAt:
          _date(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.type,
    required this.summary,
    required this.actor,
    required this.at,
    required this.changes,
  });

  final String type;
  final String summary;
  final String actor;
  final DateTime at;
  final Map<String, dynamic> changes;

  factory AuditEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AuditEntry(
      type: d['type'] as String? ?? '',
      summary: d['summary'] as String? ?? '',
      actor: d['actor'] as String? ?? '',
      at: _date(d['at']) ?? DateTime.now(),
      changes: Map<String, dynamic>.from((d['changes'] as Map?) ?? const {}),
    );
  }
}

/// Production, quality, delivery proof, purchasing and audit — the
/// back-of-house operations layer.
class OpsRepository {
  OpsRepository(this._db, this._storage, this._functions);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  HttpsCallable _call(String name) => _functions.httpsCallable(name);

  Stream<List<ProductionJob>> streamJobs() => _db
      .collection('ProductionJobs')
      .snapshots()
      .map((s) => s.docs.map(ProductionJob.fromFirestore).toList())
      .transform(logStreamErrors('[ops] streamJobs failed'));

  Future<void> updateJob(
    String orderId,
    Map<String, dynamic> changes, {
    required String uid,
  }) {
    appLogger.i('[ops] updateJob($orderId, ${changes.keys.join(',')})');
    return _db.collection('ProductionJobs').doc(orderId).update({
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  Stream<List<OrderEvent>> streamEvents(String orderId) => _db
      .collection('Orders')
      .doc(orderId)
      .collection('Events')
      .orderBy('at', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(OrderEvent.fromFirestore).toList())
      .transform(logStreamErrors('[ops] streamEvents($orderId) failed'));

  /// The customer's own delivery handover code.
  Stream<String?> streamDeliveryCode(String orderId) => _db
      .collection('OrderSecrets')
      .doc(orderId)
      .snapshots()
      .map((s) => s.data()?['deliveryCode'] as String?)
      .handleError((Object _) => null);

  Future<String> _upload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    final task = await _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
    return task.ref.getDownloadURL();
  }

  Future<void> recordQualityCheck({
    required String orderId,
    required bool passed,
    required Map<int, bool> checks,
    required String notes,
    List<(Uint8List, String)> photos = const [],
  }) async {
    final urls = <String>[];
    for (final (i, (bytes, type)) in photos.indexed) {
      urls.add(
        await _upload(
          'qc/$orderId/${DateTime.now().millisecondsSinceEpoch}_$i',
          bytes,
          type,
        ),
      );
    }
    await _call('recordQualityCheck').call({
      'orderId': orderId,
      'passed': passed,
      'checks': {for (final e in checks.entries) '${e.key}': e.value},
      'notes': notes,
      'photoUrls': urls,
    });
  }

  Future<bool> completeDelivery({
    required String orderId,
    required String recipientName,
    String? code,
    Uint8List? photo,
    Uint8List? signaturePng,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final photoUrl = photo == null
        ? null
        : await _upload('pod/$orderId/photo_$stamp', photo, 'image/jpeg');
    final signatureUrl = signaturePng == null
        ? null
        : await _upload(
            'pod/$orderId/signature_$stamp',
            signaturePng,
            'image/png',
          );
    final result = await _call('completeDelivery').call({
      'orderId': orderId,
      'recipientName': recipientName,
      if ((code ?? '').isNotEmpty) 'code': code,
      'photoUrl': ?photoUrl,
      'signatureUrl': ?signatureUrl,
    });
    return (result.data as Map)['codeVerified'] as bool? ?? false;
  }

  Stream<List<InventoryMovement>> streamMovements() => _db
      .collection('InventoryMovements')
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(InventoryMovement.fromFirestore).toList())
      .transform(logStreamErrors('[ops] streamMovements failed'));

  Stream<List<PurchaseOrder>> streamPurchaseOrders() => _db
      .collection('PurchaseOrders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PurchaseOrder.fromFirestore).toList())
      .transform(logStreamErrors('[ops] streamPurchaseOrders failed'));

  Future<String> createPurchaseOrder({
    required String supplierName,
    required String supplierContact,
    required List<PurchaseOrderLine> lines,
    DateTime? expectedDate,
    String notes = '',
  }) async {
    final r = await _call('createPurchaseOrder').call({
      'supplierName': supplierName,
      'supplierContact': supplierContact,
      'lines': [for (final l in lines) l.toMap()],
      if (expectedDate != null) 'expectedDate': expectedDate.toIso8601String(),
      'notes': notes,
    });
    return (r.data as Map)['poNumber'] as String;
  }

  Future<void> setPurchaseOrderStatus(
    String poId,
    String status, {
    required String uid,
  }) => _db.collection('PurchaseOrders').doc(poId).update({
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  });

  Future<void> receivePurchaseOrder(String poId, {required bool logExpense}) =>
      _call(
        'receivePurchaseOrder',
      ).call({'poId': poId, 'logExpense': logExpense});

  Stream<List<AuditEntry>> streamAudit() => _db
      .collection('AuditLog')
      .orderBy('at', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(AuditEntry.fromFirestore).toList())
      .transform(logStreamErrors('[ops] streamAudit failed'));
}
