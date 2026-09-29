import { timingSafeEqual } from 'node:crypto';

import { functionsBaseUrl } from '../../core/app';
import { callProvider } from '../http_util';
import { PaymentProvider } from './types';

const API = 'https://api.flutterwave.com/v3';

function auth(secretKey: string) {
  return { Authorization: `Bearer ${secretKey}` };
}

export const flutterwaveProvider: PaymentProvider = {
  async start(ctx) {
    const amount = Math.round(ctx.amountKes);
    const res = await callProvider<Record<string, any>>(`${API}/payments`, {
      headers: auth(ctx.config.values.secretKey),
      json: {
        // tx_ref is the payment id: that's how the return redirect and the
        // webhook find the payment again.
        tx_ref: ctx.paymentId,
        amount,
        currency: 'KES',
        redirect_url: `${functionsBaseUrl()}/flutterwaveReturn`,
        customer: {
          email: ctx.customerEmail || 'no-reply@brightbrush.app',
          name: ctx.customerName,
        },
        customizations: {
          title: ctx.settings.businessName,
          description: `Order ${ctx.orderNumber}`,
        },
        meta: { paymentId: ctx.paymentId, orderId: ctx.orderId },
      },
    });
    const link = res.data?.link as string | undefined;
    if (res.status !== 'success' || !link) {
      throw new Error(res.message ?? 'Flutterwave did not return a payment link.');
    }
    return {
      action: 'redirect',
      providerRef: ctx.paymentId,
      redirectUrl: link,
      message: 'Continue to Flutterwave to pay by card, M-Pesa or bank.',
      chargedAmount: amount,
      chargedCurrency: 'KES',
    };
  },

  async verify(config, payment) {
    try {
      const res = await callProvider<Record<string, any>>(
        `${API}/transactions/verify_by_reference?tx_ref=${encodeURIComponent(payment.id)}`,
        { headers: auth(config.values.secretKey) },
      );
      const d = res.data ?? {};
      if (d.status === 'successful') {
        // Never trust a "successful" flag alone: amount and currency must
        // match what this payment asked for.
        if (d.currency !== 'KES' || Number(d.amount) < payment.amount) {
          return {
            state: 'failed',
            message: 'Amount paid did not match the amount due. Contact support.',
          };
        }
        return {
          state: 'succeeded',
          receipt: String(d.flw_ref ?? d.id),
          providerTxnId: String(d.id),
        };
      }
      if (d.status === 'failed') return { state: 'failed', message: d.processor_response };
      return { state: 'pending' };
    } catch (error: any) {
      // 404-ish "No transaction was found" just means the customer hasn't
      // finished yet.
      if (String(error?.message ?? '').toLowerCase().includes('no transaction')) {
        return { state: 'pending' };
      }
      throw error;
    }
  },

  async refund(config, payment, amountKes) {
    if (!payment.providerTxnId) throw new Error('No Flutterwave transaction id on record.');
    const res = await callProvider<Record<string, any>>(
      `${API}/transactions/${encodeURIComponent(payment.providerTxnId)}/refund`,
      { headers: auth(config.values.secretKey), json: { amount: Math.round(amountKes) } },
    );
    return String(res.data?.id ?? res.data?.flw_ref ?? 'refund');
  },

  async test(config) {
    await callProvider(`${API}/banks/KE`, { headers: auth(config.values.secretKey) });
    return `Flutterwave keys accepted (${config.values.secretKey.includes('TEST') ? 'test' : 'live'} key).`;
  },
};

export function verifyFlutterwaveHash(
  header: string | undefined,
  secretHash: string,
): boolean {
  if (!header || !secretHash) return false;
  const a = Buffer.from(header);
  const b = Buffer.from(secretHash);
  return a.length === b.length && timingSafeEqual(a, b);
}
