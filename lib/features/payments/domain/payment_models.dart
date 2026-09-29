import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Online gateways the backend supports. Ids match `GatewayId` in
/// functions/src/payments/gateway_config.ts.
enum PaymentGatewayId {
  mpesa(icon: Icons.phone_android_rounded),
  stripe(icon: Icons.credit_card_rounded),
  paypal(icon: Icons.account_balance_wallet_rounded),
  flutterwave(icon: Icons.payments_rounded);

  const PaymentGatewayId({required this.icon});

  final IconData icon;

  static PaymentGatewayId? fromName(String? name) {
    for (final g in values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

/// PaymentGateways/{id} — the public face of a gateway. A gateway only
/// ever shows up at checkout once an admin has saved complete credentials
/// *and* switched it on ([isAvailable]).
class PaymentGatewayInfo {
  const PaymentGatewayInfo({
    required this.id,
    required this.displayName,
    required this.enabled,
    required this.configured,
    required this.mode,
  });

  final PaymentGatewayId id;
  final String displayName;
  final bool enabled;
  final bool configured;

  /// 'sandbox' or 'live'.
  final String mode;

  bool get isAvailable => enabled && configured;
  bool get isSandbox => mode != 'live';

  static PaymentGatewayInfo? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final id = PaymentGatewayId.fromName(doc.id);
    if (id == null) return null;
    final d = doc.data() ?? {};
    return PaymentGatewayInfo(
      id: id,
      displayName: d['displayName'] as String? ?? doc.id,
      enabled: d['enabled'] as bool? ?? false,
      configured: d['configured'] as bool? ?? false,
      mode: d['mode'] as String? ?? 'sandbox',
    );
  }
}

enum PaymentState {
  pending(label: 'Pending', icon: Icons.hourglass_top_rounded),
  succeeded(label: 'Paid', icon: Icons.check_circle_rounded),
  failed(label: 'Failed', icon: Icons.error_outline_rounded),
  cancelled(label: 'Cancelled', icon: Icons.cancel_outlined);

  const PaymentState({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static PaymentState fromName(String? name) => values.firstWhere(
    (s) => s.name == name,
    orElse: () => PaymentState.pending,
  );
}

/// Payments/{id} — one attempt to pay (part of) an order, written only by
/// Cloud Functions. Offline payments recorded by staff have gateway
/// 'manual' and a [method] (cash, bank transfer, ...).
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.orderId,
    required this.gateway,
    required this.method,
    required this.amount,
    required this.chargedAmount,
    required this.chargedCurrency,
    required this.status,
    required this.receipt,
    required this.message,
    required this.mode,
    required this.createdAt,
    this.receiptNumber,
    this.refundedAmount = 0,
  });

  final String id;
  final String orderId;

  /// Sequential receipt number (RCT-000123) assigned when it succeeded.
  final String? receiptNumber;
  final num refundedAmount;
  final String gateway;
  final String? method;
  final num amount;
  final num? chargedAmount;
  final String? chargedCurrency;
  final PaymentState status;
  final String? receipt;
  final String? message;
  final String mode;
  final DateTime createdAt;

  String get gatewayLabel => switch (gateway) {
    'mpesa' => 'M-Pesa',
    'stripe' => 'Card (Stripe)',
    'paypal' => 'PayPal',
    'flutterwave' => 'Flutterwave',
    'manual' => switch (method) {
      'cash' => 'Cash',
      'bankTransfer' => 'Bank transfer',
      'mpesaManual' => 'M-Pesa (recorded)',
      'cheque' => 'Cheque',
      _ => 'Recorded payment',
    },
    _ => gateway,
  };

  factory PaymentRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return PaymentRecord(
      id: doc.id,
      orderId: d['orderId'] as String? ?? '',
      gateway: d['gateway'] as String? ?? '',
      method: d['method'] as String?,
      amount: d['amount'] as num? ?? 0,
      chargedAmount: d['chargedAmount'] as num?,
      chargedCurrency: d['chargedCurrency'] as String?,
      status: PaymentState.fromName(d['status'] as String?),
      receipt: d['receipt'] as String?,
      message: d['message'] as String?,
      mode: d['mode'] as String? ?? 'live',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      receiptNumber: d['receiptNumber'] as String?,
      refundedAmount: d['refundedAmount'] as num? ?? 0,
    );
  }
}

