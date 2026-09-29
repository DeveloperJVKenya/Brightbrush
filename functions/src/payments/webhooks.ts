import { timingSafeEqual } from 'node:crypto';

import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onRequest } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import {
  loadBusinessSettings,
  orderPageUrl,
} from '../settings/business_settings';
import { loadGateway } from './gateway_config';
import { markPaymentClosed, markPaymentSucceeded, paymentRef } from './ledger';
import { verifyFlutterwaveHash, flutterwaveProvider } from './providers/flutterwave';
import { mapResultCode } from './providers/mpesa';
import { paypalProvider } from './providers/paypal';
import { verifyStripeSignature } from './providers/stripe';

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

/// Daraja STK Push result callback. URL shape:
///   /mpesaCallback/{paymentId}/{callbackToken}
/// Safaricom doesn't sign callbacks, so the per-payment random token (only
/// ever sent to Safaricom inside the CallBackURL) proves authenticity, and
/// the CheckoutRequestID must also match the one we stored.
export const mpesaCallback = onRequest(async (req, res) => {
  // Always ACK so Safaricom doesn't retry forever; problems are logged.
  const ack = () => res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
  try {
    const [paymentId, token] = req.path.split('/').filter(Boolean).slice(-2);
    if (!paymentId || !token) {
      logger.warn('[mpesaCallback] malformed path', { path: req.path });
      ack();
      return;
    }
    const tokenSnap = await db.collection('PaymentTokens').doc(paymentId).get();
    const expected = tokenSnap.data()?.callbackToken as string | undefined;
    if (!expected || !safeEqual(expected, token)) {
      logger.warn('[mpesaCallback] token mismatch', { paymentId });
      ack();
      return;
    }
    const cb = req.body?.Body?.stkCallback;
    const pSnap = await paymentRef(paymentId).get();
    const p = pSnap.data();
    if (!cb || !p || p.providerRef !== cb.CheckoutRequestID) {
      logger.warn('[mpesaCallback] unknown payment/checkout id', { paymentId });
      ack();
      return;
    }
    const outcome = mapResultCode(String(cb.ResultCode), cb.ResultDesc);
    const items: Array<{ Name: string; Value?: unknown }> =
      cb.CallbackMetadata?.Item ?? [];
    const meta = Object.fromEntries(items.map((i) => [i.Name, i.Value]));
    if (outcome.state === 'succeeded') {
      const paid = Number(meta.Amount ?? 0);
      if (paid < (p.amount as number)) {
        logger.error('[mpesaCallback] amount mismatch', { paymentId, paid, expected: p.amount });
        await markPaymentClosed(paymentId, 'failed', `Received KES ${paid}, expected KES ${p.amount}. Contact support.`);
      } else {
        await markPaymentSucceeded(paymentId, {
          receipt: String(meta.MpesaReceiptNumber ?? ''),
        });
      }
    } else if (outcome.state === 'failed' || outcome.state === 'cancelled') {
      await markPaymentClosed(paymentId, outcome.state, outcome.message);
    }
    ack();
  } catch (error) {
    logger.error('[mpesaCallback] failed', { error: String(error) });
    ack();
  }
});

/// Stripe webhook — configure in Stripe → Developers → Webhooks for
/// checkout.session.completed, checkout.session.async_payment_succeeded,
/// checkout.session.async_payment_failed and checkout.session.expired.
export const stripeWebhook = onRequest(async (req, res) => {
  const gateway = await loadGateway('stripe');
  const ok = verifyStripeSignature(
    req.rawBody,
    req.header('stripe-signature'),
    gateway.values.webhookSecret ?? '',
  );
  if (!ok) {
    logger.warn('[stripeWebhook] bad signature');
    res.status(400).send('Invalid signature');
    return;
  }
  const event = req.body as { type: string; data: { object: Record<string, any> } };
  const session = event.data?.object ?? {};
  const paymentId = (session.metadata?.paymentId ?? session.client_reference_id) as
    | string
    | undefined;
  if (!paymentId) {
    res.json({ received: true });
    return;
  }
  const pSnap = await paymentRef(paymentId).get();
  if (!pSnap.exists || pSnap.data()?.providerRef !== session.id) {
    logger.warn('[stripeWebhook] unknown session', { paymentId, session: session.id });
    res.json({ received: true });
    return;
  }
  switch (event.type) {
    case 'checkout.session.completed':
    case 'checkout.session.async_payment_succeeded':
      if (session.payment_status === 'paid') {
        await markPaymentSucceeded(paymentId, {
          receipt: String(session.payment_intent ?? session.id),
        });
      }
      break;
    case 'checkout.session.async_payment_failed':
      await markPaymentClosed(paymentId, 'failed', 'The card payment failed.');
      break;
    case 'checkout.session.expired':
      await markPaymentClosed(paymentId, 'cancelled', 'Checkout expired before payment.');
      break;
  }
  res.json({ received: true });
});

