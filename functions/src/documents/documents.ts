import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { loadCustomerAccount } from '../accounts/accounts';
import { db } from '../core/app';
import { Caller, isStaff, loadCaller } from '../core/authz';
import { asObject, requireEnum, requireString } from '../core/validate';
import { BusinessSettings, loadBusinessSettings } from '../settings/business_settings';
import { DocLine, DocSpec, DocTotalRow, formatDate, formatMoney, renderPdf } from './pdf';

const STAFF: Array<'systemManager' | 'admin'> = ['systemManager', 'admin'];

function toDate(v: any): Date {
  return v?.toDate?.() ?? (v instanceof Date ? v : new Date());
}

function assertAccess(caller: Caller, customerId: string | undefined): void {
  if (caller.uid !== customerId && !isStaff(caller.role, STAFF)) {
    throw new HttpsError('not-found', 'Document not found.');
  }
}

const LABELS: Record<string, string> = {
  leftChest: 'Left chest', rightChest: 'Right chest', centerChest: 'Centre chest',
  fullFront: 'Full front', upperBack: 'Upper back', fullBack: 'Full back',
  leftSleeve: 'Left sleeve', rightSleeve: 'Right sleeve', capFront: 'Cap front',
  capSide: 'Cap side', capBack: 'Cap back', productFront: 'Front', productBack: 'Back',
  wrapAround: 'Wrap-around', embroidery: 'embroidery', screenPrint: 'screen print',
  dtf: 'DTF', heatTransfer: 'heat transfer', sublimation: 'sublimation',
  laserEngraving: 'laser engraving',
};
const label = (v: unknown) => LABELS[String(v)] ?? String(v ?? '');

function describeCustomization(c: Record<string, any> | undefined): string | undefined {
  if (!c) return undefined;
  const sizes = Object.entries(c.sizeQuantities ?? {})
    .map(([s, q]) => (s === 'One size' ? `${q} pcs` : `${s}×${q}`))
    .join(', ');
  const decorations = (c.decorations ?? []).map((d: any) =>
    [label(d.placement) + ':', label(d.method), d.sizeClass, d.artworkName ?? (d.text ? `"${d.text}"` : '')].filter(Boolean).join(' '),
  );
  return [c.colour, sizes, ...decorations, c.names?.length ? `${c.names.length} names` : '']
    .filter(Boolean)
    .join(' · ');
}

function billTo(o: Record<string, any>): string[] {
  return [
    o.customerCompany,
    o.contactName,
    o.contactPhone,
    o.customerEmail,
    o.deliveryAddress,
    o.customerKraPin ? `KRA PIN: ${o.customerKraPin}` : '',
  ].filter(Boolean);
}

function etimsBlock(e: any): DocSpec['etims'] {
  if (!e || e.status !== 'submitted') return undefined;
  return {
    qrUrl: e.qrUrl,
    lines: [
      e.sdcId ? `SCU ID: ${e.sdcId}` : '',
      e.mrcNo ? `MRC: ${e.mrcNo}` : '',
      `CU invoice no: ${e.sdcId ?? ''}/${e.rcptNo ?? e.invcNo}`,
      e.intrlData ? `Internal data: ${e.intrlData}` : '',
      e.rcptSign ? `Receipt signature: ${e.rcptSign}` : '',
      e.sdcDateTime ? `Date: ${e.sdcDateTime}` : '',
    ].filter(Boolean),
  };
}

function orderTotals(o: Record<string, any>): DocTotalRow[] {
  const vatPct = Math.round((o.taxRate ?? 0) * 100);
  const inclusive = (o.total ?? 0) === (o.subtotal ?? 0) - (o.discountAmount ?? 0) + (o.deliveryFee ?? 0);
  const paid = (o.amountPaid ?? 0) - (o.refundedAmount ?? 0);
  return [
    { label: 'Subtotal', amount: o.subtotal ?? 0 },
    ...((o.corporateDiscount ?? 0) > 0 ? [{ label: 'Account discount', amount: -o.corporateDiscount }] : []),
    ...((o.couponDiscount ?? 0) > 0 ? [{ label: `Coupon ${o.couponCode ?? ''}`, amount: -o.couponDiscount }] : []),
    ...((o.deliveryFee ?? 0) > 0 ? [{ label: `Delivery${o.deliveryZoneName ? ` (${o.deliveryZoneName})` : ''}`, amount: o.deliveryFee }] : []),
    ...((o.taxAmount ?? 0) > 0 ? [{ label: inclusive ? `Includes VAT ${vatPct}%` : `VAT ${vatPct}%`, amount: o.taxAmount }] : []),
    { label: 'Total', amount: o.total ?? 0, bold: true },
    ...(paid > 0 ? [{ label: 'Paid', amount: paid }] : []),
    { label: 'Balance due', amount: Math.max(0, (o.total ?? 0) - paid), bold: true },
  ];
}

