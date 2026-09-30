import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { DATABASE_ID, db } from '../core/app';
import { requireRole } from '../core/authz';

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------

/// Fixed-window limiter: at most [max] calls per [windowSeconds] per key.
/// Throws a friendly resource-exhausted error when exceeded.
export async function rateLimit(key: string, max: number, windowSeconds: number): Promise<void> {
  const ref = db.collection('RateLimits').doc(key.replace(/[/]/g, '_').slice(0, 300));
  const now = Date.now();
  const allowed = await db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    const windowStart = (d?.windowStart as number | undefined) ?? 0;
    const count = (d?.count as number | undefined) ?? 0;
    if (now - windowStart > windowSeconds * 1000) {
      tx.set(ref, { windowStart: now, count: 1, expiresAt: Timestamp.fromMillis(now + windowSeconds * 2000) });
      return true;
    }
    if (count >= max) return false;
    tx.update(ref, { count: count + 1 });
    return true;
  });
  if (!allowed) {
    throw new HttpsError('resource-exhausted', 'Too many attempts. Please wait a moment and try again.');
  }
}

// ---------------------------------------------------------------------------
// Server-side statistics (dashboards read these instead of every order)
// ---------------------------------------------------------------------------

/// yyyy-MM-dd in Nairobi time.
export function nairobiDay(ms: number): string {
  return new Date(ms + 3 * 3600 * 1000).toISOString().slice(0, 10);
}

export interface StatDelta {
  day: string;
  fields: Record<string, number>;
}

/// Pure: the counter changes an order write implies.
export function statDeltas(
  before: Record<string, any> | undefined,
  after: Record<string, any> | undefined,
  nowMs: number,
): { daily: StatDelta[]; totals: Record<string, number> } {
  const daily: StatDelta[] = [];
  const totals: Record<string, number> = {};
  const add = (bag: Record<string, number>, k: string, v: number) => {
    if (v) bag[k] = (bag[k] ?? 0) + v;
  };
  const today = nairobiDay(nowMs);
  const todayBag: Record<string, number> = {};

  if (!before && after) {
    const created = (after.createdAt as Timestamp | undefined)?.toMillis() ?? nowMs;
    daily.push({ day: nairobiDay(created), fields: { ordersPlaced: 1, orderValue: after.total ?? 0 } });
    add(totals, 'ordersPlaced', 1);
    add(totals, 'orderValue', after.total ?? 0);
    add(totals, `status_${after.status}`, 1);
  }
  if (before && after) {
    if (before.status !== after.status) {
      add(totals, `status_${before.status}`, -1);
      add(totals, `status_${after.status}`, 1);
      if (after.status === 'completed') {
        add(todayBag, 'ordersCompleted', 1);
        add(totals, 'ordersCompleted', 1);
      }
      if (after.status === 'cancelled') {
        add(todayBag, 'ordersCancelled', 1);
        add(totals, 'ordersCancelled', 1);
      }
    }
    const paid = (after.amountPaid ?? 0) - (before.amountPaid ?? 0);
    add(todayBag, 'collected', paid);
    add(totals, 'collected', paid);
    const refunded = (after.refundedAmount ?? 0) - (before.refundedAmount ?? 0);
    add(todayBag, 'refunded', refunded);
    add(totals, 'refunded', refunded);
  }
  if (Object.keys(todayBag).length) daily.push({ day: today, fields: todayBag });
  return { daily, totals };
}

