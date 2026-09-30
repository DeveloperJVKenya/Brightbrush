import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/monitoring/monitoring.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/stream_error_logger.dart';
import '../domain/business_settings.dart';
import '../domain/payment_models.dart';

/// Reads payment state straight from Firestore (gateways, ledger,
/// settings) and performs every money-moving action through Cloud
/// Functions — the client never writes Payments or order totals itself.
class PaymentsRepository {
  PaymentsRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<BusinessSettings> streamBusinessSettings() {
    return _db
        .collection('Settings')
        .doc('business')
        .snapshots()
        .map((snap) => BusinessSettings.fromMap(snap.data()))
        .transform(logStreamErrors('[payments] streamBusinessSettings failed'));
  }

  Future<void> saveBusinessSettings(
    BusinessSettings settings, {
    required String uid,
  }) async {
    appLogger.i('[payments] saveBusinessSettings by uid=$uid');
    try {
      await _db
          .collection('Settings')
          .doc('business')
          .set(settings.toFirestore(uid: uid));
    } catch (error, stack) {
      appLogger.e(
        '[payments] saveBusinessSettings failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Stream<List<PaymentGatewayInfo>> streamGateways() {
    return _db
        .collection('PaymentGateways')
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs) ?PaymentGatewayInfo.fromFirestore(doc),
          ]..sort((a, b) => a.id.index.compareTo(b.id.index)),
        )
        .transform(logStreamErrors('[payments] streamGateways failed'));
  }

  /// Payment attempts for one order, newest first. Customers must filter by
  /// their own uid (firestore.rules only lets them read their own
  /// Payments); staff pass `customerId: null` to see all.
  Stream<List<PaymentRecord>> streamForOrder(
    String orderId, {
    String? customerId,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('Payments')
        .where('orderId', isEqualTo: orderId);
    if (customerId != null) q = q.where('customerId', isEqualTo: customerId);
    return q
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(PaymentRecord.fromFirestore).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        )
        .transform(
          logStreamErrors('[payments] streamForOrder($orderId) failed'),
        );
  }

  Future<PaymentStartResult> initiatePayment({
    required String orderId,
    required PaymentGatewayId gateway,
    required String amountChoice,
    String? phone,
  }) async {
    appLogger.i(
      '[payments] initiatePayment(order=$orderId, gateway=${gateway.name}, choice=$amountChoice)',
    );
    try {
      final result = await _functions.httpsCallable('initiatePayment').call({
        'orderId': orderId,
        'gateway': gateway.name,
        'amountChoice': amountChoice,
        'phone': ?phone,
      });
      Monitoring.paymentStarted(gateway.name, 0);
      return PaymentStartResult.fromMap(
        Map<String, dynamic>.from(result.data as Map),
      );
    } catch (error, stack) {
      appLogger.e(
        '[payments] initiatePayment failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<String> refreshStatus(String paymentId) async {
    final result = await _functions.httpsCallable('refreshPaymentStatus').call({
      'paymentId': paymentId,
    });
    return (result.data as Map)['status'] as String? ?? 'pending';
  }

  Future<void> recordManualPayment({
    required String orderId,
    required num amount,
    required String method,
    required String reference,
    required String note,
  }) async {
    appLogger.i(
      '[payments] recordManualPayment(order=$orderId, amount=$amount, method=$method)',
    );
    try {
      await _functions.httpsCallable('recordManualPayment').call({
        'orderId': orderId,
        'amount': amount,
        'method': method,
        'reference': reference,
        'note': note,
      });
    } catch (error, stack) {
      appLogger.e(
        '[payments] recordManualPayment failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<GatewayAdminConfig>> adminLoadGateways() async {
    final result = await _functions
        .httpsCallable('adminGetPaymentGateways')
        .call();
    final list = (result.data as Map)['gateways'] as List;
    return [
      for (final g in list)
        GatewayAdminConfig.fromMap(Map<String, dynamic>.from(g as Map)),
    ];
  }

  Future<void> adminSaveGateway({
    required PaymentGatewayId id,
    required String mode,
    required bool enabled,
    required Map<String, String> values,
    bool clear = false,
  }) async {
    appLogger.i(
      '[payments] adminSaveGateway(${id.name}, mode=$mode, enabled=$enabled, clear=$clear)',
    );
    await _functions.httpsCallable('adminSavePaymentGateway').call({
      'id': id.name,
      'mode': mode,
      'enabled': enabled,
      'values': values,
      'clear': clear,
    });
  }

  Future<({bool ok, String message})> adminTestGateway(
    PaymentGatewayId id,
  ) async {
    final result = await _functions
        .httpsCallable('adminTestPaymentGateway')
        .call({'id': id.name});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      ok: data['ok'] as bool? ?? false,
      message: data['message'] as String? ?? '',
    );
  }
}
