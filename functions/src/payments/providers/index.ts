import { GatewayId } from '../gateway_config';
import { flutterwaveProvider } from './flutterwave';
import { mpesaProvider } from './mpesa';
import { paypalProvider } from './paypal';
import { stripeProvider } from './stripe';
import { PaymentProvider } from './types';

export const PROVIDERS: Record<GatewayId, PaymentProvider> = {
  mpesa: mpesaProvider,
  stripe: stripeProvider,
  paypal: paypalProvider,
  flutterwave: flutterwaveProvider,
};
