import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { DATABASE_ID, db } from '../core/app';
import { writeAudit } from './audit';
import { materialNeeds, parseBom } from './materials';

/// Order fields whose changes appear on the order's timeline.
const TRACKED = [
  'status',
  'paymentStatus',
  'amountPaid',
  'refundedAmount',
  'assignedStaffId',
  'proofStatus',
  'qcStatus',
  'etims.status',
  'overdue',
] as const;

export interface OrderChange {
  field: string;
  from: unknown;
  to: unknown;
}

function read(d: Record<string, any>, path: string): unknown {
  return path.split('.').reduce<any>((v, k) => (v == null ? undefined : v[k]), d);
}

/// Pure: which tracked fields changed between two versions of an order.
export function diffOrder(before: Record<string, any>, after: Record<string, any>): OrderChange[] {
  const out: OrderChange[] = [];
  for (const field of TRACKED) {
    const a = read(before, field) ?? null;
    const b = read(after, field) ?? null;
    if (JSON.stringify(a) !== JSON.stringify(b)) out.push({ field, from: a, to: b });
  }
  return out;
}

const PRODUCTION_STAGES = ['confirmed', 'awaitingProof', 'inProduction', 'qualityCheck'];

/// One trigger for every order change:
///  • timeline events (Orders/{id}/Events) with who made the change,
///  • audit entries for staff-made status/payment/assignment changes,
///  • a production job card the first time an order is confirmed,
///  • stock deduction when production starts, restock if cancelled after.
export const onOrderChanged = onDocumentUpdated(
  { document: 'Orders/{orderId}', database: DATABASE_ID },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const orderId = event.params.orderId as string;
    const orderRef = db.collection('Orders').doc(orderId);
    const changes = diffOrder(before, after);
    const actor = String(after.lastUpdatedBy ?? 'system');

    if (changes.length > 0) {
      const batch = db.batch();
      for (const c of changes) {
        batch.create(orderRef.collection('Events').doc(), {
          field: c.field,
          from: c.from,
          to: c.to,
          by: actor,
          at: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      const staffish = changes.filter((c) => ['status', 'paymentStatus', 'assignedStaffId'].includes(c.field));
      if (staffish.length > 0 && !actor.startsWith('system') && actor !== after.customerId) {
        await writeAudit({
          type: 'order.updated',
          entity: 'order',
          entityId: orderId,
          summary: `${after.orderNumber ?? orderId}: ${staffish.map((c) => `${c.field} ${c.from ?? '—'} → ${c.to ?? '—'}`).join('; ')}`,
          actor,
          changes: Object.fromEntries(staffish.map((c) => [c.field, { from: c.from, to: c.to }])),
        });
      }
    }

    // Production job card, created once when the order enters production flow.
    if (PRODUCTION_STAGES.includes(after.status) && !PRODUCTION_STAGES.includes(before.status)) {
      const jobRef = db.collection('ProductionJobs').doc(orderId);
      await jobRef.create({
        orderId,
        orderNumber: after.orderNumber ?? orderId,
        customerName: after.customerCompany || after.contactName || '',
        itemsSummary: (after.items ?? []).map((i: any) => `${i.quantity}× ${i.name}`).join(', ').slice(0, 500),
        stage: 'queued',
        priority: 'normal',
        machineId: null,
        machineName: '',
        operatorName: '',
        scheduledDate: null,
        estimatedMinutes: 0,
        dueDate: after.promisedDate ?? null,
        notes: '',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: 'system:orderConfirmed',
      }).catch((error) => {
        // Already exists (e.g. order went back and forth) — nothing to do.
        if (!String(error).includes('ALREADY_EXISTS')) throw error;
      });
    }

    if (after.status === 'inProduction' && before.status !== 'inProduction' && after.materialsDeducted !== true) {
      await adjustStock(orderId, after, -1);
    }
    if (after.status === 'cancelled' && before.status !== 'cancelled' && after.materialsDeducted === true) {
      await adjustStock(orderId, after, +1);
    }
    if (['completed', 'cancelled'].includes(after.status) && after.status !== before.status) {
      await db.collection('ProductionJobs').doc(orderId).set(
        { stage: after.status === 'completed' ? 'done' : 'cancelled', updatedAt: FieldValue.serverTimestamp(), updatedBy: 'system:order' },
        { merge: true },
      );
    }
  },
);

/// Deducts (direction -1) or restores (+1) the order's bill of materials,
/// idempotently via the order's materialsDeducted flag, logging every
/// movement. Stock never goes below zero; shortfalls are recorded.
async function adjustStock(orderId: string, order: Record<string, any>, direction: -1 | 1): Promise<void> {
  const itemIds = [...new Set((order.items ?? []).map((i: any) => String(i.itemId)))] as string[];
  if (itemIds.length === 0) return;
  const itemSnaps = await db.getAll(...itemIds.map((id) => db.collection('CatalogItems').doc(id)));
  const boms = new Map(itemSnaps.map((s) => [s.id, parseBom(s.data()?.materials)]));
  const needs =
    direction === -1
      ? materialNeeds(
          (order.items ?? []).map((i: any) => ({ itemId: String(i.itemId), kind: String(i.kind ?? 'item'), quantity: Number(i.quantity) || 0 })),
          boms,
        )
      : new Map<string, number>(Object.entries((order.materialsUsed ?? {}) as Record<string, number>));
  const orderRef = db.collection('Orders').doc(orderId);

  await db.runTransaction(async (tx) => {
    const fresh = (await tx.get(orderRef)).data() ?? {};
    const already = fresh.materialsDeducted === true;
    if ((direction === -1 && already) || (direction === 1 && !already)) return;
    const refs = [...needs.keys()].map((id) => db.collection('InventoryMaterials').doc(id));
    const snaps = refs.length ? await tx.getAll(...refs) : [];
    const used: Record<string, number> = {};
    snaps.forEach((snap, i) => {
      const m = snap.data();
      if (!m) return;
      const want = needs.get(refs[i].id) ?? 0;
      const onHand = Number(m.quantityOnHand) || 0;
      const change = direction === -1 ? -Math.min(want, onHand) : want;
      used[refs[i].id] = direction === -1 ? -change : 0;
      tx.update(refs[i], { quantityOnHand: onHand + change, updatedAt: FieldValue.serverTimestamp() });
      tx.create(db.collection('InventoryMovements').doc(), {
        materialId: refs[i].id,
        materialName: m.name ?? '',
        change,
        shortfall: direction === -1 ? Math.max(0, want - onHand) : 0,
        reason: direction === -1 ? 'orderProduction' : 'orderCancelled',
        orderId,
        orderNumber: order.orderNumber ?? orderId,
        at: FieldValue.serverTimestamp(),
      });
    });
    tx.update(orderRef, {
      materialsDeducted: direction === -1,
      materialsUsed: direction === -1 ? used : {},
      lastUpdatedBy: 'system:inventory',
    });
  });
  logger.info('[inventory] stock adjusted', { orderId, direction, materials: needs.size });
}