/// What `initiatePayment` tells the client to do next.
class PaymentStartResult {
  const PaymentStartResult({
    required this.paymentId,
    required this.action,
    required this.redirectUrl,
    required this.message,
    required this.amount,
  });

  final String paymentId;

  /// 'stk' (wait for the M-Pesa PIN prompt) or 'redirect' (open
  /// [redirectUrl] — Stripe/PayPal/Flutterwave hosted checkout).
  final String action;
  final String? redirectUrl;
  final String message;
  final num amount;

  factory PaymentStartResult.fromMap(Map<String, dynamic> d) {
    return PaymentStartResult(
      paymentId: d['paymentId'] as String,
      action: d['action'] as String? ?? 'redirect',
      redirectUrl: d['redirectUrl'] as String?,
      message: d['message'] as String? ?? '',
      amount: d['amount'] as num? ?? 0,
    );
  }
}

/// One credential field in the admin gateway form, as described by
/// `adminGetPaymentGateways`. Secret values never come back from the
/// server — only [hasValue] and a masked [preview].
class GatewayFieldConfig {
  const GatewayFieldConfig({
    required this.key,
    required this.label,
    required this.help,
    required this.secret,
    required this.required,
    required this.options,
    required this.hasValue,
    required this.value,
    required this.preview,
  });

  final String key;
  final String label;
  final String help;
  final bool secret;
  final bool required;
  final List<String>? options;
  final bool hasValue;
  final String value;
  final String preview;

  factory GatewayFieldConfig.fromMap(Map<String, dynamic> d) {
    return GatewayFieldConfig(
      key: d['key'] as String,
      label: d['label'] as String? ?? d['key'] as String,
      help: d['help'] as String? ?? '',
      secret: d['secret'] as bool? ?? false,
      required: d['required'] as bool? ?? false,
      options: (d['options'] as List?)?.cast<String>(),
      hasValue: d['hasValue'] as bool? ?? false,
      value: d['value'] as String? ?? '',
      preview: d['preview'] as String? ?? '',
    );
  }
}

class GatewayAdminConfig {
  const GatewayAdminConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.signupUrl,
    required this.mode,
    required this.enabled,
    required this.configured,
    required this.integrationUrls,
    required this.lastTestOk,
    required this.lastTestMessage,
    required this.fields,
  });

  final PaymentGatewayId id;
  final String displayName;
  final String description;
  final String signupUrl;
  final String mode;
  final bool enabled;
  final bool configured;
  final Map<String, String> integrationUrls;
  final bool? lastTestOk;
  final String? lastTestMessage;
  final List<GatewayFieldConfig> fields;

  factory GatewayAdminConfig.fromMap(Map<String, dynamic> d) {
    final lastTest = d['lastTest'] == null
        ? null
        : Map<String, dynamic>.from(d['lastTest'] as Map);
    return GatewayAdminConfig(
      id: PaymentGatewayId.fromName(d['id'] as String)!,
      displayName: d['displayName'] as String? ?? '',
      description: d['description'] as String? ?? '',
      signupUrl: d['signupUrl'] as String? ?? '',
      mode: d['mode'] as String? ?? 'sandbox',
      enabled: d['enabled'] as bool? ?? false,
      configured: d['configured'] as bool? ?? false,
      integrationUrls: Map<String, String>.from(
        (d['integrationUrls'] as Map?) ?? const {},
      ),
      lastTestOk: lastTest?['ok'] as bool?,
      lastTestMessage: lastTest?['message'] as String?,
      fields: [
        for (final f in (d['fields'] as List? ?? const []))
          GatewayFieldConfig.fromMap(Map<String, dynamic>.from(f as Map)),
      ],
    );
  }
}
