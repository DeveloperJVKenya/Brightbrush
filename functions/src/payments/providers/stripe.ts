import { createHmac, timingSafeEqual } from 'node:crypto';

import { orderPageUrl } from '../../settings/business_settings';
import { callProvider } from '../http_util';
import { PaymentProvider } from './types';

const API = 'https://api.stripe.com/v1';

function auth(secretKey: string) {
  return { Authorization: `Bearer ${secretKey}` };
}

export const stripeProvider: PaymentProvider = {
  async start(ctx) {
    const amount = Math.round(ctx.amountKes);
    const session = await callProvider<{ id: string; url: string }>(
      `${API}/checkout/sessions`,
      {
        headers: {
          ...auth(ctx.config.values.secretKey),
          // Re-trying the same payment never creates a second session.
          'Idempotency-Key': `bb-${ctx.paymentId}`,
        },
        form: {
          mode: 'payment',
          // KES is a two-decimal currency in Stripe: amounts are in cents.
          'line_items[0][price_data][currency]': 'kes',
          'line_items[0][price_data][unit_amount]': String(amount * 100),
          'line_items[0][price_data][product_data][name]': `${ctx.settings.businessName} order ${ctx.orderNumber}`,
          'line_items[0][quantity]': '1',
          client_reference_id: ctx.paymentId,
          'metadata[paymentId]': ctx.paymentId,
          'metadata[orderId]': ctx.orderId,
          'payment_intent_data[metadata][paymentId]': ctx.paymentId,
          ...(ctx.customerEmail ? { customer_email: ctx.customerEmail } : {}),
          success_url: orderPageUrl(ctx.settings, ctx.orderId, 'success'),
          cancel_url: orderPageUrl(ctx.settings, ctx.orderId, 'cancelled'),
          expires_at: String(Math.floor(Date.now() / 1000) + 60 * 60),
        },
      },
    );
    return {
      action: 'redirect',
      providerRef: session.id,
      redirectUrl: session.url,
      message: 'Continue to the secure Stripe checkout page to pay.',
      chargedAmount: amount,
      chargedCurrency: 'KES',
    };
  },

  async verify(config, payment) {
    const session = await callProvider<Record<string, any>>(
      `${API}/checkout/sessions/${encodeURIComponent(payment.providerRef)}`,
      { headers: auth(config.values.secretKey) },
    );
    if (session.payment_status === 'paid') {
      return {
        state: 'succeeded',
        receipt: String(session.payment_intent ?? session.id),
      };
    }
    if (session.status === 'expired') {
      return { state: 'cancelled', message: 'The checkout session expired.' };
    }
    return { state: 'pending' };
  },

  async refund(config, payment, amountKes) {
    const intent = payment.receipt;
    if (!intent || !intent.startsWith('pi_')) throw new Error('No Stripe payment intent on record.');
    const res = await callProvider<Record<string, any>>(`${API}/refunds`, {
      headers: { ...auth(config.values.secretKey), 'Idempotency-Key': `bb-refund-${payment.id}-${amountKes}` },
      form: { payment_intent: intent, amount: String(Math.round(amountKes) * 100) },
    });
    return String(res.id);
  },

  async test(config) {
    const balance = await callProvider<Record<string, any>>(`${API}/balance`, {
      headers: auth(config.values.secretKey),
    });
    const live = balance.livemode === true;
    if (live !== (config.mode === 'live')) {
      return `Connected, but these are ${live ? 'LIVE' : 'TEST'} keys while the gateway is set to ${config.mode}. Switch the mode to match.`;
    }
    return `Stripe ${live ? 'live' : 'test'} keys accepted.`;
  },
};

/// Verifies the Stripe-Signature header (t=…,v1=…) against the raw body,
/// rejecting anything older than 5 minutes to block replays.
export function verifyStripeSignature(
  rawBody: Buffer,
  header: string | undefined,
  secret: string,
  toleranceSeconds = 300,
): boolean {
  if (!header || !secret) return false;
  const parts = Object.fromEntries(
    header.split(',').map((p) => {
      const i = p.indexOf('=');
      return [p.substring(0, i).trim(), p.substring(i + 1).trim()];
    }),
  );
  const timestamp = Number(parts.t);
  if (!Number.isFinite(timestamp)) return false;
  if (Math.abs(Date.now() / 1000 - timestamp) > toleranceSeconds) return false;
  const expected = createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody.toString('utf8')}`)
    .digest('hex');
  const signatures = header
    .split(',')
    .filter((p) => p.trim().startsWith('v1='))
    .map((p) => p.trim().substring(3));
  return signatures.some((sig) => {
    const a = Buffer.from(sig, 'hex');
    const b = Buffer.from(expected, 'hex');
    return a.length === b.length && timingSafeEqual(a, b);
  });
}
