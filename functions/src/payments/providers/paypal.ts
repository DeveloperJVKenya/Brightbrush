import { functionsBaseUrl } from '../../core/app';
import { GatewayRuntimeConfig } from '../gateway_config';
import { basicAuth, callProvider } from '../http_util';
import { PaymentProvider } from './types';

function baseUrl(config: GatewayRuntimeConfig): string {
  return config.mode === 'live'
    ? 'https://api-m.paypal.com'
    : 'https://api-m.sandbox.paypal.com';
}

async function accessToken(config: GatewayRuntimeConfig): Promise<string> {
  const res = await callProvider<{ access_token: string }>(
    `${baseUrl(config)}/v1/oauth2/token`,
    {
      headers: {
        Authorization: basicAuth(config.values.clientId, config.values.clientSecret),
      },
      form: { grant_type: 'client_credentials' },
    },
  );
  return res.access_token;
}

/// PayPal can't charge KES — convert with the admin-maintained rate.
export function convertFromKes(amountKes: number, kesPerUnit: number): number {
  return Math.round((amountKes / kesPerUnit) * 100) / 100;
}

export const paypalProvider: PaymentProvider = {
  async start(ctx) {
    const v = ctx.config.values;
    const currency = (v.currency || 'USD').toUpperCase();
    const charged = convertFromKes(ctx.amountKes, Number(v.kesPerUnit));
    const token = await accessToken(ctx.config);
    const order = await callProvider<Record<string, any>>(
      `${baseUrl(ctx.config)}/v2/checkout/orders`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'PayPal-Request-Id': `bb-${ctx.paymentId}`,
        },
        json: {
          intent: 'CAPTURE',
          purchase_units: [
            {
              reference_id: ctx.paymentId,
              custom_id: ctx.paymentId,
              invoice_id: ctx.paymentId,
              description: `${ctx.settings.businessName} order ${ctx.orderNumber}`,
              amount: { currency_code: currency, value: charged.toFixed(2) },
            },
          ],
          payment_source: {
            paypal: {
              experience_context: {
                brand_name: ctx.settings.businessName.substring(0, 127),
                user_action: 'PAY_NOW',
                shipping_preference: 'NO_SHIPPING',
                return_url: `${functionsBaseUrl()}/paypalReturn?pid=${ctx.paymentId}`,
                cancel_url: `${functionsBaseUrl()}/paypalReturn?pid=${ctx.paymentId}&cancelled=1`,
              },
            },
          },
        },
      },
    );
    const link = (order.links as Array<{ rel: string; href: string }>).find(
      (l) => l.rel === 'payer-action' || l.rel === 'approve',
    );
    if (!link) throw new Error('PayPal did not return an approval link.');
    return {
      action: 'redirect',
      providerRef: order.id,
      redirectUrl: link.href,
      message: `Continue to PayPal to pay ${currency} ${charged.toFixed(2)}.`,
      chargedAmount: charged,
      chargedCurrency: currency,
    };
  },

  /// For PayPal "verify" also captures: an approved-but-uncaptured order
  /// hasn't moved any money yet. Capture is idempotent via
  /// PayPal-Request-Id, so calling it twice is safe.
  async verify(config, payment) {
    const token = await accessToken(config);
    const orderUrl = `${baseUrl(config)}/v2/checkout/orders/${encodeURIComponent(payment.providerRef)}`;
    const current = await callProvider<Record<string, any>>(orderUrl, {
      headers: { Authorization: `Bearer ${token}` },
    });
    let status: string = current.status;
    let captureId: string | undefined;
    if (status === 'APPROVED') {
      const captured = await callProvider<Record<string, any>>(
        `${orderUrl}/capture`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
            'PayPal-Request-Id': `bb-capture-${payment.id}`,
          },
        },
      );
      status = captured.status;
      captureId = captured.purchase_units?.[0]?.payments?.captures?.[0]?.id;
    } else if (status === 'COMPLETED') {
      captureId = current.purchase_units?.[0]?.payments?.captures?.[0]?.id;
    }
    if (status === 'COMPLETED') {
      return { state: 'succeeded', receipt: captureId ?? payment.providerRef };
    }
    if (status === 'VOIDED') return { state: 'cancelled' };
    return { state: 'pending' };
  },

  async test(config) {
    await accessToken(config);
    return `PayPal ${config.mode} credentials accepted.`;
  },
};