export const aggregateOrderStats = onDocumentWritten(
  { document: 'Orders/{orderId}', database: DATABASE_ID },
  async (event) => {
    const { daily, totals } = statDeltas(event.data?.before.data(), event.data?.after.data(), Date.now());
    if (daily.length === 0 && Object.keys(totals).length === 0) return;
    const batch = db.batch();
    const inc = (f: Record<string, number>) =>
      Object.fromEntries(Object.entries(f).map(([k, v]) => [k, FieldValue.increment(v)]));
    for (const d of daily) {
      batch.set(db.collection('Stats').doc(`daily-${d.day}`), { day: d.day, ...inc(d.fields) }, { merge: true });
    }
    if (Object.keys(totals).length) {
      batch.set(db.collection('Stats').doc('totals'), { ...inc(totals), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    await batch.commit();
  },
);

/// Pure: the counters rebuilt from scratch over a set of orders. Orders
/// placed are booked on their creation day; money and completions (whose
/// exact day isn't stored) on the day the order was last updated.
export function rebuildStats(orders: Array<Record<string, any>>): {
  totals: Record<string, number>;
  daily: Record<string, Record<string, number>>;
} {
  const totals: Record<string, number> = {};
  const daily: Record<string, Record<string, number>> = {};
  const add = (bag: Record<string, number>, k: string, v: number) => {
    if (v) bag[k] = (bag[k] ?? 0) + v;
  };
  const dayOf = (t: unknown) => {
    const ms = (t as Timestamp | undefined)?.toMillis?.();
    return ms ? nairobiDay(ms) : null;
  };
  const bag = (day: string | null) => (day ? (daily[day] ??= {}) : {});
  for (const o of orders) {
    const created = dayOf(o.createdAt);
    const touched = dayOf(o.updatedAt) ?? created;
    add(totals, 'ordersPlaced', 1);
    add(totals, 'orderValue', o.total ?? 0);
    add(totals, `status_${o.status}`, 1);
    add(bag(created), 'ordersPlaced', 1);
    add(bag(created), 'orderValue', o.total ?? 0);
    add(totals, 'collected', o.amountPaid ?? 0);
    add(bag(touched), 'collected', o.amountPaid ?? 0);
    add(totals, 'refunded', o.refundedAmount ?? 0);
    add(bag(touched), 'refunded', o.refundedAmount ?? 0);
    if (o.status === 'completed') {
      add(totals, 'ordersCompleted', 1);
      add(bag(touched), 'ordersCompleted', 1);
    }
    if (o.status === 'cancelled') {
      add(totals, 'ordersCancelled', 1);
      add(bag(touched), 'ordersCancelled', 1);
    }
  }
  return { totals, daily };
}

/// Admin: recount every Stats document from the orders themselves — run
/// once after first deploy (orders placed before the counters existed),
/// or any time the numbers look off.
export const rebuildOrderStats = onCall({ timeoutSeconds: 540, memory: '1GiB' }, async (request) => {
  const caller = await requireRole(request, ['admin']);
  const orders: Array<Record<string, any>> = [];
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db.collection('Orders').orderBy('__name__').limit(1000);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    page.docs.forEach((d) => orders.push(d.data()));
    if (page.size < 1000) break;
    last = page.docs[page.docs.length - 1];
  }
  const { totals, daily } = rebuildStats(orders);
  const old = await db.collection('Stats').listDocuments();
  const writer = db.bulkWriter();
  old.forEach((ref) => writer.delete(ref));
  await writer.flush();
  for (const [day, fields] of Object.entries(daily)) {
    writer.set(db.collection('Stats').doc(`daily-${day}`), { day, ...fields });
  }
  writer.set(db.collection('Stats').doc('totals'), {
    ...totals,
    rebuiltAt: FieldValue.serverTimestamp(),
    rebuiltBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await writer.close();
  logger.info('[stats] rebuilt', { orders: orders.length, days: Object.keys(daily).length });
  return { orders: orders.length, days: Object.keys(daily).length };
});

// ---------------------------------------------------------------------------
// Search keywords (server-side search that doesn't depend on loaded data)
// ---------------------------------------------------------------------------

/// Pure: lowercase word tokens plus prefixes (from 2 chars) for
/// type-ahead, capped for index size.
export function searchKeywords(...parts: Array<string | undefined | null>): string[] {
  const out = new Set<string>();
  for (const part of parts) {
    if (!part) continue;
    const lower = part.toLowerCase();
    const words = lower.split(/[^a-z0-9]+/).filter((w) => w.length > 0);
    const digits = lower.replace(/[^0-9]/g, '');
    if (digits.length >= 6) words.push(digits, digits.slice(-9));
    for (const w of words) {
      for (let i = 2; i <= Math.min(w.length, 15); i++) out.add(w.slice(0, i));
    }
  }
  return [...out].slice(0, 150);
}

function sameList(a: unknown, b: string[]): boolean {
  return Array.isArray(a) && a.length === b.length && a.every((v, i) => v === b[i]);
}

export const indexOrderSearch = onDocumentWritten(
  { document: 'Orders/{orderId}', database: DATABASE_ID },
  async (event) => {
    const o = event.data?.after.data();
    if (!o) return;
    const words = searchKeywords(o.orderNumber, o.invoiceNumber, o.contactName, o.customerCompany, o.contactPhone, o.customerEmail?.split('@')[0]);
    if (sameList(o.searchKeywords, words)) return;
    await event.data!.after.ref.update({ searchKeywords: words, lastUpdatedBy: 'system:search' });
  },
);

export const indexCatalogSearch = onDocumentWritten(
  { document: 'CatalogItems/{itemId}', database: DATABASE_ID },
  async (event) => {
    const d = event.data?.after.data();
    if (!d) return;
    const words = searchKeywords(d.name, d.category, d.description?.slice(0, 300), ...(d.tags ?? []));
    if (sameList(d.searchKeywords, words)) return;
    await event.data!.after.ref.update({ searchKeywords: words });
  },
);

// ---------------------------------------------------------------------------
// Backups
// ---------------------------------------------------------------------------

export const BACKUP_BUCKET = 'bright-brush-firestore-backups';

/// Nightly export of the whole database to Cloud Storage (bucket keeps 30
/// days via its lifecycle rule). Restore with `gcloud firestore import`.
export const backupFirestore = onSchedule(
  { schedule: 'every day 02:00', timeZone: 'Africa/Nairobi', timeoutSeconds: 540 },
  async () => {
    const { v1 } = await import('@google-cloud/firestore');
    const client = new v1.FirestoreAdminClient();
    const projectId = process.env.GCLOUD_PROJECT ?? 'bright-brush';
    const stamp = new Date().toISOString().slice(0, 10);
    const [operation] = await client.exportDocuments({
      name: client.databasePath(projectId, DATABASE_ID),
      outputUriPrefix: `gs://${BACKUP_BUCKET}/${stamp}`,
      collectionIds: [],
    });
    logger.info('[backup] export started', { operation: operation.name, prefix: stamp });
  },
);

// ---------------------------------------------------------------------------
// Client error reporting (web has no Crashlytics)
// ---------------------------------------------------------------------------

export const logClientError = onCall(async (request) => {
  const uid = request.auth?.uid ?? 'anonymous';
  await rateLimit(`clientError_${uid}`, 20, 3600);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const str = (v: unknown, max: number) => (typeof v === 'string' ? v.slice(0, max) : '');
  await db.collection('ClientErrors').add({
    uid,
    message: str(d.message, 1000),
    stack: str(d.stack, 4000),
    route: str(d.route, 200),
    platform: str(d.platform, 30),
    appVersion: str(d.appVersion, 30),
    at: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 30 * 86400 * 1000),
  });
  return { ok: true };
});