async function invoiceSpec(orderId: string, caller: Caller, settings: BusinessSettings): Promise<[DocSpec, string]> {
  const o = (await db.collection('Orders').doc(orderId).get()).data();
  if (!o) throw new HttpsError('not-found', 'Order not found.');
  assertAccess(caller, o.customerId);
  const lines: DocLine[] = (o.items ?? []).map((i: any) => ({
    description: String(i.name),
    detail: describeCustomization(i.customization),
    quantity: Number(i.quantity) || 1,
    unitPrice: Number(i.unitPrice) || 0,
    amount: Number(i.lineTotal ?? i.unitPrice * i.quantity) || 0,
  }));
  const number = o.invoiceNumber ?? o.orderNumber ?? orderId;
  return [{
    title: 'Tax invoice',
    number,
    date: toDate(o.createdAt),
    meta: [
      ['Order', String(o.orderNumber ?? orderId)],
      ...(o.dueDate ? [['Due', formatDate(toDate(o.dueDate))] as [string, string]] : []),
      ['Delivery', o.deliveryMethod === 'pickup' ? 'Store pickup' : 'Delivery'],
    ],
    billTo: billTo(o),
    lines,
    totals: orderTotals(o),
    etims: etimsBlock(o.etims),
    notes: [
      o.paymentPlan === 'credit' && o.dueDate ? `Payment due by ${formatDate(toDate(o.dueDate))}.` : '',
      settings.paymentInstructions ? `How to pay: ${settings.paymentInstructions}` : '',
      `Pay online from your order page: ${settings.appBaseUrl}`,
    ],
  }, `${number}.pdf`];
}

async function receiptSpec(paymentId: string, caller: Caller, settings: BusinessSettings): Promise<[DocSpec, string]> {
  const p = (await db.collection('Payments').doc(paymentId).get()).data();
  if (!p || p.status !== 'succeeded') throw new HttpsError('not-found', 'Receipt not found.');
  assertAccess(caller, p.customerId);
  const o = (await db.collection('Orders').doc(p.orderId).get()).data() ?? {};
  const method: Record<string, string> = {
    mpesa: 'M-Pesa', stripe: 'Card (Stripe)', paypal: 'PayPal', flutterwave: 'Flutterwave',
    cash: 'Cash', bankTransfer: 'Bank transfer', mpesaManual: 'M-Pesa', cheque: 'Cheque', other: 'Other',
  };
  const number = p.receiptNumber ?? `RCT-${paymentId.slice(0, 8)}`;
  const paidNet = (o.amountPaid ?? 0) - (o.refundedAmount ?? 0);
  return [{
    title: 'Receipt',
    number,
    date: toDate(p.completedAt ?? p.createdAt),
    meta: [
      ['Invoice', String(o.invoiceNumber ?? p.orderNumber ?? '')],
      ['Method', method[p.method ?? p.gateway] ?? String(p.gateway)],
      ...(p.receipt ? [['Reference', String(p.receipt)] as [string, string]] : []),
    ],
    billTo: billTo(o),
    lines: [{
      description: `Payment for order ${o.orderNumber ?? p.orderId}`,
      quantity: 1,
      unitPrice: p.amount,
      amount: p.amount,
    }],
    totals: [
      { label: 'Amount received', amount: p.amount, bold: true },
      { label: 'Order total', amount: o.total ?? 0 },
      { label: 'Balance remaining', amount: Math.max(0, (o.total ?? 0) - paidNet) },
    ],
    notes: [
      p.chargedCurrency && p.chargedCurrency !== 'KES' ? `Charged as ${p.chargedCurrency} ${p.chargedAmount}.` : '',
      'Thank you for your payment.',
    ],
  }, `${number}.pdf`];
}

async function creditNoteSpec(refundId: string, caller: Caller, settings: BusinessSettings): Promise<[DocSpec, string]> {
  const r = (await db.collection('Refunds').doc(refundId).get()).data();
  if (!r) throw new HttpsError('not-found', 'Credit note not found.');
  assertAccess(caller, r.customerId);
  const o = (await db.collection('Orders').doc(r.orderId).get()).data() ?? {};
  return [{
    title: 'Credit note',
    number: r.creditNoteNumber,
    date: toDate(r.createdAt),
    meta: [['Against invoice', String(r.invoiceNumber ?? o.orderNumber ?? '')]],
    billTo: billTo(o),
    lines: [{ description: `Refund: ${r.reason}`, quantity: 1, unitPrice: r.amount, amount: r.amount }],
    totals: [
      ...((r.cancellationFee ?? 0) > 0 ? [{ label: 'Cancellation fee retained', amount: r.cancellationFee }] : []),
      { label: 'Total credited', amount: r.amount, bold: true },
    ],
    etims: etimsBlock(r.etims),
    notes: [r.cancelled ? 'The order was cancelled.' : ''],
  }, `${r.creditNoteNumber}.pdf`];
}

