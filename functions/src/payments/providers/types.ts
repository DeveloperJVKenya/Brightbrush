import { BusinessSettings } from '../../settings/business_settings';
import { GatewayRuntimeConfig } from '../gateway_config';

export interface StartContext {
  paymentId: string;
  orderId: string;
  orderNumber: string;
  amountKes: number;
  customerEmail: string;
  customerName: string;
  /// M-Pesa only — normalised 2547XXXXXXXX / 2541XXXXXXXX.
  phone?: string;
  /// Unguessable per-payment token embedded in callback URLs for providers
  /// that don't sign their callbacks (M-Pesa).
  callbackToken: string;
  settings: BusinessSettings;
  config: GatewayRuntimeConfig;
}

export interface StartResult {
  action: 'stk' | 'redirect';
  providerRef: string;
  redirectUrl?: string;
  message: string;
  chargedAmount: number;
  chargedCurrency: string;
}

export interface VerifyResult {
  state: 'succeeded' | 'pending' | 'failed' | 'cancelled';
  receipt?: string;
  message?: string;
}

export interface PaymentProvider {
  start(ctx: StartContext): Promise<StartResult>;
  /// Asks the provider directly whether a payment went through — used by
  /// redirects, webhooks (never trusting the webhook body alone where the
  /// provider allows a lookup) and the customer's "check status" button.
  verify(
    config: GatewayRuntimeConfig,
    payment: { providerRef: string; id: string; amount: number },
  ): Promise<VerifyResult>;
  /// Cheapest authenticated call the provider offers — proves the saved
  /// credentials work without moving money.
  test(config: GatewayRuntimeConfig): Promise<string>;
}
