import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { DATABASE_ID, db } from '../core/app';
import { requireRole } from '../core/authz';
import { asObject, requireEnum, requireString } from '../core/validate';
import { callProvider } from '../payments/http_util';
import { maskSecret } from '../payments/gateway_config';
import { loadBusinessSettings } from '../settings/business_settings';
import {
  EtimsLineInput,
  buildSalePayload,
  etimsQrUrl,
  paymentTypeFor,
} from './etims_payload';

/// Integrations/etims is public status; IntegrationSecrets/etims holds the
/// KRA device credentials and cmcKey (no client can read it).
const publicRef = db.collection('Integrations').doc('etims');
const secretRef = db.collection('IntegrationSecrets').doc('etims');

export const ETIMS_FIELDS = [
  { key: 'tin', label: 'KRA PIN (TIN)', secret: false, required: true, help: 'Your business KRA PIN, e.g. P051234567X.' },
  { key: 'bhfId', label: 'Branch ID', secret: false, required: true, help: '00 for the head office unless KRA assigned another.' },
  { key: 'dvcSrlNo', label: 'Device serial number', secret: false, required: true, help: 'The OSCU device serial from your eTIMS registration.' },
  { key: 'itemCode', label: 'Registered item code', secret: false, required: true, help: 'Item code of a "Branded merchandise" item registered in eTIMS (e.g. KE1NTXU0000001). All lines are reported under it.' },
  { key: 'itemClassCode', label: 'Item classification code', secret: false, required: true, help: '10-digit UNSPSC code chosen when registering that item.' },
] as const;

interface EtimsConfig {
  mode: 'sandbox' | 'live';
  enabled: boolean;
  autoSubmit: boolean;
  values: Record<string, string>;
  cmcKey?: string;
}

function baseUrl(mode: string): string {
  return mode === 'live'
    ? 'https://etims-api.kra.go.ke/etims-api'
    : 'https://etims-api-sbx.kra.go.ke/etims-api';
}

async function loadConfig(): Promise<EtimsConfig> {
  const [pub, sec] = await Promise.all([publicRef.get(), secretRef.get()]);
  const p = pub.data() ?? {};
  const s = sec.data() ?? {};
  return {
    mode: p.mode === 'live' ? 'live' : 'sandbox',
    enabled: p.enabled === true,
    autoSubmit: p.autoSubmit === true,
    values: (s.values ?? {}) as Record<string, string>,
    cmcKey: s.cmcKey as string | undefined,
  };
}

function isComplete(values: Record<string, string>): boolean {
  return ETIMS_FIELDS.every((f) => !f.required || (values[f.key] ?? '').trim());
}

async function kra<T = Record<string, any>>(
  config: EtimsConfig,
  path: string,
  body: unknown,
  withKey = true,
): Promise<T> {
  const res = await callProvider<Record<string, any>>(`${baseUrl(config.mode)}${path}`, {
    headers: {
      tin: config.values.tin,
      bhfId: config.values.bhfId,
      ...(withKey && config.cmcKey ? { cmcKey: config.cmcKey } : {}),
    },
    json: body,
    timeoutMs: 30000,
  });
  // resultCd is a string; '000' is success (never coerce to a number).
  if (String(res.resultCd) !== '000') {
    throw new Error(`KRA ${res.resultCd}: ${res.resultMsg ?? 'request rejected'}`);
  }
  return res as T;
}

export const adminGetEtims = onCall(async (request) => {
  await requireRole(request, ['admin']);
  const [config, pub] = await Promise.all([loadConfig(), publicRef.get()]);
  return {
    mode: config.mode,
    enabled: config.enabled,
    autoSubmit: config.autoSubmit,
    configured: isComplete(config.values),
    initialized: !!config.cmcKey,
    lastTest: pub.data()?.lastTest ?? null,
    fields: ETIMS_FIELDS.map((f) => ({
      ...f,
      value: f.secret ? '' : config.values[f.key] ?? '',
      hasValue: !!config.values[f.key],
      preview: f.secret ? maskSecret(config.values[f.key] ?? '') : config.values[f.key] ?? '',
      options: null,
    })),
  };
});

