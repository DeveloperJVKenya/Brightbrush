import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../core/app';

export type GatewayId = 'mpesa' | 'stripe' | 'paypal' | 'flutterwave';
export type GatewayMode = 'sandbox' | 'live';

export const GATEWAY_IDS: readonly GatewayId[] = [
  'mpesa',
  'stripe',
  'paypal',
  'flutterwave',
];

export interface FieldSpec {
  key: string;
  label: string;
  /// Secret fields are never returned to any client once saved — the admin
  /// screen only sees "set, ending in …1234".
  secret: boolean;
  required: boolean;
  help: string;
  options?: string[];
  defaultValue?: string;
}

export interface GatewaySpec {
  id: GatewayId;
  displayName: string;
  customerLabel: string;
  description: string;
  signupUrl: string;
  fields: FieldSpec[];
}

/// Everything an admin must paste in from each provider's dashboard. The
/// admin screen renders its form straight from this list, so adding a field
/// here is the only change needed to collect a new credential.
export const GATEWAY_SPECS: Record<GatewayId, GatewaySpec> = {
  mpesa: {
    id: 'mpesa',
    displayName: 'M-Pesa (Daraja STK Push)',
    customerLabel: 'M-Pesa',
    description:
      'Customers get a PIN prompt on their phone (Lipa na M-Pesa Online). Works with a Paybill or a Till (Buy Goods).',
    signupUrl: 'https://developer.safaricom.co.ke/',
    fields: [
      { key: 'consumerKey', label: 'Consumer Key', secret: true, required: true, help: 'From your Daraja app (My Apps).' },
      { key: 'consumerSecret', label: 'Consumer Secret', secret: true, required: true, help: 'From your Daraja app (My Apps).' },
      { key: 'shortcode', label: 'Business Shortcode', secret: false, required: true, help: 'Paybill number, or the Head Office / Store number for a Till. Sandbox: 174379.' },
      { key: 'passkey', label: 'Lipa na M-Pesa Passkey', secret: true, required: true, help: 'Emailed by Safaricom when STK Push goes live. Sandbox passkey is on the Daraja test credentials page.' },
      { key: 'transactionType', label: 'Transaction type', secret: false, required: true, help: 'Paybill → CustomerPayBillOnline. Till → CustomerBuyGoodsOnline.', options: ['CustomerPayBillOnline', 'CustomerBuyGoodsOnline'], defaultValue: 'CustomerPayBillOnline' },
      { key: 'tillNumber', label: 'Till number (Buy Goods only)', secret: false, required: false, help: 'Only for CustomerBuyGoodsOnline — the till that receives the money.' },
    ],
  },
  stripe: {
    id: 'stripe',
    displayName: 'Stripe (cards, Apple Pay, Google Pay)',
    customerLabel: 'Card (Stripe)',
    description:
      'Hosted Stripe Checkout page. Charges in KES. Add the webhook URL below in Stripe → Developers → Webhooks, listening for checkout.session.* events.',
    signupUrl: 'https://dashboard.stripe.com/register',
    fields: [
      { key: 'publishableKey', label: 'Publishable key', secret: false, required: true, help: 'pk_test_… or pk_live_…' },
      { key: 'secretKey', label: 'Secret key', secret: true, required: true, help: 'sk_test_… or sk_live_… (a restricted key with Checkout Sessions write access also works).' },
      { key: 'webhookSecret', label: 'Webhook signing secret', secret: true, required: true, help: 'whsec_… shown after you add the webhook endpoint.' },
    ],
  },
  paypal: {
    id: 'paypal',
    displayName: 'PayPal',
    customerLabel: 'PayPal',
    description:
      'PayPal wallet checkout. PayPal does not settle in KES, so orders are converted at the exchange rate you set here.',
    signupUrl: 'https://developer.paypal.com/dashboard/applications',
    fields: [
      { key: 'clientId', label: 'Client ID', secret: false, required: true, help: 'From PayPal Developer → Apps & Credentials.' },
      { key: 'clientSecret', label: 'Client secret', secret: true, required: true, help: 'From the same app.' },
      { key: 'currency', label: 'Charge currency', secret: false, required: true, help: 'Currency PayPal charges in.', options: ['USD', 'EUR', 'GBP'], defaultValue: 'USD' },
      { key: 'kesPerUnit', label: 'KES per 1 unit of that currency', secret: false, required: true, help: 'e.g. 129.5 for USD. Update it when the rate moves.' },
    ],
  },
  flutterwave: {
    id: 'flutterwave',
    displayName: 'Flutterwave (cards, M-Pesa, bank)',
    customerLabel: 'Flutterwave',
    description:
      'Flutterwave Standard hosted checkout in KES. Add the webhook URL below in Flutterwave → Settings → Webhooks, and use the same Secret hash there.',
    signupUrl: 'https://app.flutterwave.com/register',
    fields: [
      { key: 'publicKey', label: 'Public key', secret: false, required: true, help: 'FLWPUBK_TEST-… or FLWPUBK-…' },
      { key: 'secretKey', label: 'Secret key', secret: true, required: true, help: 'FLWSECK_TEST-… or FLWSECK-…' },
      { key: 'secretHash', label: 'Webhook secret hash', secret: true, required: true, help: 'Any long random string — paste the same value into Flutterwave\'s webhook settings.' },
    ],
  },
};

export interface GatewayRuntimeConfig {
  id: GatewayId;
  mode: GatewayMode;
  enabled: boolean;
  configured: boolean;
  values: Record<string, string>;
}

/// PaymentGateways/{id}: public (enabled/configured/mode/labels) — the
/// checkout reads it to decide which buttons to show.
/// PaymentGatewaySecrets/{id}: credentials — firestore.rules deny every
/// client read/write, only this Admin SDK code touches it.
export const publicRef = (id: GatewayId) =>
  db.collection('PaymentGateways').doc(id);
export const secretRef = (id: GatewayId) =>
  db.collection('PaymentGatewaySecrets').doc(id);

export function isComplete(
  id: GatewayId,
  values: Record<string, string>,
): boolean {
  const spec = GATEWAY_SPECS[id];
  const baseOk = spec.fields
    .filter((f) => f.required)
    .every((f) => (values[f.key] ?? '').trim().length > 0);
  if (!baseOk) return false;
  if (id === 'mpesa' && values.transactionType === 'CustomerBuyGoodsOnline') {
    return (values.tillNumber ?? '').trim().length > 0;
  }
  if (id === 'paypal') {
    const rate = Number(values.kesPerUnit);
    return Number.isFinite(rate) && rate > 0;
  }
  return true;
}

export async function loadGateway(
  id: GatewayId,
): Promise<GatewayRuntimeConfig> {
  const [pub, sec] = await Promise.all([publicRef(id).get(), secretRef(id).get()]);
  const p = pub.data() ?? {};
  const values = (sec.data()?.values ?? {}) as Record<string, string>;
  const configured = isComplete(id, values);
  return {
    id,
    mode: p.mode === 'live' ? 'live' : 'sandbox',
    enabled: p.enabled === true && configured,
    configured,
    values,
  };
}

export function maskSecret(value: string): string {
  if (!value) return '';
  return value.length <= 4 ? '••••' : `••••${value.slice(-4)}`;
}

export async function recordTestResult(
  id: GatewayId,
  ok: boolean,
  message: string,
): Promise<void> {
  await publicRef(id).set(
    {
      lastTest: { ok, message: message.slice(0, 300), at: FieldValue.serverTimestamp() },
    },
    { merge: true },
  );
}
