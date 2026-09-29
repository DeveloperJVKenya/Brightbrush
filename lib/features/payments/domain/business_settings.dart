import 'package:cloud_firestore/cloud_firestore.dart';

/// Settings/business — VAT, delivery, deposits and the business details
/// printed on invoices. Edited by Admin/CEO under Payments & Settings.
/// Defaults match `DEFAULT_BUSINESS_SETTINGS` in
/// functions/src/settings/business_settings.ts so the checkout preview and
/// the server agree even before anyone has saved settings.
class BusinessSettings {
  const BusinessSettings({
    this.businessName = 'BrightBrush Creations',
    this.appBaseUrl = 'https://bright-brush.web.app',
    this.supportPhone = '',
    this.supportEmail = '',
    this.kraPin = '',
    this.vatEnabled = false,
    this.vatRate = 0.16,
    this.pricesIncludeVat = true,
    this.deliveryFlatFee = 0,
    this.freeDeliveryThreshold = 0,
    this.allowDeposit = true,
    this.depositPercent = 50,
  });

  final String businessName;
  final String appBaseUrl;
  final String supportPhone;
  final String supportEmail;
  final String kraPin;
  final bool vatEnabled;

  /// 0..1 — 0.16 is Kenya's standard VAT rate.
  final double vatRate;
  final bool pricesIncludeVat;
  final num deliveryFlatFee;
  final num freeDeliveryThreshold;
  final bool allowDeposit;

  /// 0..100.
  final num depositPercent;

  bool get depositsAvailable =>
      allowDeposit && depositPercent > 0 && depositPercent < 100;

  factory BusinessSettings.fromMap(Map<String, dynamic>? d) {
    const f = BusinessSettings();
    if (d == null) return f;
    String str(String key, String fallback) {
      final v = d[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : fallback;
    }

    return BusinessSettings(
      businessName: str('businessName', f.businessName),
      appBaseUrl: str('appBaseUrl', f.appBaseUrl),
      supportPhone: str('supportPhone', f.supportPhone),
      supportEmail: str('supportEmail', f.supportEmail),
      kraPin: str('kraPin', f.kraPin),
      vatEnabled: d['vatEnabled'] as bool? ?? f.vatEnabled,
      vatRate: (d['vatRate'] as num?)?.toDouble() ?? f.vatRate,
      pricesIncludeVat: d['pricesIncludeVat'] as bool? ?? f.pricesIncludeVat,
      deliveryFlatFee: d['deliveryFlatFee'] as num? ?? f.deliveryFlatFee,
      freeDeliveryThreshold:
          d['freeDeliveryThreshold'] as num? ?? f.freeDeliveryThreshold,
      allowDeposit: d['allowDeposit'] as bool? ?? f.allowDeposit,
      depositPercent: d['depositPercent'] as num? ?? f.depositPercent,
    );
  }

  Map<String, dynamic> toFirestore({required String uid}) {
    return {
      'businessName': businessName,
      'appBaseUrl': appBaseUrl,
      'supportPhone': supportPhone,
      'supportEmail': supportEmail,
      'kraPin': kraPin,
      'vatEnabled': vatEnabled,
      'vatRate': vatRate,
      'pricesIncludeVat': pricesIncludeVat,
      'deliveryFlatFee': deliveryFlatFee,
      'freeDeliveryThreshold': freeDeliveryThreshold,
      'allowDeposit': allowDeposit,
      'depositPercent': depositPercent,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    };
  }
}

/// Checkout preview of what the server will charge. This is a mirror of
/// `computeTotals` in functions/src/orders/pricing.ts — keep the two in
/// step. The placed order always carries the server's own numbers.
class OrderPricing {
  const OrderPricing({
    required this.subtotal,
    required this.deliveryFee,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.paymentPlan,
    required this.depositAmount,
    required this.pricesIncludeVat,
  });

  final num subtotal;
  final num deliveryFee;
  final double taxRate;
  final num taxAmount;
  final num total;
  final String paymentPlan;
  final num depositAmount;
  final bool pricesIncludeVat;

  factory OrderPricing.compute(
    num subtotal,
    BusinessSettings s, {
    required String paymentPlan,
    bool includeDelivery = true,
  }) {
    final cleanSubtotal = subtotal.round();
    final deliveryFee =
        !includeDelivery ||
            s.deliveryFlatFee <= 0 ||
            (s.freeDeliveryThreshold > 0 &&
                cleanSubtotal >= s.freeDeliveryThreshold)
        ? 0
        : s.deliveryFlatFee.round();
    final taxable = cleanSubtotal + deliveryFee;
    final taxRate = s.vatEnabled ? s.vatRate : 0.0;
    num taxAmount = 0;
    num total = taxable;
    if (taxRate > 0) {
      if (s.pricesIncludeVat) {
        taxAmount = (taxable - taxable / (1 + taxRate)).round();
      } else {
        taxAmount = (taxable * taxRate).round();
        total = taxable + taxAmount;
      }
    }
    final plan = paymentPlan == 'deposit' && s.depositsAvailable
        ? 'deposit'
        : 'full';
    final deposit = plan == 'deposit'
        ? (total * s.depositPercent / 100).ceil()
        : total;
    return OrderPricing(
      subtotal: cleanSubtotal,
      deliveryFee: deliveryFee,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
      paymentPlan: plan,
      depositAmount: deposit,
      pricesIncludeVat: s.pricesIncludeVat,
    );
  }
}
