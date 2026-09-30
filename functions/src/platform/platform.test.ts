import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { Timestamp } from 'firebase-admin/firestore';

import { nairobiDay, rebuildStats, searchKeywords, statDeltas } from './platform';

describe('statDeltas', () => {
  const now = Date.parse('2026-09-30T21:30:00Z'); // 00:30 on 1 Oct in Nairobi

  it('counts a new order on the day it was placed (Nairobi time)', () => {
    const r = statDeltas(undefined, { total: 5000, status: 'pendingReview', createdAt: Timestamp.fromMillis(now) }, now);
    assert.deepEqual(r.daily, [{ day: '2026-10-01', fields: { ordersPlaced: 1, orderValue: 5000 } }]);
    assert.deepEqual(r.totals, { ordersPlaced: 1, orderValue: 5000, status_pendingReview: 1 });
  });

  it('moves status counters and books money on the day it arrives', () => {
    const r = statDeltas(
      { status: 'outForDelivery', amountPaid: 1000, refundedAmount: 0 },
      { status: 'completed', amountPaid: 3000, refundedAmount: 500 },
      now,
    );
    assert.deepEqual(r.totals, {
      status_outForDelivery: -1,
      status_completed: 1,
      ordersCompleted: 1,
      collected: 2000,
      refunded: 500,
    });
    assert.equal(r.daily[0].day, nairobiDay(now));
    assert.deepEqual(r.daily[0].fields, { ordersCompleted: 1, collected: 2000, refunded: 500 });
  });

  it('ignores writes that change nothing it counts', () => {
    const r = statDeltas({ status: 'confirmed', amountPaid: 0 }, { status: 'confirmed', amountPaid: 0, notes: 'x' }, now);
    assert.deepEqual(r, { daily: [], totals: {} });
  });
});

describe('searchKeywords', () => {
  it('indexes words, prefixes and phone digits', () => {
    const k = searchKeywords('BB-000123', 'Jane Wanjiru', '0712 345 678');
    for (const w of ['bb', '000123', 'ja', 'jane', 'wanj', 'wanjiru', '0712345678', '712345678']) {
      assert.ok(k.includes(w), `missing ${w}`);
    }
    assert.ok(!k.includes('j'));
  });
  it('caps the list size', () => {
    assert.ok(searchKeywords('x'.repeat(10), ...Array.from({ length: 50 }, (_, i) => `word${i}abcdefghij`)).length <= 150);
  });
});

describe('rebuildStats', () => {
  it('recounts totals and books days in Nairobi time', () => {
    const ts = (iso: string) => Timestamp.fromMillis(Date.parse(iso));
    const r = rebuildStats([
      { status: 'completed', total: 1000, amountPaid: 1000, createdAt: ts('2026-09-01T08:00:00Z'), updatedAt: ts('2026-09-03T22:00:00Z') },
      { status: 'cancelled', total: 500, amountPaid: 0, createdAt: ts('2026-09-02T08:00:00Z'), updatedAt: ts('2026-09-02T09:00:00Z') },
      { status: 'inProduction', total: 2000, amountPaid: 1000, refundedAmount: 0, createdAt: ts('2026-09-02T10:00:00Z') },
    ]);
    assert.deepEqual(r.totals, {
      ordersPlaced: 3,
      orderValue: 3500,
      status_completed: 1,
      status_cancelled: 1,
      status_inProduction: 1,
      collected: 2000,
      ordersCompleted: 1,
      ordersCancelled: 1,
    });
    assert.deepEqual(r.daily['2026-09-04'], { collected: 1000, ordersCompleted: 1 });
    assert.deepEqual(r.daily['2026-09-02'], { ordersPlaced: 2, orderValue: 2500, ordersCancelled: 1, collected: 1000 });
  });
});
