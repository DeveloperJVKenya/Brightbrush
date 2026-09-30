import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { DATABASE_ID, db } from '../core/app';
import { notifyStaff, notifyUser } from './notify';

const kes = (v: number) => `KES ${Math.round(v).toLocaleString('en-KE')}`;

export const onOrderCreated = onDocumentCreated(
  { document: 'Orders/{orderId}', database: DATABASE_ID },
  async (event) => {
    const o = event.data?.data();
    if (!o) return;
    const orderId = event.params.orderId as string;
    await Promise.all([
      notifyUser(o.customerId, {
        type: 'order.placed',
        title: `Order ${o.orderNumber} received`,
        body: o.paymentPlan === 'credit'
          ? `Total ${kes(o.total)} on your account. We'll review it shortly.`
          : `Total ${kes(o.total)}. ${o.depositAmount < o.total ? `Pay the ${kes(o.depositAmount)} deposit` : 'Pay'} from your order page to get started.`,
        link: `/customer/orders/${orderId}`,
        orderId,
      }),
      notifyStaff({
        type: 'staff.order',
        title: `New order ${o.orderNumber} — ${kes(o.total)}`,
        body: `${o.customerCompany || o.contactName} · ${(o.items ?? []).length} line(s)${o.requiresProof ? ' · needs a proof' : ''}`,
        link: '/manager/orders',
        orderId,
      }),
    ]);
  },
);

export const onQuoteWritten = onDocumentWritten(
  { document: 'QuoteRequests/{quoteId}', database: DATABASE_ID },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;
    if (!before) {
      await notifyStaff({
        type: 'staff.quote',
        title: `Quote request: ${after.title}`,
        body: `${after.customerName} · ${after.quantity} pcs`,
        link: '/manager/quotes',
      });
      return;
    }
    if (after.status === 'quoted' && (before.status !== 'quoted' || before.quotedTotal !== after.quotedTotal)) {
      await notifyUser(after.customerId, {
        type: 'quote.priced',
        title: `Your quote is ready — ${kes(after.quotedTotal)}`,
        body: `${after.title}. Accept it in My quotes to place the order.`,
        link: '/customer/quotes',
      });
    }
    if (after.status === 'declined' && before.status !== 'declined') {
      await notifyUser(after.customerId, {
        type: 'quote.declined',
        title: 'About your quote request',
        body: after.quoteMessage || `We can't take on "${after.title}" right now.`,
        link: '/customer/quotes',
      });
    }
  },
);

/// Daily at 10:00: a friendly nudge for carts left untouched for more than
/// a day (at most one reminder per cart change, and never after 7 days).
export const remindAbandonedCarts = onSchedule(
  { schedule: 'every day 10:00', timeZone: 'Africa/Nairobi' },
  async () => {
    const now = Date.now();
    const snap = await db
      .collection('Carts')
      .where('updatedAt', '<=', Timestamp.fromMillis(now - 24 * 3600 * 1000))
      .where('updatedAt', '>=', Timestamp.fromMillis(now - 7 * 24 * 3600 * 1000))
      .get();
    let sent = 0;
    for (const doc of snap.docs) {
      const c = doc.data();
      const count = Object.keys(c.items ?? {}).length + Object.keys(c.lines ?? {}).length;
      if (count === 0) continue;
      const updatedAt = (c.updatedAt as Timestamp).toMillis();
      const reminderRef = db.collection('CartReminders').doc(doc.id);
      const last = (await reminderRef.get()).data()?.forUpdatedAt as number | undefined;
      if (last === updatedAt) continue;
      await notifyUser(doc.id, {
        type: 'marketing.cart',
        title: 'You left something in your cart',
        body: `${count} item(s) are waiting for you. Complete your order whenever you're ready.`,
        link: '/customer/cart',
      });
      await reminderRef.set({ forUpdatedAt: updatedAt, at: FieldValue.serverTimestamp() });
      sent++;
    }
    logger.info('[remindAbandonedCarts]', { checked: snap.size, sent });
  },
);
