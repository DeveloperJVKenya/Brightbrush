import { HttpsError } from 'firebase-functions/v2/https';

import { functionsBaseUrl } from '../../core/app';
import { GatewayRuntimeConfig } from '../gateway_config';
import { basicAuth, callProvider } from '../http_util';
import { PaymentProvider, VerifyResult } from './types';

function baseUrl(config: GatewayRuntimeConfig): string {
  return config.mode === 'live'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';
}

/// Accepts 07XXXXXXXX, 01XXXXXXXX, +2547…, 2547… (spaces/dashes ignored)
/// and returns Safaricom's required 2547XXXXXXXX / 2541XXXXXXXX form.
export function normalizeKenyanPhone(input: string): string | null {
  const digits = input.replace(/[^\d]/g, '');
  let normalized = digits;
  if (/^0[17]\d{8}$/.test(digits)) normalized = `254${digits.substring(1)}`;
  else if (/^[17]\d{8}$/.test(digits)) normalized = `254${digits}`;
  return /^254[17]\d{8}$/.test(normalized) ? normalized : null;
}

/// Daraja wants yyyyMMddHHmmss in East Africa Time (UTC+3, no DST).
export function darajaTimestamp(date = new Date()): string {
  const eat = new Date(date.getTime() + 3 * 60 * 60 * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    eat.getUTCFullYear().toString() +
    pad(eat.getUTCMonth() + 1) +
    pad(eat.getUTCDate()) +
    pad(eat.getUTCHours()) +
    pad(eat.getUTCMinutes()) +
    pad(eat.getUTCSeconds())
  );
}

async function accessToken(config: GatewayRuntimeConfig): Promise<string> {
  const res = await callProvider<{ access_token: string }>(
    `${baseUrl(config)}/oauth/v1/generate?grant_type=client_credentials`,
    {
      headers: {
        Authorization: basicAuth(
          config.values.consumerKey,
          config.values.consumerSecret,
        ),
      },
    },
  );
  if (!res.access_token) throw new Error('Daraja returned no access token.');
  return res.access_token;
}

function password(config: GatewayRuntimeConfig, timestamp: string): string {
  return Buffer.from(
    `${config.values.shortcode}${config.values.passkey}${timestamp}`,
  ).toString('base64');
}

export const mpesaProvider: PaymentProvider = {
  async start(ctx) {
    if (!ctx.phone) {
      throw new HttpsError(
        'invalid-argument',
        'Enter the Safaricom number that should receive the M-Pesa prompt.',
      );
    }
    const token = await accessToken(ctx.config);
    const timestamp = darajaTimestamp();
    const v = ctx.config.values;
    const isTill = v.transactionType === 'CustomerBuyGoodsOnline';
    const res = await callProvider<Record<string, string>>(
      `${baseUrl(ctx.config)}/mpesa/stkpush/v1/processrequest`,
      {
        headers: { Authorization: `Bearer ${token}` },
        json: {
          BusinessShortCode: v.shortcode,
          Password: password(ctx.config, timestamp),
          Timestamp: timestamp,
          TransactionType: isTill
            ? 'CustomerBuyGoodsOnline'
            : 'CustomerPayBillOnline',
          Amount: Math.ceil(ctx.amountKes),
          PartyA: ctx.phone,
          PartyB: isTill ? v.tillNumber : v.shortcode,
          PhoneNumber: ctx.phone,
          // Path segments (not query params) carry the payment id + secret
          // token: Safaricom doesn't sign callbacks, so this token is what
          // proves a callback is genuine.
          CallBackURL: `${functionsBaseUrl()}/mpesaCallback/${ctx.paymentId}/${ctx.callbackToken}`,
          AccountReference: ctx.orderNumber.substring(0, 12),
          TransactionDesc: 'Order payment',
        },
      },
    );
    if (res.ResponseCode !== '0' || !res.CheckoutRequestID) {
      throw new Error(res.ResponseDescription ?? 'M-Pesa rejected the request.');
    }
    return {
      action: 'stk',
      providerRef: res.CheckoutRequestID,
      message:
        res.CustomerMessage ??
        'Check your phone and enter your M-Pesa PIN to complete payment.',
      chargedAmount: Math.ceil(ctx.amountKes),
      chargedCurrency: 'KES',
    };
  },

  async verify(config, payment): Promise<VerifyResult> {
    const token = await accessToken(config);
    const timestamp = darajaTimestamp();
    try {
      const res = await callProvider<Record<string, string>>(
        `${baseUrl(config)}/mpesa/stkpushquery/v1/query`,
        {
          headers: { Authorization: `Bearer ${token}` },
          json: {
            BusinessShortCode: config.values.shortcode,
            Password: password(config, timestamp),
            Timestamp: timestamp,
            CheckoutRequestID: payment.providerRef,
          },
        },
      );
      return mapResultCode(String(res.ResultCode), res.ResultDesc);
    } catch (error: any) {
      // Daraja answers "The transaction is being processed" with a 500
      // while the customer still has the PIN prompt open.
      if (String(error?.message ?? '').toLowerCase().includes('processed')) {
        return { state: 'pending' };
      }
      throw error;
    }
  },

  async test(config) {
    await accessToken(config);
    return `Daraja ${config.mode} credentials accepted (access token issued).`;
  },
};

/// Daraja STK result codes: 0 success, 1032 cancelled by user, 1037
/// timeout / phone unreachable, 1 insufficient balance, 2001 wrong PIN.
export function mapResultCode(code: string, desc?: string): VerifyResult {
  if (code === '0') return { state: 'succeeded', message: desc };
  if (code === '1032') {
    return { state: 'cancelled', message: 'You cancelled the M-Pesa prompt.' };
  }
  if (code === '1037') {
    return {
      state: 'failed',
      message: 'The M-Pesa prompt timed out. Make sure your phone is on and try again.',
    };
  }
  if (code === '1') {
    return { state: 'failed', message: 'Insufficient M-Pesa balance.' };
  }
  if (code === '2001') {
    return { state: 'failed', message: 'Wrong M-Pesa PIN entered.' };
  }
  return { state: 'failed', message: desc ?? `M-Pesa error ${code}.` };
}