export const adminSaveEtims = onCall(async (request) => {
  const caller = await requireRole(request, ['admin']);
  const data = asObject(request.data);
  const mode = requireEnum(data, 'mode', ['sandbox', 'live'], 'sandbox');
  const incoming = asObject(data.values ?? {});
  const current = await loadConfig();
  const values = { ...current.values };
  for (const f of ETIMS_FIELDS) {
    const v = incoming[f.key];
    if (typeof v === 'string' && v.trim()) values[f.key] = v.trim().slice(0, 100);
  }
  const configured = isComplete(values);
  const enabled = data.enabled === true && configured && !!current.cmcKey;
  // Changing mode or device identity invalidates the old cmcKey.
  const identityChanged =
    mode !== current.mode ||
    values.tin !== current.values.tin ||
    values.bhfId !== current.values.bhfId ||
    values.dvcSrlNo !== current.values.dvcSrlNo;
  await secretRef.set({
    values,
    ...(identityChanged ? { cmcKey: FieldValue.delete() } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await publicRef.set({
    mode,
    enabled: identityChanged ? false : enabled,
    autoSubmit: data.autoSubmit === true,
    configured,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: caller.uid,
  }, { merge: true });
  return { configured, enabled: identityChanged ? false : enabled, needsInitialize: identityChanged || !current.cmcKey };
});

/// One-time OSCU device initialization — gets the cmcKey every later call
/// needs. Doubles as "Test connection".
export const adminInitEtims = onCall(async (request) => {
  await requireRole(request, ['admin']);
  const config = await loadConfig();
  if (!isComplete(config.values)) {
    throw new HttpsError('failed-precondition', 'Save all eTIMS fields first.');
  }
  try {
    const res = await kra<Record<string, any>>(config, '/selectInitOsdcInfo', {
      tin: config.values.tin,
      bhfId: config.values.bhfId,
      dvcSrlNo: config.values.dvcSrlNo,
    }, false);
    const info = res.data?.info ?? {};
    if (!info.cmcKey) throw new Error('KRA did not return a communication key.');
    await secretRef.set({ cmcKey: info.cmcKey, sdcId: info.sdcId ?? null, mrcNo: info.mrcNo ?? null }, { merge: true });
    const message = `Device initialised for ${info.tradeNm ?? config.values.tin} (${info.bhfNm ?? 'branch ' + config.values.bhfId}).`;
    await publicRef.set({ lastTest: { ok: true, message, at: FieldValue.serverTimestamp() } }, { merge: true });
    return { ok: true, message };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await publicRef.set({ lastTest: { ok: false, message, at: FieldValue.serverTimestamp() } }, { merge: true });
    return { ok: false, message };
  }
});

/// Claims the document for submission and assigns its eTIMS invoice
/// number. KRA requires gapless numbers, so a failed attempt keeps its
/// number for the retry, and a concurrent attempt (auto trigger + a staff
/// click) is refused rather than double-reported.
async function claimInvoiceNo(target: FirebaseFirestore.DocumentReference): Promise<number | null> {
  const counterRef = db.collection('Counters').doc('etimsInvoices');
  return db.runTransaction(async (tx) => {
    const [doc, counter] = await Promise.all([tx.get(target), tx.get(counterRef)]);
    const e = doc.data()?.etims;
    if (e?.status === 'submitted') return null;
    const startedAt = e?.startedAt?.toMillis?.() ?? 0;
    if (e?.status === 'submitting' && Date.now() - startedAt < 120000) {
      throw new HttpsError('aborted', 'This invoice is already being submitted to KRA.');
    }
    let invcNo = typeof e?.invcNo === 'number' ? e.invcNo : 0;
    if (!invcNo) {
      invcNo = ((counter.data()?.value as number | undefined) ?? 0) + 1;
      tx.set(counterRef, { value: invcNo, updatedAt: FieldValue.serverTimestamp() });
    }
    tx.update(target, { etims: { status: 'submitting', invcNo, startedAt: FieldValue.serverTimestamp() } });
    return invcNo;
  });
}

/// Submits an order's invoice (or a refund's credit note) to KRA and stores
/// the signed receipt data used for the invoice QR code.
async function submit(orderId: string, creditNote?: { refundId: string }): Promise<Record<string, unknown>> {
  const [config, settings] = await Promise.all([loadConfig(), loadBusinessSettings()]);
  if (!config.enabled || !config.cmcKey) {
    throw new HttpsError('failed-precondition', 'eTIMS is not set up. An admin must configure and initialise it first.');
  }
  const orderRef = db.collection('Orders').doc(orderId);
  const order = (await orderRef.get()).data();
  if (!order) throw new HttpsError('not-found', 'Order not found.');

  const rate = settings.vatEnabled ? settings.vatRate : 0;
  const inclusive = (v: number) => (settings.pricesIncludeVat || rate === 0 ? v : v * (1 + rate));
  let lines: EtimsLineInput[];
  let discount: number;
  let target: FirebaseFirestore.DocumentReference = orderRef;
  let original: number | undefined;

  if (creditNote) {
    target = db.collection('Refunds').doc(creditNote.refundId);
    const refund = (await target.get()).data();
    if (!refund) throw new HttpsError('not-found', 'Refund not found.');

    original = order.etims?.invcNo;
    if (!original) throw new HttpsError('failed-precondition', 'The original invoice was never submitted to eTIMS.');
    lines = [{ name: `Refund on ${order.invoiceNumber ?? order.orderNumber}`, quantity: 1, lineTotal: refund.amount }];
    discount = 0;
  } else {
    lines = (order.items as Array<Record<string, any>>).map((i) => ({
      name: String(i.name),
      quantity: Number(i.quantity) || 1,
      lineTotal: inclusive(Number(i.lineTotal ?? i.unitPrice * i.quantity)),
    }));
    if ((order.deliveryFee ?? 0) > 0) {
      lines.push({ name: 'Delivery', quantity: 1, lineTotal: inclusive(order.deliveryFee) });
    }
    discount = inclusive(order.discountAmount ?? 0);
  }

  const invcNo = await claimInvoiceNo(target);
  if (invcNo === null) {
    return ((await target.get()).data()?.etims ?? {}) as Record<string, unknown>;
  }
  const payload = buildSalePayload({
    tin: config.values.tin,
    bhfId: config.values.bhfId,
    invcNo,
    orgInvcNo: original,
    trdInvcNo: creditNote ? `CN-${creditNote.refundId.slice(0, 10)}` : String(order.invoiceNumber ?? order.orderNumber),
    kind: creditNote ? 'creditNote' : 'sale',
    customerName: order.customerCompany || order.contactName || 'Customer',
    customerTin: order.customerKraPin,
    salesDate: order.createdAt?.toDate?.() ?? new Date(),
    confirmDate: new Date(),
    paymentTypeCode: paymentTypeFor(undefined, order.paymentPlan === 'credit'),
    vatRegistered: settings.vatEnabled,
    itemCode: config.values.itemCode,
    itemClassCode: config.values.itemClassCode,
    lines,
    discount,
    businessName: settings.businessName,
    address: settings.physicalAddress,
  });

  try {
    const res = await kra<Record<string, any>>(config, '/saveTrnsSalesOsdc', payload);
    const d = res.data ?? {};
    const secret = (await secretRef.get()).data() ?? {};
    const etims = {
      status: 'submitted',
      invcNo,
      rcptNo: d.curRcptNo ?? d.rcptNo ?? null,
      totRcptNo: d.totRcptNo ?? null,
      rcptSign: d.rcptSign ?? null,
      intrlData: d.intrlData ?? null,
      sdcDateTime: d.sdcDateTime ?? d.vsdcRcptPbctDate ?? null,
      sdcId: secret.sdcId ?? null,
      mrcNo: secret.mrcNo ?? null,
      qrUrl: d.rcptSign ? etimsQrUrl(config.mode === 'live', config.values.tin, config.values.bhfId, d.rcptSign) : null,
      mode: config.mode,
      submittedAt: FieldValue.serverTimestamp(),
    };
    await target.update({ etims });
    logger.info('[etims] submitted', { orderId, invcNo, creditNote: !!creditNote });
    return etims;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await target.update({ etims: { status: 'failed', invcNo, error: message.slice(0, 300), mode: config.mode, submittedAt: FieldValue.serverTimestamp() } });
    logger.error('[etims] submission failed', { orderId, invcNo, message });
    throw new HttpsError('unavailable', `KRA rejected the invoice: ${message}`);
  }
}

export const submitEtimsInvoice = onCall(async (request) => {
  await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const refundId = typeof data.refundId === 'string' && data.refundId ? data.refundId : undefined;
  return submit(orderId, refundId ? { refundId } : undefined);
});

/// Auto-submit: when eTIMS auto-submit is on, an order is reported to KRA
/// the moment it becomes fully paid (or is confirmed on credit terms).
export const etimsOnOrderUpdate = onDocumentUpdated(
  { document: 'Orders/{orderId}', database: DATABASE_ID },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || after.etims?.status === 'submitted') return;
    const becamePaid = before.paymentStatus !== 'paid' && after.paymentStatus === 'paid';
    const creditConfirmed =
      after.paymentPlan === 'credit' && before.status === 'pendingReview' && after.status === 'confirmed';
    if (!becamePaid && !creditConfirmed) return;
    const config = await loadConfig();
    if (!config.enabled || !config.autoSubmit) return;
    try {
      await submit(event.params.orderId);
    } catch (error) {
      logger.warn('[etims] auto-submit failed (staff can retry from the order)', { orderId: event.params.orderId, error: String(error) });
    }
  },
);

/// Credit notes follow refunds automatically for orders already on eTIMS.
export const etimsOnRefund = onDocumentCreated(
  { document: 'Refunds/{refundId}', database: DATABASE_ID },
  async (event) => {
    const refund = event.data?.data();
    if (!refund || !(refund.amount > 0)) return;
    const [config, order] = await Promise.all([
      loadConfig(),
      db.collection('Orders').doc(refund.orderId).get(),
    ]);
    if (!config.enabled || order.data()?.etims?.status !== 'submitted') return;
    try {
      await submit(refund.orderId, { refundId: event.params.refundId });
    } catch (error) {
      logger.warn('[etims] credit note failed', { refundId: event.params.refundId, error: String(error) });
    }
  },
);
