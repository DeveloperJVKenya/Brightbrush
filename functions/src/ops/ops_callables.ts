import { timingSafeEqual } from 'node:crypto';

import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { isStaff, loadCaller, requireRole } from '../core/authz';
import { rateLimit } from '../platform/platform';
import { asObject, optionalString, requireString } from '../core/validate';

export const QC_CHECKLIST = [
  'Items and quantities match the order',
  'Sizes and colours correct',
  'Placement matches the approved proof',
  'Stitching / print quality (no gaps, bleeding or puckering)',
  'Clean — no loose threads, stains or marks',
  'Folded, packed and labelled',
] as const;

const storageUrls = (v: unknown, max: number) =>
  (Array.isArray(v) ? v : [])
    .filter((u): u is string => typeof u === 'string' && u.startsWith('https://firebasestorage.googleapis.com/') && u.length <= 1000)
    .slice(0, max);

/// Quality check before handover. Passing moves the order to "ready for
/// delivery" (firestore.rules refuse that move unless qcStatus is passed);
/// failing sends it back to production with the reasons recorded.
export const recordQualityCheck = onCall(async (request) => {
  const caller = await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const notes = optionalString(data, 'notes', 'Notes', 1000);
  const checks = asObject(data.checks ?? {});
  const results = QC_CHECKLIST.map((label, i) => ({ label, ok: checks[String(i)] === true }));
  const passed = data.passed === true && results.every((r) => r.ok);
  if (data.passed === true && !passed) {
    throw new HttpsError('failed-precondition', 'Tick every checklist item to pass the order.');
  }
  if (!passed && !notes) {
    throw new HttpsError('invalid-argument', 'Say what needs fixing.');
  }
  const orderRef = db.collection('Orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const o = (await tx.get(orderRef)).data();
    if (!o) throw new HttpsError('not-found', 'Order not found.');
    if (!['inProduction', 'qualityCheck'].includes(o.status)) {
      throw new HttpsError('failed-precondition', 'Only orders in production can be quality-checked.');
    }
    tx.create(orderRef.collection('QualityChecks').doc(), {
      passed,
      results,
      notes,
      photoUrls: storageUrls(data.photoUrls, 6),
      checkedBy: caller.uid,
      at: FieldValue.serverTimestamp(),
    });
    tx.update(orderRef, {
      qcStatus: passed ? 'passed' : 'failed',
      status: passed ? 'readyForDelivery' : 'inProduction',
      lastUpdatedBy: caller.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('ProductionJobs').doc(orderId), {
      stage: passed ? 'done' : 'rework',
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: caller.uid,
    }, { merge: true });
  });
  logger.info('[qc]', { orderId, passed, by: caller.uid });
  return { passed };
});

