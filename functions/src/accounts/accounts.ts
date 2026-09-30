import { FieldValue, Timestamp, Transaction } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { loadCaller } from '../core/authz';
import { asObject, requireNumber } from '../core/validate';
import { Coupon, computeDiscount } from '../orders/pricing';

/// CustomerAccounts/{uid} — set by Admin/CEO for business customers:
/// company details for invoices, a standing discount, and credit terms.
export interface CustomerAccount {
  /// Set when the customer is a buyer under a Companies/{id} account; the
  /// company's terms (and credit exposure across all its buyers) apply.
  companyId?: string;
  memberIds?: string[];
  companyName: string;
  kraPin: string;
  discountPercent: number;
  creditEnabled: boolean;
  /// 0 = no limit.
  creditLimit: number;
  paymentTermsDays: number;
}

export const NO_ACCOUNT: CustomerAccount = {
  companyName: '',
  kraPin: '',
  discountPercent: 0,
  creditEnabled: false,
  creditLimit: 0,
  paymentTermsDays: 30,
};

export async function loadCustomerAccount(uid: string): Promise<CustomerAccount> {
  const num = (v: unknown, fallback: number, max: number) =>
    typeof v === 'number' && v >= 0 && v <= max ? v : fallback;
  const company = await db.collection('Companies').where('memberIds', 'array-contains', uid).limit(1).get();
  if (!company.empty) {
    const c = company.docs[0].data();
    return {
      companyId: company.docs[0].id,
      memberIds: (c.memberIds as string[]) ?? [uid],
      companyName: typeof c.name === 'string' ? c.name : '',
      kraPin: typeof c.kraPin === 'string' ? c.kraPin : '',
      discountPercent: num(c.discountPercent, 0, 100),
      creditEnabled: c.creditEnabled === true,
      creditLimit: num(c.creditLimit, 0, 1e10),
      paymentTermsDays: num(c.paymentTermsDays, 30, 365),
    };
  }
  const d = (await db.collection('CustomerAccounts').doc(uid).get()).data();
  if (!d) return NO_ACCOUNT;
  return {
    companyName: typeof d.companyName === 'string' ? d.companyName : '',
    kraPin: typeof d.kraPin === 'string' ? d.kraPin : '',
    discountPercent: num(d.discountPercent, 0, 100),
    creditEnabled: d.creditEnabled === true,
    creditLimit: num(d.creditLimit, 0, 1e10),
    paymentTermsDays: num(d.paymentTermsDays, 30, 365),
  };
}

/// Everything the customer still owes across open (non-cancelled) orders —
/// checked against their credit limit before another credit order.
export async function outstandingBalance(uid: string, memberIds?: string[]): Promise<number> {
  const ids = memberIds?.length ? memberIds : [uid];
  const docs = [];
  for (let i = 0; i < ids.length; i += 30) {
    const snap = await db.collection('Orders').where('customerId', 'in', ids.slice(i, i + 30)).get();
    docs.push(...snap.docs);
  }
  return docs.reduce((sum, doc) => {
    const o = doc.data();
    if (o.status === 'cancelled') return sum;
    const net = (o.amountPaid ?? 0) - (o.refundedAmount ?? 0);
    return sum + Math.max(0, (o.total ?? 0) - net);
  }, 0);
}

export interface LoadedCoupon extends Coupon {
  code: string;
  description: string;
}

export function normalizeCouponCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, '');
}

/// Reads and checks a coupon inside a transaction (reads only). Throws a
/// customer-facing error for any reason it can't be used.
export async function readCoupon(
  tx: Transaction,
  code: string,
  uid: string,
): Promise<{ coupon: LoadedCoupon; redemptionCount: number }> {
  const ref = db.collection('Coupons').doc(code);
  const [snap, redemption] = await Promise.all([
    tx.get(ref),
    tx.get(ref.collection('Redemptions').doc(uid)),
  ]);
  const c = snap.data();
  const now = Date.now();
  if (!snap.exists || !c || c.active !== true) {
    throw new HttpsError('failed-precondition', `The code "${code}" isn't valid.`);
  }
  const from = (c.validFrom as Timestamp | undefined)?.toMillis();
  const to = (c.validTo as Timestamp | undefined)?.toMillis();
  if ((from && now < from) || (to && now > to)) {
    throw new HttpsError('failed-precondition', `The code "${code}" has expired.`);
  }
  if (c.usageLimit > 0 && (c.usedCount ?? 0) >= c.usageLimit) {
    throw new HttpsError('failed-precondition', `The code "${code}" has been fully used.`);
  }
  const redemptionCount = (redemption.data()?.count as number | undefined) ?? 0;
  if (c.perCustomerLimit > 0 && redemptionCount >= c.perCustomerLimit) {
    throw new HttpsError('failed-precondition', `You've already used the code "${code}".`);
  }
  return {
    coupon: {
      code,
      description: String(c.description ?? ''),
      type: c.type === 'fixed' ? 'fixed' : 'percent',
      value: Number(c.value) || 0,
      minSubtotal: Number(c.minSubtotal) || 0,
      maxDiscount: Number(c.maxDiscount) || 0,
    },
    redemptionCount,
  };
}

/// Records a use of the coupon (write half of readCoupon).
export function redeemCoupon(
  tx: Transaction,
  code: string,
  uid: string,
  redemptionCount: number,
  orderId: string,
): void {
  const ref = db.collection('Coupons').doc(code);
  tx.update(ref, { usedCount: FieldValue.increment(1) });
  tx.set(ref.collection('Redemptions').doc(uid), {
    count: redemptionCount + 1,
    lastOrderId: orderId,
    updatedAt: new Date(),
  });
}


/// Checkout preview: what the customer's corporate discount and a coupon
/// would take off this subtotal. Coupons are never readable by customers
/// directly (codes would leak), so validation happens here.
export const previewDiscount = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const subtotal = requireNumber(data, 'subtotal', 'Subtotal', 0, 1e10);
  const rawCode = typeof data.couponCode === 'string' ? data.couponCode : '';
  const code = normalizeCouponCode(rawCode);
  const account = await loadCustomerAccount(caller.uid);
  let coupon: LoadedCoupon | null = null;
  let message = '';
  if (code) {
    try {
      coupon = await db.runTransaction(async (tx) => (await readCoupon(tx, code, caller.uid)).coupon);
      if (subtotal < coupon.minSubtotal) {
        message = `Spend at least KES ${coupon.minSubtotal} to use this code.`;
      }
    } catch (error) {
      if (error instanceof HttpsError) {
        return { valid: false, message: error.message, corporate: computeDiscount(subtotal, { corporatePercent: account.discountPercent }).corporate, coupon: 0 };
      }
      throw error;
    }
  }
  const d = computeDiscount(subtotal, {
    corporatePercent: account.discountPercent,
    coupon,
  });
  return {
    valid: !code || (coupon !== null && !message),
    message: message || (coupon?.description ?? ''),
    corporate: d.corporate,
    coupon: d.coupon,
    discountPercent: account.discountPercent,
    creditEnabled: account.creditEnabled,
    paymentTermsDays: account.paymentTermsDays,
  };
});

