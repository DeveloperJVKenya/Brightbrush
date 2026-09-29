/// BrightBrush Creations backend. Every export below becomes one deployed
/// Cloud Function (region set in core/app.ts).

export { deleteMyAccount } from './account/delete_my_account';
export { placeOrder } from './orders/place_order';
export {
  adminGetPaymentGateways,
  adminSavePaymentGateway,
  adminTestPaymentGateway,
} from './payments/admin_gateways';
export {
  initiatePayment,
  recordManualPayment,
  refreshPaymentStatus,
} from './payments/payment_callables';
export {
  flutterwaveReturn,
  flutterwaveWebhook,
  mpesaCallback,
  paypalReturn,
  stripeWebhook,
} from './payments/webhooks';
export { acceptQuote } from './quotes/accept_quote';
export { respondToProof, sendProof } from './proofs/proofs';
