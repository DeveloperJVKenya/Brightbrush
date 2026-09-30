import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';

import { DATABASE_ID, db } from '../core/app';

export interface AuditEntry {
  /// e.g. 'order.status', 'user.role', 'catalog.price', 'settings.business'
  type: string;
  entity: string;
  entityId: string;
  summary: string;
  /// uid, or 'system:<source>' for automated changes.
  actor: string;
  changes?: Record<string, { from: unknown; to: unknown }>;
}

/// AuditLog is admin-read-only and written exclusively here (firestore.rules
/// deny every client write), so entries can't be edited or deleted.
export async function writeAudit(entry: AuditEntry): Promise<void> {
  try {
    await db.collection('AuditLog').add({
      ...entry,
      changes: entry.changes ?? {},
      at: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error('[audit] write failed', { entry: entry.type, error: String(error) });
  }
}

const same = (a: unknown, b: unknown) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

/// Field-level diff restricted to [fields].
export function diffFields(
  before: Record<string, any> | undefined,
  after: Record<string, any> | undefined,
  fields: string[],
): Record<string, { from: unknown; to: unknown }> {
  const out: Record<string, { from: unknown; to: unknown }> = {};
  for (const f of fields) {
    const a = before?.[f];
    const b = after?.[f];
    if (!same(a, b)) out[f] = { from: a ?? null, to: b ?? null };
  }
  return out;
}

function actorOf(d: Record<string, any> | undefined): string {
  return String(d?.lastUpdatedBy ?? d?.updatedBy ?? d?.createdBy ?? d?.recordedBy ?? 'unknown');
}

/// Watches a collection and logs changes to [fields] (or create/delete).
function auditCollection(
  path: string,
  entity: string,
  fields: string[],
  describe: (id: string, d: Record<string, any>) => string,
) {
  return onDocumentWritten({ document: `${path}/{id}`, database: DATABASE_ID }, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const id = event.params.id as string;
    if (!before && after) {
      await writeAudit({ type: `${entity}.created`, entity, entityId: id, summary: `Created ${describe(id, after)}`, actor: actorOf(after) });
      return;
    }
    if (before && !after) {
      await writeAudit({ type: `${entity}.deleted`, entity, entityId: id, summary: `Deleted ${describe(id, before)}`, actor: 'unknown' });
      return;
    }
    const changes = diffFields(before, after, fields);
    if (Object.keys(changes).length === 0) return;
    await writeAudit({
      type: `${entity}.updated`,
      entity,
      entityId: id,
      summary: `${describe(id, after!)}: ${Object.keys(changes).join(', ')} changed`,
      actor: actorOf(after),
      changes,
    });
  });
}

export const auditUsers = auditCollection(
  'Users', 'user', ['role', 'disabled', 'dailyWage'],
  (id, d) => `user ${d.displayName ?? id}`,
);
export const auditCatalog = auditCollection(
  'CatalogItems', 'catalog', ['basePrice', 'priceTiers', 'moq', 'isActive', 'name'],
  (id, d) => `item "${d.name ?? id}"`,
);
export const auditSettings = auditCollection(
  'Settings', 'settings',
  ['vatEnabled', 'vatRate', 'pricesIncludeVat', 'deliveryFlatFee', 'deliveryZones', 'allowDeposit', 'depositPercent', 'kraPin', 'methods', 'personalisationFee'],
  (id) => `${id} settings`,
);
export const auditGateways = auditCollection(
  'PaymentGateways', 'gateway', ['enabled', 'mode', 'configured'],
  (id) => `payment gateway ${id}`,
);
export const auditAccounts = auditCollection(
  'CustomerAccounts', 'account', ['discountPercent', 'creditEnabled', 'creditLimit', 'paymentTermsDays', 'companyName'],
  (id, d) => `business account ${d.companyName || id}`,
);
export const auditCoupons = auditCollection(
  'Coupons', 'coupon', ['value', 'type', 'active', 'usageLimit', 'validTo'],
  (id) => `promo code ${id}`,
);

export const auditRefunds = onDocumentCreated({ document: 'Refunds/{id}', database: DATABASE_ID }, async (event) => {
  const r = event.data?.data();
  if (!r) return;
  await writeAudit({
    type: 'refund.issued',
    entity: 'order',
    entityId: r.orderId,
    summary: `Refund ${r.creditNoteNumber}: KES ${r.amount} on ${r.orderNumber}${r.cancelled ? ' (order cancelled)' : ''} — ${r.reason}`,
    actor: String(r.createdBy ?? 'unknown'),
  });
});

export const auditManualPayments = onDocumentCreated({ document: 'Payments/{id}', database: DATABASE_ID }, async (event) => {
  const p = event.data?.data();
  if (!p || p.gateway !== 'manual') return;
  await writeAudit({
    type: 'payment.recorded',
    entity: 'order',
    entityId: p.orderId,
    summary: `Recorded ${p.method} payment of KES ${p.amount} on ${p.orderNumber}${p.receipt ? ` (ref ${p.receipt})` : ''}`,
    actor: String(p.recordedBy ?? 'unknown'),
  });
});
