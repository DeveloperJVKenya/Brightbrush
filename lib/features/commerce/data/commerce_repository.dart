import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';

/// PDF kinds the getDocument function can produce.
enum DocumentKind { invoice, receipt, creditNote, quote, statement }

class CustomerAccount {
  const CustomerAccount({
    required this.uid,
    this.companyName = '',
    this.kraPin = '',
    this.discountPercent = 0,
    this.creditEnabled = false,
    this.creditLimit = 0,
    this.paymentTermsDays = 30,
    this.notes = '',
  });

  final String uid;
  final String companyName;
  final String kraPin;
  final num discountPercent;
  final bool creditEnabled;
  final num creditLimit;
  final int paymentTermsDays;
  final String notes;

  bool get isBusiness =>
      companyName.isNotEmpty || discountPercent > 0 || creditEnabled;

  factory CustomerAccount.fromMap(String uid, Map<String, dynamic>? d) {
    if (d == null) return CustomerAccount(uid: uid);
    return CustomerAccount(
      uid: uid,
      companyName: d['companyName'] as String? ?? '',
      kraPin: d['kraPin'] as String? ?? '',
      discountPercent: d['discountPercent'] as num? ?? 0,
      creditEnabled: d['creditEnabled'] as bool? ?? false,
      creditLimit: d['creditLimit'] as num? ?? 0,
      paymentTermsDays: (d['paymentTermsDays'] as num?)?.toInt() ?? 30,
      notes: d['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore({required String adminUid}) => {
    'companyName': companyName,
    'kraPin': kraPin,
    'discountPercent': discountPercent,
    'creditEnabled': creditEnabled,
    'creditLimit': creditLimit,
    'paymentTermsDays': paymentTermsDays,
    'notes': notes,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': adminUid,
  };
}

class Coupon {
  const Coupon({
    required this.code,
    this.description = '',
    this.type = 'percent',
    this.value = 10,
    this.minSubtotal = 0,
    this.maxDiscount = 0,
    this.validFrom,
    this.validTo,
    this.usageLimit = 0,
    this.perCustomerLimit = 1,
    this.usedCount = 0,
    this.active = true,
    this.createdAt,
  });

  final String code;
  final String description;

  /// 'percent' or 'fixed'.
  final String type;
  final num value;
  final num minSubtotal;
  final num maxDiscount;
  final DateTime? validFrom;
  final DateTime? validTo;
  final int usageLimit;
  final int perCustomerLimit;
  final int usedCount;
  final bool active;
  final DateTime? createdAt;

  factory Coupon.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Coupon(
      code: doc.id,
      description: d['description'] as String? ?? '',
      type: d['type'] as String? ?? 'percent',
      value: d['value'] as num? ?? 0,
      minSubtotal: d['minSubtotal'] as num? ?? 0,
      maxDiscount: d['maxDiscount'] as num? ?? 0,
      validFrom: (d['validFrom'] as Timestamp?)?.toDate(),
      validTo: (d['validTo'] as Timestamp?)?.toDate(),
      usageLimit: (d['usageLimit'] as num?)?.toInt() ?? 0,
      perCustomerLimit: (d['perCustomerLimit'] as num?)?.toInt() ?? 0,
      usedCount: (d['usedCount'] as num?)?.toInt() ?? 0,
      active: d['active'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RefundRecord {
  const RefundRecord({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.creditNoteNumber,
    required this.reason,
    required this.cancelled,
    required this.cancellationFee,
    required this.allocations,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final num amount;
  final String creditNoteNumber;
  final String reason;
  final bool cancelled;
  final num cancellationFee;
  final List<Map<String, dynamic>> allocations;
  final DateTime createdAt;

  factory RefundRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return RefundRecord(
      id: doc.id,
      orderId: d['orderId'] as String? ?? '',
      amount: d['amount'] as num? ?? 0,
      creditNoteNumber: d['creditNoteNumber'] as String? ?? '',
      reason: d['reason'] as String? ?? '',
      cancelled: d['cancelled'] as bool? ?? false,
      cancellationFee: d['cancellationFee'] as num? ?? 0,
      allocations: [
        for (final a in (d['allocations'] as List? ?? const []))
          Map<String, dynamic>.from(a as Map),
      ],
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DiscountPreview {
  const DiscountPreview({
    required this.valid,
    required this.message,
    required this.corporate,
    required this.coupon,
  });

  final bool valid;
  final String message;
  final num corporate;
  final num coupon;

  num get total => corporate + coupon;
}

/// Invoicing, discounts, refunds, eTIMS and accounting — everything that
/// needs server authority goes through Cloud Functions.
class CommerceRepository {
  CommerceRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  HttpsCallable _call(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
  );

  Future<({String fileName, Uint8List bytes})> getDocument(
    DocumentKind kind,
    String? id,
  ) async {
    appLogger.i('[documents] getDocument(${kind.name}, $id)');
    final result = await _call(
      'getDocument',
    ).call({'kind': kind.name, 'id': ?id});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      fileName: data['fileName'] as String,
      bytes: base64Decode(data['base64'] as String),
    );
  }

  Future<DiscountPreview> previewDiscount({
    required num subtotal,
    required String couponCode,
  }) async {
    final result = await _call(
      'previewDiscount',
    ).call({'subtotal': subtotal, 'couponCode': couponCode});
    final d = Map<String, dynamic>.from(result.data as Map);
    return DiscountPreview(
      valid: d['valid'] as bool? ?? false,
      message: d['message'] as String? ?? '',
      corporate: d['corporate'] as num? ?? 0,
      coupon: d['coupon'] as num? ?? 0,
    );
  }

  Future<Map<String, dynamic>> issueRefund({
    required String orderId,
    required String reason,
    num? amount,
    bool cancelOrder = false,
    num cancellationFee = 0,
  }) async {
    appLogger.i(
      '[refunds] issueRefund($orderId, amount=$amount, cancel=$cancelOrder)',
    );
    final result = await _call('issueRefund').call({
      'orderId': orderId,
      'reason': reason,
      'amount': ?amount,
      'cancelOrder': cancelOrder,
      'cancellationFee': cancellationFee,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> submitEtims(String orderId) async {
    await _call('submitEtimsInvoice').call({'orderId': orderId});
  }

  Future<Map<String, dynamic>> exportAccounting(
    DateTime from,
    DateTime to,
  ) async {
    final result = await _call('exportAccounting').call({
      'from': from.toIso8601String().substring(0, 10),
      'to': to.toIso8601String().substring(0, 10),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> adminGetEtims() async =>
      Map<String, dynamic>.from(
        (await _call('adminGetEtims').call()).data as Map,
      );

  Future<Map<String, dynamic>> adminSaveEtims({
    required String mode,
    required bool enabled,
    required bool autoSubmit,
    required Map<String, String> values,
  }) async => Map<String, dynamic>.from(
    (await _call('adminSaveEtims').call({
          'mode': mode,
          'enabled': enabled,
          'autoSubmit': autoSubmit,
          'values': values,
        })).data
        as Map,
  );

  Future<({bool ok, String message})> adminInitEtims() async {
    final d = Map<String, dynamic>.from(
      (await _call('adminInitEtims').call()).data as Map,
    );
    return (
      ok: d['ok'] as bool? ?? false,
      message: d['message'] as String? ?? '',
    );
  }

  Stream<bool> streamEtimsEnabled() => _db
      .collection('Integrations')
      .doc('etims')
      .snapshots()
      .map((s) => s.data()?['enabled'] as bool? ?? false)
      .handleError((Object _) => false);

  Stream<CustomerAccount> streamAccount(String uid) => _db
      .collection('CustomerAccounts')
      .doc(uid)
      .snapshots()
      .map((s) => CustomerAccount.fromMap(uid, s.data()))
      .transform(logStreamErrors('[accounts] streamAccount($uid) failed'));

  Stream<Map<String, CustomerAccount>> streamAllAccounts() => _db
      .collection('CustomerAccounts')
      .snapshots()
      .map(
        (snap) => {
          for (final d in snap.docs)
            d.id: CustomerAccount.fromMap(d.id, d.data()),
        },
      )
      .transform(logStreamErrors('[accounts] streamAllAccounts failed'));

  Future<void> saveAccount(
    CustomerAccount account, {
    required String adminUid,
  }) => _db
      .collection('CustomerAccounts')
      .doc(account.uid)
      .set(account.toFirestore(adminUid: adminUid));

  Stream<List<Coupon>> streamCoupons() => _db
      .collection('Coupons')
      .snapshots()
      .map(
        (snap) => snap.docs.map(Coupon.fromFirestore).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          ),
      )
      .transform(logStreamErrors('[coupons] streamCoupons failed'));

  Future<void> saveCoupon(Coupon c, {required bool isNew}) {
    final ref = _db.collection('Coupons').doc(c.code);
    final data = {
      'code': c.code,
      'description': c.description,
      'type': c.type,
      'value': c.value,
      'minSubtotal': c.minSubtotal,
      'maxDiscount': c.maxDiscount,
      if (c.validFrom != null) 'validFrom': Timestamp.fromDate(c.validFrom!),
      if (c.validTo != null) 'validTo': Timestamp.fromDate(c.validTo!),
      'usageLimit': c.usageLimit,
      'perCustomerLimit': c.perCustomerLimit,
      'active': c.active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isNew) {
      return ref.set({
        ...data,
        'usedCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return ref.update(data);
  }

  Future<void> deleteCoupon(String code) =>
      _db.collection('Coupons').doc(code).delete();

  Stream<List<RefundRecord>> streamRefunds(
    String orderId, {
    String? customerId,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('Refunds')
        .where('orderId', isEqualTo: orderId);
    if (customerId != null) q = q.where('customerId', isEqualTo: customerId);
    return q
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(RefundRecord.fromFirestore).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        )
        .transform(logStreamErrors('[refunds] streamRefunds($orderId) failed'));
  }
}
