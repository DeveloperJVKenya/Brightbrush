import 'package:brightbrush/features/payments/domain/business_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same cases as functions/src/orders/pricing.test.ts — the checkout
/// preview must agree with what placeOrder actually charges.
void main() {
  const base = BusinessSettings(
    vatEnabled: false,
    vatRate: 0.16,
    pricesIncludeVat: true,
    deliveryFlatFee: 0,
    freeDeliveryThreshold: 0,
    allowDeposit: true,
    depositPercent: 50,
  );

  BusinessSettings copy({
    bool? vatEnabled,
    bool? pricesIncludeVat,
    num? deliveryFlatFee,
    num? freeDeliveryThreshold,
    bool? allowDeposit,
  }) => BusinessSettings(
    vatEnabled: vatEnabled ?? base.vatEnabled,
    vatRate: base.vatRate,
    pricesIncludeVat: pricesIncludeVat ?? base.pricesIncludeVat,
    deliveryFlatFee: deliveryFlatFee ?? base.deliveryFlatFee,
    freeDeliveryThreshold: freeDeliveryThreshold ?? base.freeDeliveryThreshold,
    allowDeposit: allowDeposit ?? base.allowDeposit,
    depositPercent: base.depositPercent,
  );

  test('no VAT, no delivery: total equals subtotal', () {
    final t = OrderPricing.compute(12000, base, paymentPlan: 'full');
    expect(t.total, 12000);
    expect(t.taxAmount, 0);
    expect(t.depositAmount, 12000);
  });

  test('VAT-inclusive prices extract VAT without changing the total', () {
    final t = OrderPricing.compute(
      11600,
      copy(vatEnabled: true),
      paymentPlan: 'full',
    );
    expect(t.total, 11600);
    expect(t.taxAmount, 1600);
  });

  test('VAT-exclusive prices add VAT on subtotal + delivery', () {
    final t = OrderPricing.compute(
      10000,
      copy(vatEnabled: true, pricesIncludeVat: false, deliveryFlatFee: 500),
      paymentPlan: 'full',
    );
    expect(t.deliveryFee, 500);
    expect(t.taxAmount, 1680);
    expect(t.total, 12180);
  });

  test('free delivery above the threshold, and never for quotes', () {
    final s = copy(deliveryFlatFee: 400, freeDeliveryThreshold: 20000);
    expect(
      OrderPricing.compute(19999, s, paymentPlan: 'full').deliveryFee,
      400,
    );
    expect(OrderPricing.compute(20000, s, paymentPlan: 'full').deliveryFee, 0);
    expect(
      OrderPricing.compute(
        100,
        s,
        paymentPlan: 'full',
        includeDelivery: false,
      ).deliveryFee,
      0,
    );
  });

  test('deposit rounds up and falls back to full when deposits are off', () {
    expect(
      OrderPricing.compute(1001, base, paymentPlan: 'deposit').depositAmount,
      501,
    );
    final off = OrderPricing.compute(
      1000,
      copy(allowDeposit: false),
      paymentPlan: 'deposit',
    );
    expect(off.paymentPlan, 'full');
    expect(off.depositAmount, 1000);
  });

  test('discount before delivery and VAT; zone fee; pickup; credit', () {
    final vatEx = copy(
      vatEnabled: true,
      pricesIncludeVat: false,
      freeDeliveryThreshold: 9500,
    );
    final t = OrderPricing.compute(
      10000,
      vatEx,
      paymentPlan: 'full',
      deliveryFee: 600,
      discount: 1000,
    );
    expect(t.discountAmount, 1000);
    expect(t.deliveryFee, 600);
    expect(t.total, (9600 * 1.16).round());
    final flat = copy(deliveryFlatFee: 300);
    expect(
      OrderPricing.compute(
        1000,
        flat,
        paymentPlan: 'full',
        deliveryFee: 800,
      ).deliveryFee,
      800,
    );
    expect(
      OrderPricing.compute(
        1000,
        flat,
        paymentPlan: 'full',
        includeDelivery: false,
      ).deliveryFee,
      0,
    );
    final credit = OrderPricing.compute(
      5000,
      base,
      paymentPlan: 'credit',
      creditAllowed: true,
    );
    expect(credit.paymentPlan, 'credit');
    expect(credit.depositAmount, 0);
    expect(
      OrderPricing.compute(5000, base, paymentPlan: 'credit').paymentPlan,
      'full',
    );
  });
}
