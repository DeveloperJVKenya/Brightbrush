/// Pure pricing maths — no Firebase imports, so it's unit-testable and the
/// Dart mirror (lib/features/payments/domain/business_settings.dart →
/// OrderPricing) can be checked against the same cases. The server result is
/// always authoritative; the client copy is only a checkout preview.

export interface PricingSettings {
  vatEnabled: boolean;
  /// 0..1, e.g. 0.16 for Kenya's standard VAT.
  vatRate: number;
  /// true: catalog prices already include VAT (the VAT is extracted for the
  /// invoice). false: VAT is added on top of subtotal + delivery.
  pricesIncludeVat: boolean;
  deliveryFlatFee: number;
  /// Orders whose subtotal reaches this get free delivery. 0 = never free.
  freeDeliveryThreshold: number;
  allowDeposit: boolean;
  /// 0..100 — share of the total due upfront when paying by deposit.
  depositPercent: number;
}

export type PaymentPlan = 'full' | 'deposit';

export interface OrderTotals {
  subtotal: number;
  deliveryFee: number;
  taxRate: number;
  taxAmount: number;
  total: number;
  paymentPlan: PaymentPlan;
  /// Amount that must be paid before production starts. Equals total for
  /// 'full' plans.
  depositAmount: number;
}

/// KES is priced in whole shillings throughout the app.
function roundMoney(value: number): number {
  return Math.round(value);
}

export function computeTotals(
  subtotal: number,
  settings: PricingSettings,
  options: { paymentPlan: PaymentPlan; includeDelivery: boolean },
): OrderTotals {
  const cleanSubtotal = roundMoney(subtotal);
  const deliveryFee =
    !options.includeDelivery ||
    settings.deliveryFlatFee <= 0 ||
    (settings.freeDeliveryThreshold > 0 &&
      cleanSubtotal >= settings.freeDeliveryThreshold)
      ? 0
      : roundMoney(settings.deliveryFlatFee);

  const taxable = cleanSubtotal + deliveryFee;
  const taxRate = settings.vatEnabled ? settings.vatRate : 0;
  let taxAmount = 0;
  let total = taxable;
  if (taxRate > 0) {
    if (settings.pricesIncludeVat) {
      taxAmount = roundMoney(taxable - taxable / (1 + taxRate));
    } else {
      taxAmount = roundMoney(taxable * taxRate);
      total = taxable + taxAmount;
    }
  }

  const paymentPlan: PaymentPlan =
    options.paymentPlan === 'deposit' &&
    settings.allowDeposit &&
    settings.depositPercent > 0 &&
    settings.depositPercent < 100
      ? 'deposit'
      : 'full';
  const depositAmount =
    paymentPlan === 'deposit'
      ? Math.ceil((total * settings.depositPercent) / 100)
      : total;

  return {
    subtotal: cleanSubtotal,
    deliveryFee,
    taxRate,
    taxAmount,
    total,
    paymentPlan,
    depositAmount,
  };
}

/// How much the customer owes right now for a given choice. 'deposit'
/// only means something until the deposit is covered; after that (or on a
/// 'full' plan) it's always the outstanding balance.
export function amountDue(
  order: { total: number; amountPaid: number; depositAmount: number },
  choice: 'deposit' | 'balance',
): number {
  const balance = Math.max(0, order.total - order.amountPaid);
  if (choice === 'deposit' && order.amountPaid < order.depositAmount) {
    return Math.min(balance, order.depositAmount - order.amountPaid);
  }
  return balance;
}

export function paymentStatusFor(
  total: number,
  amountPaid: number,
): 'unpaid' | 'partiallyPaid' | 'paid' {
  if (amountPaid <= 0) return 'unpaid';
  if (amountPaid >= total) return 'paid';
  return 'partiallyPaid';
}
