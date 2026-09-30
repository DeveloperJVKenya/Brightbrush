import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { customerNoticesFor, staffNoticesFor } from '../notifications/order_notices';
import { kenyanWhatsappNumber } from '../notifications/notify';
import { DEFAULT_LOYALTY, pointsEarned, redeemable } from './loyalty';

const on = { ...DEFAULT_LOYALTY, enabled: true };

describe('loyalty maths', () => {
  it('earns points per KES 100 paid', () => {
    assert.equal(pointsEarned(12345, on), 123);
    assert.equal(pointsEarned(99, on), 0);
  });
  it('caps redemption by balance and by % of the order', () => {
    assert.deepEqual(redeemable(5000, 300, 10000, on), { points: 300, value: 300 });
    assert.deepEqual(redeemable(5000, 9999, 10000, on), { points: 2000, value: 2000 });
    assert.deepEqual(redeemable(-5, 100, 10000, on), { points: 0, value: 0 });
    assert.deepEqual(redeemable(100, 100, 10000, DEFAULT_LOYALTY), { points: 0, value: 0 });
  });
});

describe('order notices', () => {
  const order = { orderNumber: 'BB-000007', total: 10000, deliveryMethod: 'pickup', customerId: 'c1' };
  it('tells the customer about meaningful moves only', () => {
    const n = customerNoticesFor(
      [
        { field: 'status', from: 'qualityCheck', to: 'readyForDelivery' },
        { field: 'amountPaid', from: 0, to: 4000 },
        { field: 'etims.status', from: null, to: 'submitted' },
      ],
      order,
      'o1',
    );
    assert.deepEqual(n.map((x) => x.type), ['order.status', 'payment.received']);
    assert.match(n[0].title, /ready to collect/);
    assert.match(n[1].body, /Balance on BB-000007: KES 6,000/);
    assert.equal(n[0].link, '/customer/orders/o1');
  });
  it('alerts staff when the customer answers a proof', () => {
    const n = staffNoticesFor([{ field: 'proofStatus', from: 'pending', to: 'changesRequested' }], order, 'o1');
    assert.equal(n.length, 1);
  });
  it('normalises WhatsApp numbers', () => {
    assert.equal(kenyanWhatsappNumber('0712 345 678'), '254712345678');
    assert.equal(kenyanWhatsappNumber('+254 110 345678'), '254110345678');
    assert.equal(kenyanWhatsappNumber('12345'), null);
  });
});
