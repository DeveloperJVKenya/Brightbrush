import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';

import { DATABASE_ID, db } from '../core/app';
import { notifyStaff, notifyUser } from './notify';

/// Order chat: notify the other side and keep unread counters in
/// Orders/{id}/ChatState/state (server-maintained; each side resets its own
/// counter when it opens the chat).
export const onChatMessage = onDocumentCreated(
  { document: 'Orders/{orderId}/Messages/{messageId}', database: DATABASE_ID },
  async (event) => {
    const m = event.data?.data();
    if (!m) return;
    const orderId = event.params.orderId as string;
    const order = (await db.collection('Orders').doc(orderId).get()).data();
    if (!order) return;
    const fromCustomer = m.fromRole === 'customer';
    await db.collection('Orders').doc(orderId).collection('ChatState').doc('state').set({
      customerId: order.customerId,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessage: String(m.text ?? '').slice(0, 120) || 'Attachment',
      ...(fromCustomer ? { staffUnread: FieldValue.increment(1) } : { customerUnread: FieldValue.increment(1) }),
    }, { merge: true });
    const preview = String(m.text ?? '').slice(0, 140) || 'Sent an attachment';
    if (fromCustomer) {
      await notifyStaff({
        type: 'chat.message',
        title: `Message on ${order.orderNumber} from ${order.contactName}`,
        body: preview,
        link: '/manager/orders',
        orderId,
      });
    } else {
      await notifyUser(order.customerId, {
        type: 'chat.message',
        title: `New message about ${order.orderNumber}`,
        body: preview,
        link: `/customer/orders/${orderId}`,
        orderId,
      });
    }
  },
);

/// Reviews: tell staff about new ones; when a review is approved or hidden,
/// recompute the average rating of every catalog item on that order.
export const onReviewWritten = onDocumentWritten(
  { document: 'Reviews/{orderId}', database: DATABASE_ID },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before && after) {
      await notifyStaff({
        type: 'staff.review',
        title: `New ${after.rating}★ review`,
        body: `${after.customerName}: ${String(after.comment ?? '').slice(0, 120)}`,
        link: '/manager/reviews',
      });
    }
    const itemIds = [...new Set([...(before?.itemIds ?? []), ...(after?.itemIds ?? [])])] as string[];
    if (before?.status === after?.status || itemIds.length === 0) return;
    for (const itemId of itemIds) {
      const approved = await db
        .collection('Reviews')
        .where('itemIds', 'array-contains', itemId)
        .where('status', '==', 'approved')
        .get();
      const ratings = approved.docs.map((d) => Number(d.data().rating) || 0).filter((r) => r > 0);
      const avg = ratings.length ? Math.round((ratings.reduce((a, b) => a + b, 0) / ratings.length) * 10) / 10 : 0;
      await db.collection('CatalogItems').doc(itemId).update({ ratingAvg: avg, ratingCount: ratings.length }).catch(() => undefined);
    }
  },
);