async function quoteSpec(quoteId: string, caller: Caller, settings: BusinessSettings): Promise<[DocSpec, string]> {
  const q = (await db.collection('QuoteRequests').doc(quoteId).get()).data();
  if (!q || typeof q.quotedTotal !== 'number') throw new HttpsError('not-found', 'Quote not found.');
  assertAccess(caller, q.customerId);
  const number = `QT-${quoteId.slice(0, 8).toUpperCase()}`;
  return [{
    title: 'Quotation',
    number,
    date: toDate(q.updatedAt),
    meta: q.validUntil ? [['Valid until', formatDate(toDate(q.validUntil))]] : [],
    billTo: [q.customerName, q.customerEmail].filter(Boolean),
    lines: [{
      description: q.title,
      detail: q.details || undefined,
      quantity: q.quantity ?? 1,
      unitPrice: Math.round(q.quotedTotal / (q.quantity || 1)),
      amount: q.quotedTotal,
    }],
    totals: [{ label: 'Quoted total (incl. delivery)', amount: q.quotedTotal, bold: true }],
    notes: [
      q.quoteMessage ?? '',
      settings.vatEnabled ? (settings.pricesIncludeVat ? 'Price includes VAT.' : 'VAT will be added.') : '',
      `Accept this quote in the app: ${settings.appBaseUrl}`,
    ],
  }, `${number}.pdf`];
}

async function statementSpec(customerId: string, caller: Caller): Promise<[DocSpec, string]> {
  assertAccess(caller, customerId);
  const [account, orders] = await Promise.all([
    loadCustomerAccount(customerId),
    db.collection('Orders').where('customerId', '==', customerId).get(),
  ]);
  const now = Date.now();
  const rows: string[][] = [];
  let invoiced = 0;
  let paidTotal = 0;
  let contact: Record<string, any> = {};
  const aging = { current: 0, d30: 0, d60: 0, d90: 0 };
  for (const doc of orders.docs.sort((a, b) => toDate(a.data().createdAt).getTime() - toDate(b.data().createdAt).getTime())) {
    const o = doc.data();
    if (o.status === 'cancelled') continue;
    contact = o;
    const paid = (o.amountPaid ?? 0) - (o.refundedAmount ?? 0);
    const balance = Math.max(0, (o.total ?? 0) - paid);
    invoiced += o.total ?? 0;
    paidTotal += paid;
    const due = o.dueDate ? toDate(o.dueDate).getTime() : toDate(o.createdAt).getTime();
    const late = Math.floor((now - due) / 86400000);
    if (balance > 0) {
      if (late <= 0) aging.current += balance;
      else if (late <= 30) aging.d30 += balance;
      else if (late <= 60) aging.d60 += balance;
      else aging.d90 += balance;
    }
    rows.push([
      formatDate(toDate(o.createdAt)),
      String(o.invoiceNumber ?? o.orderNumber ?? doc.id),
      o.dueDate ? formatDate(toDate(o.dueDate)) : '—',
      formatMoney(o.total ?? 0),
      formatMoney(paid),
      formatMoney(balance),
    ]);
  }
  return [{
    title: 'Statement',
    number: `As at ${formatDate(new Date())}`,
    date: new Date(),
    meta: account.creditEnabled ? [['Terms', `${account.paymentTermsDays} days`], ['Credit limit', account.creditLimit ? formatMoney(account.creditLimit) : 'None']] : [],
    billTo: [account.companyName, contact.contactName, contact.contactPhone, contact.customerEmail, account.kraPin ? `KRA PIN: ${account.kraPin}` : ''].filter(Boolean),
    lines: [],
    table: {
      headers: ['Date', 'Invoice', 'Due', 'Amount', 'Paid', 'Balance'],
      widths: [80, 90, 80, 85, 82, 82],
      rows,
      alignRight: [3, 4, 5],
    },
    totals: [
      { label: 'Total invoiced', amount: invoiced },
      { label: 'Total paid', amount: paidTotal },
      { label: 'Current', amount: aging.current },
      { label: '1–30 days overdue', amount: aging.d30 },
      { label: '31–60 days overdue', amount: aging.d60 },
      { label: 'Over 60 days overdue', amount: aging.d90 },
      { label: 'Balance outstanding', amount: invoiced - paidTotal, bold: true },
    ],
    notes: [],
  }, `statement-${new Date().toISOString().slice(0, 10)}.pdf`];
}

/// Returns a PDF (base64) for an invoice, receipt, credit note, quote or
/// account statement. Customers get their own documents; staff get any.
export const getDocument = onCall({ memory: '512MiB' }, async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const kind = requireEnum(data, 'kind', ['invoice', 'receipt', 'creditNote', 'quote', 'statement']);
  const settings = await loadBusinessSettings();
  const id = kind === 'statement'
    ? (typeof data.id === 'string' && data.id ? data.id : caller.uid)
    : requireString(data, 'id', 'Document', 1, 128);
  const [spec, fileName] =
    kind === 'invoice' ? await invoiceSpec(id, caller, settings)
    : kind === 'receipt' ? await receiptSpec(id, caller, settings)
    : kind === 'creditNote' ? await creditNoteSpec(id, caller, settings)
    : kind === 'quote' ? await quoteSpec(id, caller, settings)
    : await statementSpec(id, caller);
  const pdf = await renderPdf(settings, spec);
  return { fileName, base64: pdf.toString('base64') };
});
