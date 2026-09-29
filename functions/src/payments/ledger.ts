import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import { db } from '../core/app';
import { paymentStatusFor } from '../orders/pricing';

export type PaymentState = 'pending' | 'succeeded' | 'failed' | 'cancelled';

export const paymentRef = (id: string) => db.collection('Payments').doc(id);

/// Marks a payment succeeded and credits its order — in one transaction,
/// idempotently. Providers retry webhooks and customers double-tap "check
/// status", so this is safe to call any number of times: only the first
/// pending → succeeded transition ever adds to the order's amountPaid.
export async function markPaymentSucceeded(
  paymentId: string,
  details: { receipt?: string; message?: string } = {},
): Promise<boolean> {
  const applied = await db.runTransaction(async (tx) => {
    const pRef = paymentRef(paymentId);
    const pSnap = await tx.get(pRef);
    const p = pSnap.data();
    if (!pSnap.exists || !p) return false;
    if (p.status === 'succeeded') return false;

    const oRef = db.collection('Orders').doc(p.orderId as string);
    const oSnap = await tx.get(oRef);
    const o = oSnap.data();
    if (!oSnap.exists || !o) return false;

    const amountPaid = ((o.amountPaid as number | undefined) ?? 0) + (p.amount as number);
    tx.update(pRef, {
      status: 'succeeded',
      ...(details.receipt ? { receipt: details.receipt } : {}),
      ...(details.message ? { message: details.message } : {}),
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(oRef, {
      amountPaid,
      paymentStatus: paymentStatusFor(o.total as number, amountPaid),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (applied) logger.info('[ledger] payment succeeded', { paymentId });
  return applied;
}

/// Only ever moves a still-pending payment to a terminal failure state — a
/// late "failed" callback can never undo a payment that already succeeded.
export async function markPaymentClosed(
  paymentId: string,
  state: 'failed' | 'cancelled',
  message?: string,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = paymentRef(paymentId);
    const snap = await tx.get(ref);
    if (snap.data()?.status !== 'pending') return;
    tx.update(ref, {
      status: state,
      ...(message ? { message: message.slice(0, 300) } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  logger.info('[ledger] payment closed', { paymentId, state });
}
