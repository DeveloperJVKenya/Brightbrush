import { Notice } from './notify';

export interface ChangeLike {
  field: string;
  from: unknown;
  to: unknown;
}

const kes = (v: number) => `KES ${Math.round(v).toLocaleString('en-KE')}`;

/// Pure: what (if anything) to tell the customer about an order change.
export function customerNoticesFor(
  changes: ChangeLike[],
  order: Record<string, any>,
  orderId: string,
): Notice[] {
  const ref = order.orderNumber ?? 'your order';
  const link = `/customer/orders/${orderId}`;
  const out: Notice[] = [];
  const n = (type: string, title: string, body: string) => out.push({ type, title, body, link, orderId });
  for (const c of changes) {
    if (c.field === 'status') {
      switch (c.to) {
        case 'confirmed':
          n('order.status', `Order ${ref} confirmed`, 'We\'ve reviewed your order and it\'s in the queue.');
          break;
        case 'awaitingProof':
          n('order.proof', `Your design proof is ready`, `Please approve the proof for ${ref} so we can start production.`);
          break;
        case 'inProduction':
          n('order.status', `Order ${ref} is in production`, 'Your items are being made now.');
          break;
        case 'readyForDelivery':
          n(
            'order.status',
            order.deliveryMethod === 'pickup' ? `Order ${ref} is ready to collect` : `Order ${ref} is ready`,
            order.deliveryMethod === 'pickup'
              ? 'Bring your collection code (on your order page) to pick it up.'
              : 'It passed quality control and will be dispatched soon.',
          );
          break;
        case 'outForDelivery':
          n('order.status', `Order ${ref} is on its way`, 'Give the driver the 4-digit code on your order page when it arrives.');
          break;
        case 'completed':
          n('order.review', `Order ${ref} delivered`, 'Thank you! How did we do? Leave a quick review from your order page.');
          break;
        case 'cancelled':
          n('order.status', `Order ${ref} was cancelled`, order.cancelReason ? `Reason: ${order.cancelReason}` : 'Contact us if you have any questions.');
          break;
      }
    }
    if (c.field === 'amountPaid' && typeof c.to === 'number' && c.to > ((c.from as number) ?? 0)) {
      const received = c.to - ((c.from as number) ?? 0);
      const balance = Math.max(0, (order.total ?? 0) - c.to + (order.refundedAmount ?? 0));
      n('payment.received', `Payment received — ${kes(received)}`, balance > 0 ? `Thank you. Balance on ${ref}: ${kes(balance)}.` : `Thank you — ${ref} is fully paid.`);
    }
    if (c.field === 'refundedAmount' && typeof c.to === 'number' && c.to > ((c.from as number) ?? 0)) {
      n('payment.refund', `Refund on ${ref}`, `${kes(c.to - ((c.from as number) ?? 0))} is being refunded to you.`);
    }
    if (c.field === 'overdue' && c.to === true) {
      n('payment.overdue', `Invoice ${order.invoiceNumber ?? ref} is overdue`, `${kes(Math.max(0, (order.total ?? 0) - (order.amountPaid ?? 0)))} is outstanding. You can pay from your order page.`);
    }
  }
  return out;
}

/// Pure: what staff should hear about (customer-side moves).
export function staffNoticesFor(changes: ChangeLike[], order: Record<string, any>, orderId: string): Notice[] {
  const ref = order.orderNumber ?? orderId;
  const link = `/manager/orders`;
  const out: Notice[] = [];
  for (const c of changes) {
    if (c.field === 'proofStatus' && c.to === 'approved') {
      out.push({ type: 'staff.proof', title: `Proof approved — ${ref}`, body: 'Ready to schedule into production.', link, orderId });
    }
    if (c.field === 'proofStatus' && c.to === 'changesRequested') {
      out.push({ type: 'staff.proof', title: `Changes requested — ${ref}`, body: 'The customer asked for changes to the proof.', link, orderId });
    }
    if (c.field === 'status' && c.to === 'cancelled' && order.lastUpdatedBy === order.customerId) {
      out.push({ type: 'staff.order', title: `Order ${ref} cancelled by customer`, body: order.contactName ?? '', link, orderId });
    }
  }
  return out;
}
