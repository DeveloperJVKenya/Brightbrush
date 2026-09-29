import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  PricingSettings,
  amountDue,
  computeDiscount,
  computeTotals,
  paymentStatusFor,
} from './pricing';

const base: PricingSettings = {
  vatEnabled: false,
  vatRate: 0.16,
  pricesIncludeVat: true,
  deliveryFlatFee: 0,
  freeDeliveryThreshold: 0,
  allowDeposit: true,
  depositPercent: 50,
};

describe('computeTotals', () => {
  it('no VAT, no delivery: total equals subtotal', () => {
    const t = computeTotals(12000, base, { paymentPlan: 'full', includeDelivery: true });
    assert.equal(t.total, 12000);
    assert.equal(t.taxAmount, 0);
    assert.equal(t.depositAmount, 12000);
    assert.equal(t.paymentPlan, 'full');
  });

  it('VAT-inclusive prices extract VAT without changing the total', () => {
    const t = computeTotals(11600, { ...base, vatEnabled: true }, { paymentPlan: 'full', includeDelivery: true });
    assert.equal(t.total, 11600);
    assert.equal(t.taxAmount, 1600);
  });

  it('VAT-exclusive prices add VAT on subtotal + delivery', () => {
    const t = computeTotals(
      10000,
      { ...base, vatEnabled: true, pricesIncludeVat: false, deliveryFlatFee: 500 },
      { paymentPlan: 'full', includeDelivery: true },
    );
    assert.equal(t.deliveryFee, 500);
    assert.equal(t.taxAmount, 1680);
    assert.equal(t.total, 12180);
  });

  it('free delivery above the threshold, and never for quotes', () => {
    const s = { ...base, deliveryFlatFee: 400, freeDeliveryThreshold: 20000 };
    assert.equal(computeTotals(19999, s, { paymentPlan: 'full', includeDelivery: true }).deliveryFee, 400);
    assert.equal(computeTotals(20000, s, { paymentPlan: 'full', includeDelivery: true }).deliveryFee, 0);
    assert.equal(computeTotals(100, s, { paymentPlan: 'full', includeDelivery: false }).deliveryFee, 0);
  });

  it('deposit rounds up and falls back to full when deposits are off', () => {
    assert.equal(computeTotals(1001, base, { paymentPlan: 'deposit', includeDelivery: true }).depositAmount, 501);
    const off = computeTotals(1000, { ...base, allowDeposit: false }, { paymentPlan: 'deposit', includeDelivery: true });
    assert.equal(off.paymentPlan, 'full');
    assert.equal(off.depositAmount, 1000);
  });
});

describe('amountDue', () => {
  const order = { total: 10000, amountPaid: 0, depositAmount: 5000 };
  it('deposit choice charges the remaining deposit only', () => {
    assert.equal(amountDue(order, 'deposit'), 5000);
    assert.equal(amountDue({ ...order, amountPaid: 2000 }, 'deposit'), 3000);
  });
  it('after the deposit is covered, deposit choice charges the balance', () => {
    assert.equal(amountDue({ ...order, amountPaid: 5000 }, 'deposit'), 5000);
  });
  it('balance never goes negative', () => {
    assert.equal(amountDue({ ...order, amountPaid: 12000 }, 'balance'), 0);
  });
});

describe('paymentStatusFor', () => {
  it('maps paid amounts to statuses', () => {
    assert.equal(paymentStatusFor(100, 0), 'unpaid');
    assert.equal(paymentStatusFor(100, 50), 'partiallyPaid');
    assert.equal(paymentStatusFor(100, 100), 'paid');
  });
});

describe('discounts, zones and credit', () => {
  it('applies corporate discount first, then the coupon on the remainder', () => {
    const d = computeDiscount(10000, {
      corporatePercent: 10,
      coupon: { type: 'percent', value: 10, minSubtotal: 0, maxDiscount: 0 },
    });
    assert.deepEqual(d, { corporate: 1000, coupon: 900, total: 1900 });
  });
  it('caps percentage coupons and ignores unmet minimum spend', () => {
    assert.equal(computeDiscount(10000, { coupon: { type: 'percent', value: 50, minSubtotal: 0, maxDiscount: 1000 } }).coupon, 1000);
    assert.equal(computeDiscount(999, { coupon: { type: 'fixed', value: 500, minSubtotal: 1000, maxDiscount: 0 } }).coupon, 0);
    assert.equal(computeDiscount(300, { coupon: { type: 'fixed', value: 500, minSubtotal: 0, maxDiscount: 0 } }).coupon, 300);
  });
  it('discount comes off before delivery and VAT, and counts toward free delivery', () => {
    const t = computeTotals(
      10000,
      { ...base, vatEnabled: true, pricesIncludeVat: false, freeDeliveryThreshold: 9500 },
      { paymentPlan: 'full', includeDelivery: true, deliveryFee: 600, discount: 1000 },
    );
    assert.equal(t.discountAmount, 1000);
    assert.equal(t.deliveryFee, 600);
    assert.equal(t.total, Math.round(9600 * 1.16));
  });
  it('uses the zone fee over the flat fee; pickup has none', () => {
    const s = { ...base, deliveryFlatFee: 300 };
    assert.equal(computeTotals(1000, s, { paymentPlan: 'full', includeDelivery: true, deliveryFee: 800 }).deliveryFee, 800);
    assert.equal(computeTotals(1000, s, { paymentPlan: 'full', includeDelivery: false }).deliveryFee, 0);
  });
  it('credit plan only when allowed, with nothing due upfront', () => {
    const allowed = computeTotals(5000, base, { paymentPlan: 'credit', includeDelivery: true, creditAllowed: true });
    assert.equal(allowed.paymentPlan, 'credit');
    assert.equal(allowed.depositAmount, 0);
    assert.equal(computeTotals(5000, base, { paymentPlan: 'credit', includeDelivery: true }).paymentPlan, 'full');
  });
});
