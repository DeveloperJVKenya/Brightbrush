import { randomBytes } from 'node:crypto';

import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { isStaff, loadCaller, requireRole } from '../core/authz';
import {
  asObject,
  optionalString,
  requireEnum,
  requireNumber,
  requireString,
} from '../core/validate';
import { amountDue } from '../orders/pricing';
import { loadBusinessSettings } from '../settings/business_settings';
import { GATEWAY_IDS, GatewayId, loadGateway } from './gateway_config';
import { ProviderError } from './http_util';
import { markPaymentClosed, markPaymentSucceeded, paymentRef } from './ledger';
import { PROVIDERS } from './providers';
import { rateLimit } from '../platform/platform';
import { normalizeKenyanPhone } from './providers/mpesa';

/// A second M-Pesa prompt while the first is still open confuses customers
/// and can double-charge — block new attempts on the same order briefly.
const PENDING_COOLDOWN_MS = 90 * 1000;

function friendlyProviderError(error: unknown): string {
  const message =
    error instanceof ProviderError || error instanceof Error
      ? error.message
      : String(error);
  return `The payment provider rejected the request: ${message}`.slice(0, 300);
}

/// Starts a payment for the caller's own order on one of the enabled
/// gateways. The amount is always computed here from the order (deposit or
/// outstanding balance) — the client only picks which of the two.
export const initiatePayment = onCall(async (request) => {
  const caller = await loadCaller(request);
  await rateLimit(`initiatePayment_${caller.uid}`, 10, 600);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const gatewayId = requireEnum<GatewayId>(data, 'gateway', GATEWAY_IDS);
  const choice = requireEnum(data, 'amountChoice', ['deposit', 'balance'], 'balance');

  const [orderSnap, gateway, settings] = await Promise.all([
    db.collection('Orders').doc(orderId).get(),
    loadGateway(gatewayId),
    loadBusinessSettings(),
  ]);
  const order = orderSnap.data();
  if (!orderSnap.exists || !order || order.customerId !== caller.uid) {
    throw new HttpsError('not-found', 'Order not found.');
  }
  if (order.status === 'cancelled') {
    throw new HttpsError('failed-precondition', 'This order was cancelled.');
  }
  if (!gateway.enabled) {
    throw new HttpsError(
      'failed-precondition',
      'That payment method is not available right now.',
    );
  }

  const amount = amountDue(
    {
      total: order.total as number,
      amountPaid: (order.amountPaid as number | undefined) ?? 0,
      depositAmount: (order.depositAmount as number | undefined) ?? (order.total as number),
    },
    choice,
  );
  if (amount <= 0) {
    throw new HttpsError('failed-precondition', 'This order is already fully paid.');
  }

  let phone: string | undefined;
  if (gatewayId === 'mpesa') {
    const raw = requireString(data, 'phone', 'Phone number', 9, 20);
    phone = normalizeKenyanPhone(raw) ?? undefined;
    if (!phone) {
      throw new HttpsError(
        'invalid-argument',
        'Enter a valid Safaricom number, e.g. 0712 345 678.',
      );
    }
  }

  const recentPending = await db
    .collection('Payments')
    .where('orderId', '==', orderId)
    .where('status', '==', 'pending')
    .get();
  const blocking = recentPending.docs.find(
    (d) =>
      d.data().gateway === 'mpesa' &&
      gatewayId === 'mpesa' &&
      Date.now() - ((d.data().createdAt as Timestamp | undefined)?.toMillis() ?? 0) <
        PENDING_COOLDOWN_MS,
  );
  if (blocking) {
    throw new HttpsError(
      'resource-exhausted',
      'An M-Pesa prompt was just sent for this order. Complete it on your phone or wait a minute before retrying.',
    );
  }

  const pRef = db.collection('Payments').doc();
  const callbackToken = randomBytes(24).toString('hex');
  await pRef.set({
    orderId,
    orderNumber: order.orderNumber ?? orderId,
    customerId: caller.uid,
    gateway: gatewayId,
    mode: gateway.mode,
    amount,
    currency: 'KES',
    amountChoice: choice,
    status: 'pending',
    ...(phone ? { phone } : {}),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  // Kept out of the customer-readable Payments doc.
  await db.collection('PaymentTokens').doc(pRef.id).set({ callbackToken });

  try {
    const result = await PROVIDERS[gatewayId].start({
      paymentId: pRef.id,
      orderId,
      orderNumber: (order.orderNumber as string | undefined) ?? orderId,
      amountKes: amount,
      customerEmail: caller.email ?? (order.customerEmail as string) ?? '',
      customerName: order.contactName as string,
      phone,
      callbackToken,
      settings,
      config: gateway,
    });
    await pRef.update({
      providerRef: result.providerRef,
      chargedAmount: result.chargedAmount,
      chargedCurrency: result.chargedCurrency,
      ...(result.redirectUrl ? { redirectUrl: result.redirectUrl } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    logger.info('[payments] started', {
      paymentId: pRef.id,
      orderId,
      gateway: gatewayId,
      amount,
    });
    return {
      paymentId: pRef.id,
      action: result.action,
      redirectUrl: result.redirectUrl ?? null,
      message: result.message,
      amount,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      await markPaymentClosed(pRef.id, 'failed', error.message);
      throw error;
    }
    logger.error('[payments] provider start failed', {
      paymentId: pRef.id,
      gateway: gatewayId,
      error: error instanceof ProviderError ? error.body : String(error),
    });
    const message = friendlyProviderError(error);
    await markPaymentClosed(pRef.id, 'failed', message);
    throw new HttpsError('unavailable', message);
  }
});

/// Re-checks a pending payment directly with the provider — the fallback
/// when a callback is lost or the customer closed the checkout tab early.
export const refreshPaymentStatus = onCall(async (request) => {
  const caller = await loadCaller(request);
  await rateLimit(`refreshPayment_${caller.uid}`, 30, 600);
  const data = asObject(request.data);
  const paymentId = requireString(data, 'paymentId', 'Payment', 1, 100);
  const snap = await paymentRef(paymentId).get();
  const p = snap.data();
  if (
    !snap.exists ||
    !p ||
    (p.customerId !== caller.uid && !isStaff(caller.role, ['systemManager', 'admin']))
  ) {
    throw new HttpsError('not-found', 'Payment not found.');
  }
  if (p.status !== 'pending' || !p.providerRef || p.gateway === 'manual') {
    return { status: p.status };
  }
  const gateway = await loadGateway(p.gateway as GatewayId);
  const result = await PROVIDERS[p.gateway as GatewayId].verify(gateway, {
    id: paymentId,
    providerRef: p.providerRef as string,
    amount: p.amount as number,
  });
  if (result.state === 'succeeded') {
    await markPaymentSucceeded(paymentId, {
      receipt: result.receipt,
      providerTxnId: result.providerTxnId,
    });
  } else if (result.state === 'failed' || result.state === 'cancelled') {
    await markPaymentClosed(paymentId, result.state, result.message);
  }
  return { status: result.state, message: result.message ?? null };
});

/// Staff record an offline payment (cash, bank transfer, a Paybill payment
/// made outside the app) — it goes through the same ledger so the order's
/// amountPaid/paymentStatus stay consistent with gateway payments.
export const recordManualPayment = onCall(async (request) => {
  const caller = await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const amount = Math.round(requireNumber(data, 'amount', 'Amount', 1, 1e9));
  const method = requireEnum(data, 'method', [
    'cash',
    'bankTransfer',
    'mpesaManual',
    'cheque',
    'other',
  ]);
  const reference = optionalString(data, 'reference', 'Reference', 80);
  const note = optionalString(data, 'note', 'Note', 300);

  const orderSnap = await db.collection('Orders').doc(orderId).get();
  const order = orderSnap.data();
  if (!orderSnap.exists || !order) {
    throw new HttpsError('not-found', 'Order not found.');
  }
  const balance = (order.total as number) - ((order.amountPaid as number | undefined) ?? 0);
  if (amount > balance) {
    throw new HttpsError(
      'invalid-argument',
      `That's more than the outstanding balance (KES ${balance}).`,
    );
  }

  const pRef = db.collection('Payments').doc();
  await pRef.set({
    orderId,
    orderNumber: order.orderNumber ?? orderId,
    customerId: order.customerId,
    gateway: 'manual',
    method,
    mode: 'live',
    amount,
    currency: 'KES',
    status: 'pending',
    ...(reference ? { receipt: reference } : {}),
    ...(note ? { message: note } : {}),
    recordedBy: caller.uid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await markPaymentSucceeded(pRef.id, { actor: caller.uid });
  logger.info('[payments] manual payment recorded', {
    paymentId: pRef.id,
    orderId,
    amount,
    by: caller.uid,
  });
  return { paymentId: pRef.id };
});
