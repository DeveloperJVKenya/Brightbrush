import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db } from '../core/app';
import { requireRole } from '../core/authz';
import { asObject, requireString } from '../core/validate';

/// Every morning: flag credit orders past their due date with a balance as
/// overdue (and clear the flag once paid). Staff chase them from the
/// Receivables screen.
export const markOverdueInvoices = onSchedule(
  { schedule: 'every day 06:00', timeZone: 'Africa/Nairobi' },
  async () => {
    const now = Timestamp.now();
    const snap = await db.collection('Orders').where('dueDate', '<=', now).get();
    const writer = db.bulkWriter();
    let flagged = 0;
    let cleared = 0;
    for (const doc of snap.docs) {
      const o = doc.data();
      const balance = (o.total ?? 0) - ((o.amountPaid ?? 0) - (o.refundedAmount ?? 0));
      const overdue = o.status !== 'cancelled' && balance > 0;
      if (overdue && o.overdue !== true) {
        writer.update(doc.ref, { overdue: true, updatedAt: FieldValue.serverTimestamp() });
        flagged++;
      } else if (!overdue && o.overdue === true) {
        writer.update(doc.ref, { overdue: false, updatedAt: FieldValue.serverTimestamp() });
        cleared++;
      }
    }
    await writer.close();
    logger.info('[markOverdueInvoices]', { checked: snap.size, flagged, cleared });
  },
);

const csvCell = (v: unknown) => {
  const s = v === null || v === undefined ? '' : String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
export const toCsv = (rows: unknown[][]) => rows.map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n';

const day = (v: any) => {
  const d: Date | undefined = v?.toDate?.() ?? (v instanceof Date ? v : undefined);
  return d ? d.toISOString().slice(0, 10) : '';
};

/// Admin: sales, payments, refunds and expenses for a date range as CSVs
/// (sales in Xero's sales-invoice import layout, which QuickBooks also
/// maps), plus a cash-basis profit & loss summary.
export const exportAccounting = onCall({ memory: '512MiB', timeoutSeconds: 120 }, async (request) => {
  await requireRole(request, ['admin']);
  const data = asObject(request.data);
  const from = new Date(requireString(data, 'from', 'From', 10, 30));
  const to = new Date(requireString(data, 'to', 'To', 10, 30));
  if (isNaN(from.getTime()) || isNaN(to.getTime()) || to < from) {
    throw new HttpsError('invalid-argument', 'Choose a valid date range.');
  }
  to.setUTCHours(23, 59, 59, 999);
  const range = (field: string, col: string) =>
    db.collection(col).where(field, '>=', Timestamp.fromDate(from)).where(field, '<=', Timestamp.fromDate(to)).get();

  const [orders, payments, refunds, expenses] = await Promise.all([
    range('createdAt', 'Orders'),
    range('createdAt', 'Payments'),
    range('createdAt', 'Refunds'),
    range('date', 'Expenses'),
  ]);

  const sales: unknown[][] = [[
    '*ContactName', 'EmailAddress', '*InvoiceNumber', 'Reference', '*InvoiceDate', '*DueDate',
    'Description', '*Quantity', '*UnitAmount', '*AccountCode', '*TaxType', 'Currency',
  ]];
  let invoiced = 0;
  let vat = 0;
  for (const doc of orders.docs) {
    const o = doc.data();
    if (o.status === 'cancelled') continue;
    invoiced += o.total ?? 0;
    vat += o.taxAmount ?? 0;
    const contact = o.customerCompany || o.contactName || 'Customer';
    const inv = o.invoiceNumber ?? o.orderNumber ?? doc.id;
    const date = day(o.createdAt);
    const due = day(o.dueDate) || date;
    const tax = (o.taxAmount ?? 0) > 0 ? 'Output VAT' : 'No VAT';
    const row = (desc: string, qty: number, unit: number) =>
      sales.push([contact, o.customerEmail ?? '', inv, o.orderNumber ?? '', date, due, desc, qty, unit, '200', tax, 'KES']);
    for (const i of o.items ?? []) {
      const qty = Number(i.quantity) || 1;
      const total = Number(i.lineTotal ?? i.unitPrice * i.quantity) || 0;
      row(String(i.name), qty, Math.round((total / qty) * 100) / 100);
    }
    if ((o.deliveryFee ?? 0) > 0) row('Delivery', 1, o.deliveryFee);
    if ((o.discountAmount ?? 0) > 0) row('Discount', 1, -o.discountAmount);
  }

  const paymentRows: unknown[][] = [['Date', 'ReceiptNumber', 'OrderNumber', 'Method', 'Reference', 'Amount', 'Currency']];
  let collected = 0;
  for (const doc of payments.docs) {
    const p = doc.data();
    if (p.status !== 'succeeded') continue;
    collected += p.amount ?? 0;
    paymentRows.push([day(p.completedAt ?? p.createdAt), p.receiptNumber ?? '', p.orderNumber ?? p.orderId, p.method ?? p.gateway, p.receipt ?? '', p.amount, 'KES']);
  }

  const refundRows: unknown[][] = [['Date', 'CreditNoteNumber', 'OrderNumber', 'InvoiceNumber', 'Amount', 'CancellationFee', 'Reason']];
  let refunded = 0;
  for (const doc of refunds.docs) {
    const r = doc.data();
    refunded += r.amount ?? 0;
    refundRows.push([day(r.createdAt), r.creditNoteNumber, r.orderNumber, r.invoiceNumber ?? '', r.amount, r.cancellationFee ?? 0, r.reason]);
  }

  const expenseRows: unknown[][] = [['Date', 'Category', 'Note', 'Amount']];
  const byCategory: Record<string, number> = {};
  let spent = 0;
  for (const doc of expenses.docs) {
    const e = doc.data();
    spent += e.amount ?? 0;
    byCategory[e.category] = (byCategory[e.category] ?? 0) + (e.amount ?? 0);
    expenseRows.push([day(e.date), e.category, e.note ?? '', e.amount]);
  }

  const netCollected = collected - refunded;
  return {
    salesCsv: toCsv(sales),
    paymentsCsv: toCsv(paymentRows),
    refundsCsv: toCsv(refundRows),
    expensesCsv: toCsv(expenseRows),
    summary: {
      invoiced,
      vatOnInvoices: vat,
      collected,
      refunded,
      netCollected,
      expenses: spent,
      expensesByCategory: byCategory,
      netProfitCashBasis: netCollected - spent,
      orderCount: orders.size,
    },
  };
});
