import {
  DocumentReference,
  FieldValue,
  Transaction,
} from 'firebase-admin/firestore';

import { db } from '../core/app';
import { OrderTotals } from './pricing';

export interface PricedLine {
  kind: 'item' | 'package' | 'quote' | 'custom';
  itemId: string;
  name: string;
  category: string;
  unitPrice: number;
  quantity: number;
  /// Set for customised lines, whose total isn't unitPrice × quantity
  /// (one-off setup fees, size surcharges, personalisation).
  lineTotal?: number;
  customization?: Record<string, unknown>;
  pricing?: Record<string, number>;
}

export function lineTotalOf(line: PricedLine): number {
  return line.lineTotal ?? line.unitPrice * line.quantity;
}

export interface OrderContact {
  contactName: string;
  contactPhone: string;
  deliveryAddress: string;
  notes: string;
}

/// Human-friendly, gapless order numbers (BB-000123) for invoices, receipts
/// and M-Pesa account references. Must be called inside the same
/// transaction that creates the order so two concurrent checkouts can never
/// share a number. Reads happen here, so call this before any tx writes.
export async function nextOrderNumber(tx: Transaction): Promise<string> {
  const ref = db.collection('Counters').doc('orders');
  const snap = await tx.get(ref);
  const next = ((snap.data()?.value as number | undefined) ?? 0) + 1;
  tx.set(ref, { value: next, updatedAt: FieldValue.serverTimestamp() });
  return `BB-${String(next).padStart(6, '0')}`;
}

/// The single place an Orders document is ever created — clients can no
/// longer write Orders directly (firestore.rules denies create), so every
/// price, total and deposit on an order was computed here.
export function writeOrder(
  tx: Transaction,
  params: {
    ref: DocumentReference;
    orderNumber: string;
    customerId: string;
    customerEmail: string;
    contact: OrderContact;
    lines: PricedLine[];
    totals: OrderTotals;
    source: 'cart' | 'quote';
    quoteId?: string;
    /// Decorated orders need a customer-approved proof before production
    /// (enforced in firestore.rules).
    requiresProof?: boolean;
    /// Commercial extras: delivery method/zone, discounts, coupon, business
    /// account details and credit due date.
    extra?: Record<string, unknown>;
  },
): void {
  const { totals } = params;
  tx.create(params.ref, {
    orderNumber: params.orderNumber,
    // One invoice per order, numbered in step with the order (gapless).
    invoiceNumber: params.orderNumber.replace(/^BB-/, 'INV-'),
    customerId: params.customerId,
    customerEmail: params.customerEmail,
    contactName: params.contact.contactName,
    contactPhone: params.contact.contactPhone,
    deliveryAddress: params.contact.deliveryAddress,
    ...(params.contact.notes ? { notes: params.contact.notes } : {}),
    items: params.lines.map((l) => ({
      kind: l.kind,
      itemId: l.itemId,
      name: l.name,
      category: l.category,
      unitPrice: l.unitPrice,
      quantity: l.quantity,
      ...(l.lineTotal !== undefined ? { lineTotal: l.lineTotal } : {}),
      ...(l.customization ? { customization: l.customization } : {}),
      ...(l.pricing ? { pricing: l.pricing } : {}),
    })),
    requiresProof: params.requiresProof === true,
    proofStatus: params.requiresProof === true ? 'required' : 'notRequired',
    subtotal: totals.subtotal,
    deliveryFee: totals.deliveryFee,
    taxRate: totals.taxRate,
    taxAmount: totals.taxAmount,
    total: totals.total,
    paymentPlan: totals.paymentPlan,
    depositAmount: totals.depositAmount,
    amountPaid: 0,
    refundedAmount: 0,
    discountAmount: totals.discountAmount,
    ...(params.extra ?? {}),
    status: 'pendingReview',
    paymentStatus: 'unpaid',
    assignedStaffId: null,
    source: params.source,
    ...(params.quoteId ? { quoteId: params.quoteId } : {}),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}
