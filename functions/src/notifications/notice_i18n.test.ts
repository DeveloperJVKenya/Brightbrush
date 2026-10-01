import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { localizeNotice } from './notice_i18n';
import { customerNoticesFor } from './order_notices';

// Every customer notice the order trigger can produce must come out in
// Kiswahili — a new or reworded English notice that the table doesn't know
// would otherwise be sent untranslated.
describe('localizeNotice', () => {
  const base = { orderNumber: 'BB-000123', total: 5000, amountPaid: 0, invoiceNumber: 'INV-9' };
  const cases: Array<[string, Record<string, unknown>, Array<{ field: string; from: unknown; to: unknown }>]> = [];
  for (const status of ['confirmed', 'awaitingProof', 'inProduction', 'readyForDelivery', 'outForDelivery', 'completed', 'cancelled']) {
    cases.push([status, base, [{ field: 'status', from: 'pendingReview', to: status }]]);
  }
  cases.push(['pickup ready', { ...base, deliveryMethod: 'pickup' }, [{ field: 'status', from: 'qualityCheck', to: 'readyForDelivery' }]]);
  cases.push(['cancel with reason', { ...base, cancelReason: 'Duplicate order' }, [{ field: 'status', from: 'confirmed', to: 'cancelled' }]]);
  cases.push(['part payment', { ...base, amountPaid: 2000 }, [{ field: 'amountPaid', from: 0, to: 2000 }]]);
  cases.push(['full payment', { ...base, amountPaid: 5000 }, [{ field: 'amountPaid', from: 2000, to: 5000 }]]);
  cases.push(['refund', base, [{ field: 'refundedAmount', from: 0, to: 1500 }]]);
  cases.push(['overdue', base, [{ field: 'overdue', from: false, to: true }]]);

  for (const [name, order, changes] of cases) {
    it(`translates the "${name}" notice`, () => {
      const notices = customerNoticesFor(changes, order, 'o1');
      assert.ok(notices.length > 0, 'expected a notice');
      for (const n of notices) {
        const sw = localizeNotice('sw', n.title, n.body);
        assert.notEqual(sw.title, n.title, `title untranslated: ${n.title}`);
        assert.notEqual(sw.body, n.body, `body untranslated: ${n.body}`);
        assert.ok(sw.title.includes('BB-000123') || !n.title.includes('BB-000123'), 'order number kept');
      }
    });
  }

  it('leaves English alone and keeps values', () => {
    assert.deepEqual(localizeNotice('en', 'Order BB-1 confirmed', 'x'), { title: 'Order BB-1 confirmed', body: 'x' });
    assert.equal(localizeNotice('sw', 'Your quote is ready — KES 12,000', '').title, 'Bei yako iko tayari — KES 12,000');
    assert.equal(
      localizeNotice('sw', 'You left something in your cart', "3 item(s) are waiting for you. Complete your order whenever you're ready.").body,
      'Bidhaa 3 zinakusubiri. Kamilisha oda yako wakati wowote ukiwa tayari.',
    );
  });
});
