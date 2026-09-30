import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { requireRole } from '../core/authz';
import { asObject, requireNumber, requireString } from '../core/validate';
import { GatewayId, loadGateway } from './gateway_config';
import { PROVIDERS } from './providers';

export interface RefundSource {
  id: string;
  available: number;
  createdAt: number;
}

/// Splits a refund across the order's payments, newest first, never taking
/// more from a payment than is still refundable on it. Pure — unit tested.
export function allocateRefund(
  sources: RefundSource[],
  amount: number,
): Array<{ id: string; amount: number }> {
  let remaining = Math.round(amount);
  const out: Array<{ id: string; amount: number }> = [];
  for (const s of [...sources].sort((a, b) => b.createdAt - a.createdAt)) {
    if (remaining <= 0) break;
    const take = Math.min(remaining, Math.max(0, Math.round(s.available)));
    if (take > 0) {
      out.push({ id: s.id, amount: take });
      remaining -= take;
    }
  }
  if (remaining > 0) {
    throw new HttpsError('failed-precondition', 'That is more than was paid on this order.');
  }
  return out;
}

/// Staff refund (optionally cancelling the order with a cancellation fee
/// kept back). Card/PayPal/Flutterwave payments are refunded automatically
/// through the provider; M-Pesa, cash and bank payments are recorded as
/// manual refunds for staff to pay out. A numbered credit note is issued.
export const issueRefund = onCall(async (request) => {
  const caller = await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const reason = requireString(data, 'reason', 'Reason', 3, 500);
  const cancelOrder = data.cancelOrder === true;
  const cancellationFee = cancelOrder
    ? Math.round(requireNumber(data, 'cancellationFee', 'Cancellation fee', 0, 1e9))
    : 0;

  const orderRef = db.collection('Orders').doc(orderId);
  const [orderSnap, paymentsSnap] = await Promise.all([
    orderRef.get(),
    db.collection('Payments').where('orderId', '==', orderId).where('status', '==', 'succeeded').get(),
  ]);
  const order = orderSnap.data();
  if (!order) throw new HttpsError('not-found', 'Order not found.');
  if (order.status === 'completed' && cancelOrder) {
    throw new HttpsError('failed-precondition', 'Completed orders can be refunded but not cancelled.');
  }
  const paid = (order.amountPaid ?? 0) - (order.refundedAmount ?? 0);
  const amount = cancelOrder
    ? Math.max(0, paid - cancellationFee)
    : Math.round(requireNumber(data, 'amount', 'Refund amount', 1, 1e9));
  if (amount > paid) {
    throw new HttpsError('failed-precondition', `Only KES ${paid} can be refunded on this order.`);
  }

  const sources = paymentsSnap.docs.map((d) => ({
    id: d.id,
    available: (d.data().amount ?? 0) - (d.data().refundedAmount ?? 0),
    createdAt: (d.data().createdAt as Timestamp | undefined)?.toMillis() ?? 0,
  }));
  const allocations = amount > 0 ? allocateRefund(sources, amount) : [];

  const results: Array<Record<string, unknown>> = [];
  let refunded = 0;
  for (const alloc of allocations) {
    const pDoc = paymentsSnap.docs.find((d) => d.id === alloc.id)!;
    const p = pDoc.data();
    const provider = p.gateway !== 'manual' ? PROVIDERS[p.gateway as GatewayId] : undefined;
    let status = 'manual';
    let providerRefundId: string | undefined;
    let message = p.gateway === 'mpesa'
      ? 'Send this amount back to the customer via M-Pesa (B2C/reversal), then keep the reference.'
      : 'Pay this amount back to the customer (cash/bank) and keep the reference.';
    if (provider?.refund) {
      try {
        const config = await loadGateway(p.gateway as GatewayId);
        providerRefundId = await provider.refund(config, {
          id: pDoc.id,
          amount: p.amount,
          receipt: p.receipt,
          providerTxnId: p.providerTxnId,
          providerRef: p.providerRef,
          chargedAmount: p.chargedAmount,
          chargedCurrency: p.chargedCurrency,
        }, alloc.amount);
        status = 'refunded';
        message = 'Refunded automatically through the payment provider.';
      } catch (error) {
        status = 'failed';
        message = `Automatic refund failed: ${error instanceof Error ? error.message : String(error)}. Refund manually.`;
        logger.error('[issueRefund] provider refund failed', { orderId, paymentId: pDoc.id, error: String(error) });
      }
    }
    if (status !== 'failed') {
      refunded += alloc.amount;
      await pDoc.ref.update({
        refundedAmount: FieldValue.increment(alloc.amount),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    results.push({
      paymentId: pDoc.id,
      gateway: p.gateway,
      amount: alloc.amount,
      status,
      message: message.slice(0, 300),
      ...(providerRefundId ? { providerRefundId } : {}),
    });
  }

  const refundRef = db.collection('Refunds').doc();
  const creditNoteNumber = await db.runTransaction(async (tx) => {
    const counterRef = db.collection('Counters').doc('creditNotes');
    const [counter, fresh] = await Promise.all([tx.get(counterRef), tx.get(orderRef)]);
    const seq = ((counter.data()?.value as number | undefined) ?? 0) + 1;
    const number = `CN-${String(seq).padStart(6, '0')}`;
    const o = fresh.data() ?? {};
    const refundedTotal = (o.refundedAmount ?? 0) + refunded;
    tx.set(counterRef, { value: seq, updatedAt: FieldValue.serverTimestamp() });
    tx.create(refundRef, {
      orderId,
      orderNumber: o.orderNumber ?? orderId,
      invoiceNumber: o.invoiceNumber ?? null,
      customerId: o.customerId,
      amount: refunded,
      requestedAmount: amount,
      cancellationFee,
      cancelled: cancelOrder,
      reason,
      creditNoteNumber: number,
      allocations: results,
      createdBy: caller.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(orderRef, {
      lastUpdatedBy: caller.uid,
      refundedAmount: refundedTotal,
      ...(refundedTotal > 0 && refundedTotal >= (o.amountPaid ?? 0)
        ? { paymentStatus: 'refunded' }
        : refundedTotal > 0
          ? { paymentStatus: 'partiallyRefunded' }
          : {}),
      ...(cancelOrder ? { status: 'cancelled', cancellationFee, cancelReason: reason } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return number;
  });

  logger.info('[issueRefund]', { orderId, refunded, creditNoteNumber, by: caller.uid });
  return { refundId: refundRef.id, creditNoteNumber, refunded, allocations: results };
});
