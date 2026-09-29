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

/// 'credit' is only granted to business accounts with credit terms: nothing
/// is due upfront and the invoice is due after the account's terms.
export type PaymentPlan = 'full' | 'deposit' | 'credit';

export interface OrderTotals {
  subtotal: number;
  /// Corporate discount + coupon, taken off the subtotal before delivery
  /// and VAT.
  discountAmount: number;
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

export interface Coupon {
  type: 'percent' | 'fixed';
  value: number;
  minSubtotal: number;
  /// Cap for percentage coupons. 0 = no cap.
  maxDiscount: number;
}

export interface DiscountBreakdown {
  corporate: number;
  coupon: number;
  total: number;
}

/// Corporate account discount first, then the coupon on what's left. A
/// coupon whose minimum spend isn't met contributes nothing.
export function computeDiscount(
  subtotal: number,
  options: { corporatePercent?: number; coupon?: Coupon | null },
): DiscountBreakdown {
  const pct = Math.min(100, Math.max(0, options.corporatePercent ?? 0));
  const corporate = roundMoney((subtotal * pct) / 100);
  let coupon = 0;
  const c = options.coupon;
  const remaining = subtotal - corporate;
  if (c && subtotal >= c.minSubtotal) {
    coupon =
      c.type === 'percent'
        ? roundMoney((remaining * Math.min(100, Math.max(0, c.value))) / 100)
        : roundMoney(Math.max(0, c.value));
    if (c.type === 'percent' && c.maxDiscount > 0) {
      coupon = Math.min(coupon, c.maxDiscount);
    }
    coupon = Math.min(coupon, remaining);
  }
  return { corporate, coupon, total: corporate + coupon };
}

export function computeTotals(
  subtotal: number,
  settings: PricingSettings,
  options: {
    paymentPlan: PaymentPlan;
    includeDelivery: boolean;
    /// The chosen delivery zone's fee; undefined falls back to the flat
    /// fee. Pickup orders pass includeDelivery: false.
    deliveryFee?: number;
    discount?: number;
    creditAllowed?: boolean;
  },
): OrderTotals {
  const cleanSubtotal = roundMoney(subtotal);
  const discountAmount = Math.min(
    cleanSubtotal,
    Math.max(0, roundMoney(options.discount ?? 0)),
  );
  const netSubtotal = cleanSubtotal - discountAmount;
  const baseFee = options.deliveryFee ?? settings.deliveryFlatFee;
  const deliveryFee =
    !options.includeDelivery ||
    baseFee <= 0 ||
    (settings.freeDeliveryThreshold > 0 &&
      netSubtotal >= settings.freeDeliveryThreshold)
      ? 0
      : roundMoney(baseFee);

  const taxable = netSubtotal + deliveryFee;
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
    options.paymentPlan === 'credit' && options.creditAllowed
      ? 'credit'
      : options.paymentPlan === 'deposit' &&
          settings.allowDeposit &&
          settings.depositPercent > 0 &&
          settings.depositPercent < 100
        ? 'deposit'
        : 'full';
  const depositAmount =
    paymentPlan === 'credit'
      ? 0
      : paymentPlan === 'deposit'
        ? Math.ceil((total * settings.depositPercent) / 100)
        : total;

  return {
    subtotal: cleanSubtotal,
    discountAmount,
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
