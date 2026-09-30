import { randomInt } from 'node:crypto';

import { FieldValue, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { loadCaller } from '../core/authz';
import { asObject, requireString } from '../core/validate';
import { notifyUser } from '../notifications/notify';

/// Settings/loyalty (admin-editable).
export interface LoyaltySettings {
  enabled: boolean;
  /// Points earned per KES 100 actually paid on a completed order.
  pointsPerHundred: number;
  /// KES value of one point at checkout.
  pointValue: number;
  /// Points each side gets when a referred customer completes their first order.
  referralBonusPoints: number;
  /// Points can cover at most this % of an order's subtotal.
  maxRedeemPercent: number;
}

export const DEFAULT_LOYALTY: LoyaltySettings = {
  enabled: false,
  pointsPerHundred: 1,
  pointValue: 1,
  referralBonusPoints: 200,
  maxRedeemPercent: 20,
};

export async function loadLoyaltySettings(): Promise<LoyaltySettings> {
  const d = (await db.collection('Settings').doc('loyalty').get()).data() ?? {};
  const num = (v: unknown, f: number, max: number) => (typeof v === 'number' && v >= 0 && v <= max ? v : f);
  return {
    enabled: d.enabled === true,
    pointsPerHundred: num(d.pointsPerHundred, DEFAULT_LOYALTY.pointsPerHundred, 100),
    pointValue: num(d.pointValue, DEFAULT_LOYALTY.pointValue, 1000),
    referralBonusPoints: num(d.referralBonusPoints, DEFAULT_LOYALTY.referralBonusPoints, 1e6),
    maxRedeemPercent: num(d.maxRedeemPercent, DEFAULT_LOYALTY.maxRedeemPercent, 100),
  };
}

/// Pure: points earned for an amount paid.
export function pointsEarned(netPaid: number, s: LoyaltySettings): number {
  return Math.max(0, Math.floor((netPaid / 100) * s.pointsPerHundred));
}

/// Pure: how many points may be redeemed on an order (and their KES value),
/// capped by the balance and by maxRedeemPercent of the subtotal.
export function redeemable(
  requested: number,
  balance: number,
  subtotalAfterDiscounts: number,
  s: LoyaltySettings,
): { points: number; value: number } {
  if (!s.enabled || s.pointValue <= 0) return { points: 0, value: 0 };
  const capValue = Math.floor((subtotalAfterDiscounts * s.maxRedeemPercent) / 100);
  const maxPoints = Math.floor(capValue / s.pointValue);
  const points = Math.max(0, Math.min(Math.floor(requested), balance, maxPoints));
  return { points, value: Math.round(points * s.pointValue) };
}

const accountRef = (uid: string) => db.collection('LoyaltyAccounts').doc(uid);

/// Adds (or removes, negative) points with a ledger entry, inside a transaction.
export function applyPoints(
  tx: Transaction,
  uid: string,
  currentBalance: number,
  change: number,
  reason: string,
  orderId?: string,
): void {
  tx.set(accountRef(uid), {
    points: Math.max(0, currentBalance + change),
    ...(change > 0 ? { lifetimePoints: FieldValue.increment(change) } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  tx.create(db.collection('LoyaltyLedger').doc(), {
    uid,
    change,
    reason,
    ...(orderId ? { orderId } : {}),
    at: FieldValue.serverTimestamp(),
  });
}

export async function readBalance(tx: Transaction, uid: string): Promise<number> {
  return ((await tx.get(accountRef(uid))).data()?.points as number | undefined) ?? 0;
}

/// Called when an order completes: earn points, and pay out the referral
/// bonus if this is the referred customer's first completed order.
export async function onOrderCompleted(orderId: string, order: Record<string, any>): Promise<void> {
  const s = await loadLoyaltySettings();
  if (!s.enabled) return;
  const orderRef = db.collection('Orders').doc(orderId);
  const referralRef = db.collection('Referrals').doc(order.customerId);
  const result = await db.runTransaction(async (tx) => {
    const [fresh, referral] = await Promise.all([tx.get(orderRef), tx.get(referralRef)]);
    const o = fresh.data() ?? {};
    if (o.loyaltyAwarded === true) return null;
    const earned = pointsEarned((o.amountPaid ?? 0) - (o.refundedAmount ?? 0), s);
    const r = referral.data();
    const payReferral = !!r && r.status === 'pending' && s.referralBonusPoints > 0;
    const customerBalance = await readBalance(tx, order.customerId);
    const referrerBalance = payReferral ? await readBalance(tx, r!.referrerUid) : 0;
    const total = earned + (payReferral ? s.referralBonusPoints : 0);
    if (total > 0) applyPoints(tx, order.customerId, customerBalance, total, payReferral ? 'order+referral' : 'order', orderId);
    if (payReferral) {
      applyPoints(tx, r!.referrerUid, referrerBalance, s.referralBonusPoints, 'referral', orderId);
      tx.update(referralRef, { status: 'rewarded', rewardedAt: FieldValue.serverTimestamp(), orderId });
    }
    tx.update(orderRef, { loyaltyAwarded: true, pointsEarned: total, lastUpdatedBy: 'system:loyalty' });
    return { earned: total, referrer: payReferral ? r!.referrerUid as string : null };
  });
  if (!result) return;
  if (result.earned > 0) {
    await notifyUser(order.customerId, {
      type: 'loyalty.earned',
      title: `You earned ${result.earned} points`,
      body: `Worth KES ${Math.round(result.earned * s.pointValue)} off a future order.`,
      link: '/customer/profile',
    });
  }
  if (result.referrer) {
    await notifyUser(result.referrer, {
      type: 'loyalty.referral',
      title: `Referral bonus: ${s.referralBonusPoints} points`,
      body: 'Someone you referred just completed their first order. Thank you!',
      link: '/customer/profile',
    });
  }
  logger.info('[loyalty] awarded', { orderId, ...result });
}

/// Gives back points spent on an order that gets cancelled.
export async function restoreRedeemedPoints(orderId: string, order: Record<string, any>): Promise<void> {
  if (!(order.pointsRedeemed > 0) || order.pointsRestored === true) return;
  const orderRef = db.collection('Orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const o = (await tx.get(orderRef)).data() ?? {};
    if (o.pointsRestored === true) return;
    const balance = await readBalance(tx, order.customerId);
    applyPoints(tx, order.customerId, balance, o.pointsRedeemed, 'orderCancelled', orderId);
    tx.update(orderRef, { pointsRestored: true, lastUpdatedBy: 'system:loyalty' });
  });
}

function makeCode(name: string): string {
  const letters = name.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 4).padEnd(4, 'X');
  return `${letters}${randomInt(1000, 9999)}`;
}

/// The caller's own referral code (created on first request).
export const getMyReferralCode = onCall(async (request) => {
  const caller = await loadCaller(request);
  const existing = await db.collection('ReferralCodes').where('uid', '==', caller.uid).limit(1).get();
  if (!existing.empty) return { code: existing.docs[0].id };
  const name = String((await db.collection('Users').doc(caller.uid).get()).data()?.displayName ?? 'BRIGHT');
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = makeCode(name);
    try {
      await db.collection('ReferralCodes').doc(code).create({ uid: caller.uid, createdAt: FieldValue.serverTimestamp() });
      return { code };
    } catch {
      // Collision — try another.
    }
  }
  throw new HttpsError('unavailable', 'Couldn\'t create a code. Please try again.');
});

/// New customers enter a friend's code before their first order.
export const claimReferral = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const code = requireString(data, 'code', 'Referral code', 4, 20).toUpperCase().replace(/\s/g, '');
  const [codeSnap, orders, existing] = await Promise.all([
    db.collection('ReferralCodes').doc(code).get(),
    db.collection('Orders').where('customerId', '==', caller.uid).limit(1).get(),
    db.collection('Referrals').doc(caller.uid).get(),
  ]);
  const referrerUid = codeSnap.data()?.uid as string | undefined;
  if (!referrerUid) throw new HttpsError('not-found', 'That referral code doesn\'t exist.');
  if (referrerUid === caller.uid) throw new HttpsError('failed-precondition', 'You can\'t use your own code.');
  if (existing.exists) throw new HttpsError('failed-precondition', 'You\'ve already used a referral code.');
  if (!orders.empty) throw new HttpsError('failed-precondition', 'Referral codes are for new customers before their first order.');
  await db.collection('Referrals').doc(caller.uid).create({
    referrerUid,
    code,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});
