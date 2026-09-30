import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { materialNeeds, parseBom, promisedDate } from './materials';
import { diffOrder } from './order_events';

describe('materialNeeds', () => {
  const boms = new Map([
    ['cap', [{ materialId: 'blankCap', perUnit: 1 }, { materialId: 'thread', perUnit: 0.1 }]],
    ['polo', [{ materialId: 'thread', perUnit: 0.1 }]],
  ]);
  it('sums across lines and rounds up to whole stock units', () => {
    const needs = materialNeeds(
      [
        { itemId: 'cap', kind: 'custom', quantity: 25 },
        { itemId: 'polo', kind: 'item', quantity: 30 },
        { itemId: 'pkg1', kind: 'package', quantity: 2 },
      ],
      boms,
    );
    assert.equal(needs.get('blankCap'), 25);
    assert.equal(needs.get('thread'), Math.ceil(2.5 + 3));
    assert.equal(needs.size, 2);
  });
  it('avoids float-noise over-deduction', () => {
    assert.equal(materialNeeds([{ itemId: 'polo', kind: 'item', quantity: 30 }], boms).get('thread'), 3);
  });
  it('ignores malformed BOM rows', () => {
    assert.deepEqual(parseBom([{ materialId: 'a', perUnit: 2 }, { materialId: 'b', perUnit: 0 }, 'x']), [
      { materialId: 'a', perUnit: 2 },
    ]);
  });
});

describe('promisedDate', () => {
  it('adds working days, skipping Sundays', () => {
    // Fri 2 Oct 2026 + 3 working days → Mon 5 skipped Sun 4 → Tue 6.
    const d = promisedDate(new Date('2026-10-02T09:00:00Z'), 3);
    assert.equal(d.toISOString().slice(0, 10), '2026-10-06');
  });
});

describe('diffOrder', () => {
  it('reports each tracked change with its before/after', () => {
    const events = diffOrder(
      { status: 'confirmed', paymentStatus: 'unpaid', amountPaid: 0, notes: 'x' },
      { status: 'inProduction', paymentStatus: 'partiallyPaid', amountPaid: 500, notes: 'y' },
    );
    assert.deepEqual(
      events.map((e) => [e.field, e.from, e.to]),
      [
        ['status', 'confirmed', 'inProduction'],
        ['paymentStatus', 'unpaid', 'partiallyPaid'],
        ['amountPaid', 0, 500],
      ],
    );
  });
  it('reads nested eTIMS status and ignores untracked fields', () => {
    const events = diffOrder({ etims: { status: 'submitting' } }, { etims: { status: 'submitted', rcptNo: 5 } });
    assert.deepEqual(events.map((e) => e.field), ['etims.status']);
    assert.equal(diffOrder({ updatedAt: 1 }, { updatedAt: 2 }).length, 0);
  });
});