/// PayPal sends the buyer back here after approving (or cancelling). We
/// capture server-side, then bounce them to their order page in the app.
export const paypalReturn = onRequest(async (req, res) => {
  const settings = await loadBusinessSettings();
  const paymentId = String(req.query.pid ?? '');
  const pSnap = paymentId ? await paymentRef(paymentId).get() : undefined;
  const p = pSnap?.data();
  if (!p) {
    res.redirect(settings.appBaseUrl);
    return;
  }
  const orderId = p.orderId as string;
  try {
    if (req.query.cancelled) {
      await markPaymentClosed(paymentId, 'cancelled', 'PayPal checkout was cancelled.');
      res.redirect(orderPageUrl(settings, orderId, 'cancelled'));
      return;
    }
    // PayPal appends ?token=<order id>; it must be the order we created.
    if (String(req.query.token ?? '') !== p.providerRef) {
      logger.warn('[paypalReturn] token mismatch', { paymentId });
      res.redirect(orderPageUrl(settings, orderId, 'failed'));
      return;
    }
    const gateway = await loadGateway('paypal');
    const result = await paypalProvider.verify(gateway, {
      id: paymentId,
      providerRef: p.providerRef as string,
      amount: p.amount as number,
    });
    if (result.state === 'succeeded') {
      await markPaymentSucceeded(paymentId, { receipt: result.receipt });
      res.redirect(orderPageUrl(settings, orderId, 'success'));
    } else {
      if (result.state !== 'pending') {
        await markPaymentClosed(paymentId, result.state, result.message);
      }
      res.redirect(orderPageUrl(settings, orderId, 'failed'));
    }
  } catch (error) {
    logger.error('[paypalReturn] capture failed', { paymentId, error: String(error) });
    res.redirect(orderPageUrl(settings, orderId, 'failed'));
  }
});

async function settleFlutterwave(paymentId: string): Promise<string | undefined> {
  const pSnap = await paymentRef(paymentId).get();
  const p = pSnap.data();
  if (!p || p.gateway !== 'flutterwave') return undefined;
  const gateway = await loadGateway('flutterwave');
  // Always re-verify with Flutterwave's API: the redirect query string and
  // webhook body are only hints.
  const result = await flutterwaveProvider.verify(gateway, {
    id: paymentId,
    providerRef: p.providerRef as string,
    amount: p.amount as number,
  });
  if (result.state === 'succeeded') {
    await markPaymentSucceeded(paymentId, { receipt: result.receipt });
  } else if (result.state === 'failed' || result.state === 'cancelled') {
    await markPaymentClosed(paymentId, result.state, result.message);
  }
  await paymentRef(paymentId).update({ lastCheckedAt: FieldValue.serverTimestamp() });
  return p.orderId as string;
}

/// Flutterwave redirect after checkout: ?status=…&tx_ref=<paymentId>&transaction_id=…
export const flutterwaveReturn = onRequest(async (req, res) => {
  const settings = await loadBusinessSettings();
  const paymentId = String(req.query.tx_ref ?? '');
  try {
    const orderId = paymentId ? await settleFlutterwave(paymentId) : undefined;
    if (!orderId) {
      res.redirect(settings.appBaseUrl);
      return;
    }
    const status = (await paymentRef(paymentId).get()).data()?.status;
    res.redirect(
      orderPageUrl(
        settings,
        orderId,
        status === 'succeeded' ? 'success' : status === 'pending' ? 'success' : 'failed',
      ),
    );
  } catch (error) {
    logger.error('[flutterwaveReturn] failed', { paymentId, error: String(error) });
    res.redirect(settings.appBaseUrl);
  }
});

/// Flutterwave webhook — set the URL and Secret hash in Flutterwave →
/// Settings → Webhooks. The verif-hash header must equal that secret.
export const flutterwaveWebhook = onRequest(async (req, res) => {
  const gateway = await loadGateway('flutterwave');
  if (!verifyFlutterwaveHash(req.header('verif-hash'), gateway.values.secretHash ?? '')) {
    logger.warn('[flutterwaveWebhook] bad verif-hash');
    res.status(401).send('Unauthorized');
    return;
  }
  const txRef = String(req.body?.data?.tx_ref ?? req.body?.txRef ?? '');
  if (txRef) {
    try {
      await settleFlutterwave(txRef);
    } catch (error) {
      logger.error('[flutterwaveWebhook] settle failed', { txRef, error: String(error) });
      res.status(500).send('Retry later');
      return;
    }
  }
  res.status(200).send('OK');
});
