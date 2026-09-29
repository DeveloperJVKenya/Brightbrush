import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { loadCustomerAccount } from '../accounts/accounts';
import { loadCaller } from '../core/authz';
import { asObject, requireEnum, requireString } from '../core/validate';
import { nextOrderNumber, writeOrder } from '../orders/order_writer';
import { readContact } from '../orders/place_order';
import { computeTotals } from '../orders/pricing';
import { loadBusinessSettings } from '../settings/business_settings';

/// Turns a staff-priced QuoteRequest into an Order at the quoted price. The
/// quoted total is taken from the QuoteRequests document (written only by
/// manager/admin per firestore.rules), never from the client. Quoted prices
/// already include delivery; VAT follows the same inclusive/exclusive
/// setting as catalog prices.
export const acceptQuote = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const quoteId = requireString(data, 'quoteId', 'Quote', 1, 100);
  const contact = readContact(data);
  const paymentPlan = requireEnum(data, 'paymentPlan', ['full', 'deposit', 'credit'], 'full');
  const [settings, account] = await Promise.all([
    loadBusinessSettings(),
    loadCustomerAccount(caller.uid),
  ]);

  const quoteRef = db.collection('QuoteRequests').doc(quoteId);
  const orderRef = db.collection('Orders').doc();

  const orderNumber = await db.runTransaction(async (tx) => {
    const snap = await tx.get(quoteRef);
    const q = snap.data();
    if (!snap.exists || !q || q.customerId !== caller.uid) {
      throw new HttpsError('not-found', 'Quote not found.');
    }
    if (q.status !== 'quoted') {
      throw new HttpsError(
        'failed-precondition',
        q.status === 'accepted'
          ? 'This quote has already been accepted.'
          : 'This quote has not been priced yet.',
      );
    }
    const quotedTotal = q.quotedTotal;
    if (typeof quotedTotal !== 'number' || quotedTotal <= 0) {
      throw new HttpsError('failed-precondition', 'This quote has no price yet.');
    }
    const validUntil = q.validUntil?.toMillis?.() as number | undefined;
    if (validUntil && Date.now() > validUntil) {
      throw new HttpsError(
        'failed-precondition',
        'This quote has expired. Ask us for an updated price.',
      );
    }

    const totals = computeTotals(quotedTotal, settings, {
      paymentPlan,
      includeDelivery: false,
      creditAllowed: account.creditEnabled,
    });
    const number = await nextOrderNumber(tx);
    const quantity =
      typeof q.quantity === 'number' && q.quantity > 0 ? q.quantity : 1;
    writeOrder(tx, {
      ref: orderRef,
      orderNumber: number,
      customerId: caller.uid,
      customerEmail: caller.email ?? '',
      contact,
      lines: [
        {
          kind: 'quote',
          itemId: q.packageId ?? q.itemId ?? quoteId,
          name: `${q.title} (quoted, ${quantity} pcs)`,
          category: 'quote',
          unitPrice: totals.subtotal,
          quantity: 1,
        },
      ],
      totals,
      source: 'quote',
      quoteId,
      extra: {
        deliveryMethod: 'delivery',
        ...(account.companyName ? { customerCompany: account.companyName } : {}),
        ...(account.kraPin ? { customerKraPin: account.kraPin } : {}),
        ...(totals.paymentPlan === 'credit'
          ? { dueDate: new Date(Date.now() + account.paymentTermsDays * 86400000) }
          : {}),
      },
    });
    tx.update(quoteRef, {
      status: 'accepted',
      orderId: orderRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return number;
  });

  logger.info('[acceptQuote] order created', {
    quoteId,
    orderId: orderRef.id,
    orderNumber,
  });
  return { orderId: orderRef.id, orderNumber };
});
