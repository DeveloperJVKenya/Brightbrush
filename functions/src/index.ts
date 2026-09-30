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
export { issueRefund } from './payments/refunds';
export { previewDiscount } from './accounts/accounts';
export {
  adminGetEtims,
  adminInitEtims,
  adminSaveEtims,
  etimsOnOrderUpdate,
  etimsOnRefund,
  submitEtimsInvoice,
} from './etims/etims';
export { getDocument } from './documents/documents';
export { exportAccounting, markOverdueInvoices } from './accounts/receivables';
export { onOrderChanged } from './ops/order_events';
export {
  auditAccounts,
  auditCatalog,
  auditCoupons,
  auditGateways,
  auditManualPayments,
  auditRefunds,
  auditSettings,
  auditUsers,
} from './ops/audit';
export {
  completeDelivery,
  createPurchaseOrder,
  receivePurchaseOrder,
  recordQualityCheck,
} from './ops/ops_callables';
export {
  adminGetNotificationChannels,
  adminSaveNotificationChannels,
  adminTestNotification,
} from './notifications/notify';
export { onOrderCreated, onQuoteWritten, remindAbandonedCarts } from './notifications/triggers';
export { onChatMessage, onReviewWritten } from './notifications/social_triggers';
export { claimReferral, getMyReferralCode } from './loyalty/loyalty';
export {
  aggregateOrderStats,
  backupFirestore,
  indexCatalogSearch,
  indexOrderSearch,
  logClientError,
  rebuildOrderStats,
} from './platform/platform';