function codesMatch(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

/// Completes a delivery (or an in-store pickup) with proof: the customer's
/// secret 4-digit code, or — if they can't produce it — a photo of the
/// handover plus the recipient's signature. Delivery staff can no longer
/// mark orders delivered without one of these (firestore.rules).
export const completeDelivery = onCall(async (request) => {
  const caller = await loadCaller(request);
  await rateLimit(`completeDelivery_${caller.uid}`, 30, 600);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const recipientName = requireString(data, 'recipientName', 'Recipient name', 2, 80);
  const code = typeof data.code === 'string' ? data.code.trim() : '';
  const photoUrl = storageUrls([data.photoUrl], 1)[0];
  const signatureUrl = storageUrls([data.signatureUrl], 1)[0];
  const lat = typeof data.lat === 'number' ? data.lat : null;
  const lng = typeof data.lng === 'number' ? data.lng : null;

  const orderRef = db.collection('Orders').doc(orderId);
  const [orderSnap, secretSnap] = await Promise.all([
    orderRef.get(),
    db.collection('OrderSecrets').doc(orderId).get(),
  ]);
  const o = orderSnap.data();
  if (!o) throw new HttpsError('not-found', 'Order not found.');
  const manager = isStaff(caller.role, ['systemManager', 'admin']);
  const isPickup = o.deliveryMethod === 'pickup';
  if (isPickup) {
    if (!manager) throw new HttpsError('permission-denied', 'Pickups are handed over by store staff.');
    if (!['readyForDelivery', 'outForDelivery'].includes(o.status)) {
      throw new HttpsError('failed-precondition', 'This order isn\'t ready for collection yet.');
    }
  } else {
    if (!manager && !(caller.role === 'deliveryStaff' && o.assignedStaffId === caller.uid)) {
      throw new HttpsError('permission-denied', 'Only the assigned driver can complete this delivery.');
    }
    if (o.status !== 'outForDelivery') {
      throw new HttpsError('failed-precondition', 'This order isn\'t out for delivery.');
    }
  }

  const expected = String(secretSnap.data()?.deliveryCode ?? '');
  const codeVerified = !!code && !!expected && codesMatch(code, expected);
  if (code && !codeVerified) {
    throw new HttpsError('permission-denied', 'That code is wrong. Ask the customer to check their order page.');
  }
  if (!codeVerified && !(photoUrl && signatureUrl)) {
    throw new HttpsError(
      'failed-precondition',
      'Enter the customer\'s delivery code, or take a handover photo and capture a signature.',
    );
  }

  await orderRef.update({
    status: 'completed',
    proofOfDelivery: {
      recipientName,
      codeVerified,
      ...(photoUrl ? { photoUrl } : {}),
      ...(signatureUrl ? { signatureUrl } : {}),
      ...(lat !== null && lng !== null ? { lat, lng } : {}),
      by: caller.uid,
      at: FieldValue.serverTimestamp(),
    },
    lastUpdatedBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });
  logger.info('[pod] delivered', { orderId, codeVerified, by: caller.uid });
  return { codeVerified };
});

interface PoLine {
  materialId: string;
  name: string;
  unit: string;
  quantity: number;
  unitCost: number;
}

function readPoLines(raw: unknown): PoLine[] {
  const lines = (Array.isArray(raw) ? raw : []).map((l: any) => ({
    materialId: String(l?.materialId ?? ''),
    name: String(l?.name ?? '').slice(0, 80),
    unit: String(l?.unit ?? '').slice(0, 20),
    quantity: Math.floor(Number(l?.quantity) || 0),
    unitCost: Math.max(0, Number(l?.unitCost) || 0),
  }));
  if (lines.length === 0 || lines.length > 50 || lines.some((l) => !l.materialId || l.quantity <= 0)) {
    throw new HttpsError('invalid-argument', 'Add at least one material with a quantity.');
  }
  return lines;
}

/// Creates a numbered purchase order (PO-000001) for a supplier.
export const createPurchaseOrder = onCall(async (request) => {
  const caller = await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const supplierName = requireString(data, 'supplierName', 'Supplier', 2, 120);
  const supplierContact = optionalString(data, 'supplierContact', 'Supplier contact', 120);
  const notes = optionalString(data, 'notes', 'Notes', 1000);
  const lines = readPoLines(data.lines);
  const expected = typeof data.expectedDate === 'string' ? new Date(data.expectedDate) : null;
  const ref = db.collection('PurchaseOrders').doc();
  const number = await db.runTransaction(async (tx) => {
    const counter = db.collection('Counters').doc('purchaseOrders');
    const seq = (((await tx.get(counter)).data()?.value as number | undefined) ?? 0) + 1;
    const poNumber = `PO-${String(seq).padStart(6, '0')}`;
    tx.set(counter, { value: seq, updatedAt: FieldValue.serverTimestamp() });
    tx.create(ref, {
      poNumber,
      supplierName,
      supplierContact,
      notes,
      lines,
      total: Math.round(lines.reduce((s, l) => s + l.quantity * l.unitCost, 0)),
      status: 'draft',
      ...(expected && !isNaN(expected.getTime()) ? { expectedDate: expected } : {}),
      createdBy: caller.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: caller.uid,
    });
    return poNumber;
  });
  return { id: ref.id, poNumber: number };
});

/// Receives a PO: adds each line to stock (with a movement log), marks it
/// received, and optionally books the cost as a materials expense.
export const receivePurchaseOrder = onCall(async (request) => {
  const caller = await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const poId = requireString(data, 'poId', 'Purchase order', 1, 100);
  const logExpense = data.logExpense === true && isStaff(caller.role, ['admin']);
  const poRef = db.collection('PurchaseOrders').doc(poId);
  const total = await db.runTransaction(async (tx) => {
    const po = (await tx.get(poRef)).data();
    if (!po) throw new HttpsError('not-found', 'Purchase order not found.');
    if (!['draft', 'sent'].includes(po.status)) {
      throw new HttpsError('failed-precondition', `This purchase order is already ${po.status}.`);
    }
    const lines = po.lines as PoLine[];
    const refs = lines.map((l) => db.collection('InventoryMaterials').doc(l.materialId));
    const snaps = await tx.getAll(...refs);
    snaps.forEach((snap, i) => {
      if (!snap.exists) return;
      tx.update(refs[i], {
        quantityOnHand: FieldValue.increment(lines[i].quantity),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(db.collection('InventoryMovements').doc(), {
        materialId: refs[i].id,
        materialName: lines[i].name,
        change: lines[i].quantity,
        shortfall: 0,
        reason: 'purchaseReceived',
        purchaseOrderId: poId,
        poNumber: po.poNumber,
        at: FieldValue.serverTimestamp(),
      });
    });
    tx.update(poRef, {
      status: 'received',
      receivedAt: FieldValue.serverTimestamp(),
      receivedBy: caller.uid,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: caller.uid,
    });
    if (logExpense && po.total > 0) {
      tx.create(db.collection('Expenses').doc(), {
        category: 'materials',
        amount: po.total,
        note: `${po.poNumber} · ${po.supplierName}`.slice(0, 1000),
        date: FieldValue.serverTimestamp(),
        createdBy: caller.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return po.total as number;
  });
  logger.info('[po] received', { poId, total, logExpense });
  return { received: true };
});
