// Security-rules tests for the money paths added with server-side ordering
// and payments. Run from this folder with `npm test` (starts the Firestore
// emulator via `firebase emulators:exec`).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteField,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

let env;

const now = Timestamp.now();

const baseOrder = {
  orderNumber: 'BB-000001',
  customerId: 'alice',
  customerEmail: 'alice@example.com',
  contactName: 'Alice',
  contactPhone: '0712345678',
  deliveryAddress: 'Moi Avenue, Nairobi',
  items: [{ kind: 'item', itemId: 'cap1', name: 'Cap', category: 'caps', unitPrice: 500, quantity: 50 }],
  subtotal: 25000,
  deliveryFee: 0,
  taxRate: 0,
  taxAmount: 0,
  total: 25000,
  paymentPlan: 'deposit',
  depositAmount: 12500,
  amountPaid: 0,
  status: 'pendingReview',
  paymentStatus: 'unpaid',
  assignedStaffId: null,
  source: 'cart',
  createdAt: now,
  updatedAt: now,
};

const as = (uid) => env.authenticatedContext(uid).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-brightbrush',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (role) => ({
      email: `${role}@example.com`,
      displayName: role,
      role,
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'Users/alice'), user('user'));
    await setDoc(doc(db, 'Users/bob'), user('user'));
    await setDoc(doc(db, 'Users/manager'), user('systemManager'));
    await setDoc(doc(db, 'Users/admin'), user('admin'));
    await setDoc(doc(db, 'Orders/o1'), baseOrder);
    await setDoc(doc(db, 'Orders/paid'), { ...baseOrder, amountPaid: 12500, paymentStatus: 'partiallyPaid' });
    await setDoc(doc(db, 'PaymentGateways/mpesa'), { enabled: true, configured: true, mode: 'sandbox' });
    await setDoc(doc(db, 'PaymentGatewaySecrets/mpesa'), { values: { consumerSecret: 'x' } });
    await setDoc(doc(db, 'PaymentTokens/p1'), { callbackToken: 'secret' });
    await setDoc(doc(db, 'Counters/orders'), { value: 1 });
    await setDoc(doc(db, 'Payments/p1'), { orderId: 'o1', customerId: 'alice', amount: 12500, status: 'pending' });
    await setDoc(doc(db, 'QuoteRequests/q1'), {
      customerId: 'alice',
      customerName: 'Alice',
      title: '200 embroidered polos',
      quantity: 200,
      details: 'Left chest logo',
      status: 'new',
      createdAt: now,
      updatedAt: now,
    });
  });
});

describe('Orders', () => {
  it('no client can create an order directly (server-only pricing)', async () => {
    await assertFails(
      setDoc(doc(as('alice'), 'Orders/new'), { ...baseOrder, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('admin'), 'Orders/new'), { ...baseOrder, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
  });

  it('customer cannot mark their order paid or credit amountPaid', async () => {
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/o1'), { lastUpdatedBy: 'alice', paymentStatus: 'paid', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/o1'), { lastUpdatedBy: 'alice', amountPaid: 25000, updatedAt: serverTimestamp() }),
    );
  });

  it('customer cannot rewrite totals or the deposit', async () => {
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/o1'), { lastUpdatedBy: 'alice', total: 1, updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/o1'), { lastUpdatedBy: 'manager', depositAmount: 1, updatedAt: serverTimestamp() }),
    );
  });

  it('customer can cancel an unpaid pending order, but not one with money on it', async () => {
    await assertSucceeds(
      updateDoc(doc(as('alice'), 'Orders/o1'), { lastUpdatedBy: 'alice', status: 'cancelled', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/paid'), { lastUpdatedBy: 'alice', status: 'cancelled', updatedAt: serverTimestamp() }),
    );
  });

  it('manager can flag invoiced but cannot mark paid by hand', async () => {
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Orders/o1'), { lastUpdatedBy: 'manager', paymentStatus: 'invoiced', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/o1'), { lastUpdatedBy: 'manager', paymentStatus: 'paid', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/paid'), { lastUpdatedBy: 'manager', paymentStatus: 'unpaid', updatedAt: serverTimestamp() }),
    );
  });

  it('manager can still move production status', async () => {
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Orders/o1'), { lastUpdatedBy: 'manager', status: 'confirmed', updatedAt: serverTimestamp() }),
    );
  });
});

describe('Payment secrets and ledger', () => {
  it('gateway secrets, callback tokens and counters are unreadable by everyone, admins included', async () => {
    for (const uid of ['alice', 'manager', 'admin']) {
      await assertFails(getDoc(doc(as(uid), 'PaymentGatewaySecrets/mpesa')));
      await assertFails(getDoc(doc(as(uid), 'PaymentTokens/p1')));
      await assertFails(getDoc(doc(as(uid), 'Counters/orders')));
    }
    await assertFails(setDoc(doc(as('admin'), 'PaymentGatewaySecrets/mpesa'), { values: {} }));
  });

  it('gateway status is public but not client-writable', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'PaymentGateways/mpesa')));
    await assertFails(updateDoc(doc(as('admin'), 'PaymentGateways/mpesa'), { enabled: false }));
  });

  it('payments are readable by their owner and staff only, and never client-writable', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'Payments/p1')));
    await assertSucceeds(getDoc(doc(as('manager'), 'Payments/p1')));
    await assertFails(getDoc(doc(as('bob'), 'Payments/p1')));
    await assertFails(updateDoc(doc(as('alice'), 'Payments/p1'), { status: 'succeeded' }));
  });
});

describe('Settings', () => {
  const settings = {
    businessName: 'BrightBrush Creations',
    appBaseUrl: 'https://bright-brush.web.app',
    supportPhone: '',
    supportEmail: '',
    kraPin: '',
    vatEnabled: true,
    vatRate: 0.16,
    pricesIncludeVat: true,
    deliveryFlatFee: 300,
    freeDeliveryThreshold: 20000,
    allowDeposit: true,
    depositPercent: 50,
  };

  it('admin can save valid business settings; others cannot', async () => {
    await assertSucceeds(
      setDoc(doc(as('admin'), 'Settings/business'), { ...settings, updatedBy: 'admin', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('manager'), 'Settings/business'), { ...settings, updatedBy: 'manager', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('admin'), 'Settings/business'), { ...settings, vatRate: 16, updatedBy: 'admin', updatedAt: serverTimestamp() }),
    );
  });
});

describe('QuoteRequests', () => {
  const request = {
    customerId: 'alice',
    customerName: 'Alice',
    title: 'Hoodies',
    quantity: 30,
    details: '',
    status: 'new',
  };

  it('customer can request a quote but cannot pre-price it', async () => {
    await assertSucceeds(
      setDoc(doc(as('alice'), 'QuoteRequests/q2'), { ...request, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('alice'), 'QuoteRequests/q3'), {
        ...request,
        quotedTotal: 1,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('customer cannot price or accept their own quote', async () => {
    await assertFails(
      updateDoc(doc(as('alice'), 'QuoteRequests/q1'), {
        status: 'quoted',
        quotedTotal: 1,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'QuoteRequests/q1'), { status: 'accepted', updatedAt: serverTimestamp() }),
    );
  });

  it('staff can price a request but never mark it accepted', async () => {
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'QuoteRequests/q1'), {
        status: 'quoted',
        quotedTotal: 90000,
        quoteMessage: 'Includes delivery',
        validUntil: Timestamp.fromMillis(Date.now() + 86400000),
        respondedBy: 'manager',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'QuoteRequests/q1'), {
        status: 'accepted',
        respondedBy: 'manager',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('customer can withdraw a request; other customers cannot see it', async () => {
    await assertFails(getDoc(doc(as('bob'), 'QuoteRequests/q1')));
    await assertSucceeds(
      updateDoc(doc(as('alice'), 'QuoteRequests/q1'), { status: 'cancelled', updatedAt: serverTimestamp() }),
    );
  });
});

describe('Existing protections still hold', () => {
  it('a user cannot promote themselves', async () => {
    await assertFails(
      updateDoc(doc(as('alice'), 'Users/alice'), { role: 'admin', updatedAt: serverTimestamp() }),
    );
  });

  it('removing a required order field is rejected', async () => {
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/o1'), { lastUpdatedBy: 'manager', contactPhone: deleteField(), updatedAt: serverTimestamp() }),
    );
  });
});

describe('Phase 2: artwork, proofs, customised carts', () => {
  const artwork = (owner) => ({
    ownerId: owner,
    name: 'Logo',
    fileUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/logo.png',
    storagePath: `artwork/${owner}/a1/logo.png`,
    contentType: 'image/png',
    sizeBytes: 1000,
  });

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'Artworks/a1'), { ...artwork('alice'), createdAt: now, updatedAt: now });
      await setDoc(doc(db, 'Orders/decorated'), { ...baseOrder, requiresProof: true, proofStatus: 'required', status: 'confirmed' });
      await setDoc(doc(db, 'Orders/decorated/Proofs/p1'), { version: 1, status: 'pending', imageUrls: [] });
    });
  });

  it('customer uploads artwork to their own path but cannot mark it digitized', async () => {
    await assertSucceeds(
      setDoc(doc(as('alice'), 'Artworks/a2'), { ...artwork('alice'), storagePath: 'artwork/alice/a2/l.png', createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('alice'), 'Artworks/a3'), { ...artwork('alice'), digitized: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('alice'), 'Artworks/a4'), { ...artwork('alice'), storagePath: 'artwork/bob/a4/l.png', createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Artworks/a1'), { digitized: true, stitchCount: 1, updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(updateDoc(doc(as('alice'), 'Artworks/a1'), { name: 'New name', updatedAt: serverTimestamp() }));
  });

  it('other customers cannot see artwork; staff can digitize it', async () => {
    await assertFails(getDoc(doc(as('bob'), 'Artworks/a1')));
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Artworks/a1'), { digitized: true, stitchCount: 8200, updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(doc(as('manager'), 'Artworks/a1'), { name: 'x', updatedAt: serverTimestamp() }));
  });

  it('proofs are readable by the order owner and staff, writable by nobody', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'Orders/decorated/Proofs/p1')));
    await assertSucceeds(getDoc(doc(as('manager'), 'Orders/decorated/Proofs/p1')));
    await assertFails(getDoc(doc(as('bob'), 'Orders/decorated/Proofs/p1')));
    await assertFails(updateDoc(doc(as('alice'), 'Orders/decorated/Proofs/p1'), { status: 'approved' }));
  });

  it('production is blocked until the proof is approved, and clients cannot fake approval', async () => {
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/decorated'), { lastUpdatedBy: 'manager', status: 'inProduction', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/decorated'), { lastUpdatedBy: 'manager', proofStatus: 'approved', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/decorated'), { lastUpdatedBy: 'alice', proofStatus: 'approved', updatedAt: serverTimestamp() }),
    );
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'Orders/decorated'), { proofStatus: 'approved' }),
    );
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Orders/decorated'), { lastUpdatedBy: 'manager', status: 'inProduction', updatedAt: serverTimestamp() }),
    );
  });

  it('carts accept customised lines', async () => {
    await assertSucceeds(
      setDoc(doc(as('alice'), 'Carts/alice'), {
        items: {},
        lines: { l1: { itemId: 'polo', sizeQuantities: { M: 10 }, decorations: [], names: [] } },
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('only admins save decoration rates', async () => {
    const rates = { methods: { embroidery: { setupFee: 1500 } }, personalisationFee: 200 };
    await assertSucceeds(
      setDoc(doc(as('admin'), 'Settings/decoration'), { ...rates, updatedBy: 'admin', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('manager'), 'Settings/decoration'), { ...rates, updatedBy: 'manager', updatedAt: serverTimestamp() }),
    );
  });
});

describe('Phase 3: accounts, coupons, refunds, integrations', () => {
  const account = {
    companyName: 'Acme Ltd', kraPin: 'P051234567X', discountPercent: 10,
    creditEnabled: true, creditLimit: 100000, paymentTermsDays: 30, notes: '',
  };
  const coupon = {
    code: 'VALENTINE10', description: '10% off', type: 'percent', value: 10,
    minSubtotal: 0, maxDiscount: 0, usageLimit: 0, perCustomerLimit: 1, usedCount: 0, active: true,
  };

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'CustomerAccounts/alice'), { ...account, updatedBy: 'admin', updatedAt: now });
      await setDoc(doc(db, 'Coupons/SAVE5'), { ...coupon, code: 'SAVE5', createdAt: now, updatedAt: now });
      await setDoc(doc(db, 'Refunds/r1'), { orderId: 'o1', customerId: 'alice', amount: 100 });
      await setDoc(doc(db, 'Integrations/etims'), { enabled: true });
    });
  });

  it('only admins set business terms; the customer can read but not change their own', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'CustomerAccounts/alice')));
    await assertFails(getDoc(doc(as('bob'), 'CustomerAccounts/alice')));
    await assertFails(
      setDoc(doc(as('alice'), 'CustomerAccounts/alice'), { ...account, creditLimit: 9e9, updatedBy: 'alice', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(
      setDoc(doc(as('admin'), 'CustomerAccounts/bob'), { ...account, updatedBy: 'admin', updatedAt: serverTimestamp() }),
    );
  });

  it('coupon codes are invisible to customers and usage counts are server-only', async () => {
    await assertFails(getDoc(doc(as('alice'), 'Coupons/SAVE5')));
    await assertSucceeds(
      setDoc(doc(as('admin'), 'Coupons/VALENTINE10'), { ...coupon, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('admin'), 'Coupons/BAD1'), { ...coupon, code: 'BAD1', value: 150, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(doc(as('admin'), 'Coupons/SAVE5'), { usedCount: 0, updatedAt: serverTimestamp() }).then(() =>
      updateDoc(doc(as('admin'), 'Coupons/SAVE5'), { usedCount: 99, updatedAt: serverTimestamp() })));
  });

  it('customers cannot grant themselves discounts, credit or refunds on orders', async () => {
    for (const field of [{ discountAmount: 5000 }, { refundedAmount: 1 }, { dueDate: now }, { etims: { status: 'submitted' } }]) {
      await assertFails(updateDoc(doc(as('alice'), 'Orders/o1'), { lastUpdatedBy: 'alice', ...field, updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(as('manager'), 'Orders/o1'), { lastUpdatedBy: 'manager', ...field, updatedAt: serverTimestamp() }));
    }
  });

  it('credit notes are readable by the customer and staff, never writable', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'Refunds/r1')));
    await assertFails(getDoc(doc(as('bob'), 'Refunds/r1')));
    await assertFails(setDoc(doc(as('admin'), 'Refunds/r2'), { orderId: 'o1', customerId: 'alice', amount: 1 }));
  });

  it('integration status is staff-only and credentials are unreachable', async () => {
    await assertSucceeds(getDoc(doc(as('manager'), 'Integrations/etims')));
    await assertFails(getDoc(doc(as('alice'), 'Integrations/etims')));
    await assertFails(getDoc(doc(as('admin'), 'IntegrationSecrets/etims')));
  });
});

describe('Phase 4: operations', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'Users/driver'), { email: 'd@example.com', displayName: 'Driver', role: 'deliveryStaff', createdAt: now, updatedAt: now });
      await setDoc(doc(db, 'Orders/inprod'), { ...baseOrder, status: 'inProduction', qcStatus: 'pending' });
      await setDoc(doc(db, 'Orders/ready'), { ...baseOrder, status: 'readyForDelivery', qcStatus: 'passed', assignedStaffId: null });
      await setDoc(doc(db, 'Orders/out'), { ...baseOrder, status: 'outForDelivery', qcStatus: 'passed', assignedStaffId: 'driver' });
      await setDoc(doc(db, 'OrderSecrets/out'), { customerId: 'alice', deliveryCode: '1234' });
      await setDoc(doc(db, 'ProductionJobs/inprod'), {
        orderId: 'inprod', stage: 'queued', priority: 'normal', machineId: null, machineName: '',
        operatorName: '', scheduledDate: null, estimatedMinutes: 0, notes: '', dueDate: null,
        updatedAt: now, updatedBy: 'system',
      });
      await setDoc(doc(db, 'PurchaseOrders/po1'), { poNumber: 'PO-000001', status: 'draft', lines: [], total: 0 });
      await setDoc(doc(db, 'AuditLog/a1'), { type: 'user.updated', summary: 'x' });
    });
  });

  it('client order updates must name their author', async () => {
    await assertFails(updateDoc(doc(as('manager'), 'Orders/o1'), { status: 'confirmed', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('manager'), 'Orders/o1'), { status: 'confirmed', lastUpdatedBy: 'alice', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as('manager'), 'Orders/o1'), { status: 'confirmed', lastUpdatedBy: 'manager', updatedAt: serverTimestamp() }));
  });

  it('nothing is handed over before quality control passes', async () => {
    await assertSucceeds(updateDoc(doc(as('manager'), 'Orders/inprod'), { status: 'qualityCheck', lastUpdatedBy: 'manager', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('manager'), 'Orders/inprod'), { status: 'readyForDelivery', lastUpdatedBy: 'manager', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('manager'), 'Orders/inprod'), { qcStatus: 'passed', lastUpdatedBy: 'manager', updatedAt: serverTimestamp() }));
  });

  it('drivers can claim but not self-complete a delivery', async () => {
    await assertSucceeds(updateDoc(doc(as('driver'), 'Orders/ready'), { status: 'outForDelivery', assignedStaffId: 'driver', lastUpdatedBy: 'driver', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('driver'), 'Orders/out'), { status: 'completed', lastUpdatedBy: 'driver', updatedAt: serverTimestamp() }));
  });

  it('only the customer can see the delivery code', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'OrderSecrets/out')));
    await assertFails(getDoc(doc(as('driver'), 'OrderSecrets/out')));
    await assertFails(getDoc(doc(as('manager'), 'OrderSecrets/out')));
  });

  it('managers schedule job cards within the allowed fields', async () => {
    await assertSucceeds(updateDoc(doc(as('manager'), 'ProductionJobs/inprod'), {
      stage: 'inProduction', priority: 'rush', estimatedMinutes: 120, operatorName: 'Wanjiru',
      updatedBy: 'manager', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(as('manager'), 'ProductionJobs/inprod'), { orderId: 'other', updatedBy: 'manager', updatedAt: serverTimestamp() }));
    await assertFails(getDoc(doc(as('alice'), 'ProductionJobs/inprod')));
  });

  it('purchase orders only move draft → sent / cancelled from the client', async () => {
    await assertSucceeds(updateDoc(doc(as('manager'), 'PurchaseOrders/po1'), { status: 'sent', updatedBy: 'manager', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('manager'), 'PurchaseOrders/po1'), { status: 'received', updatedBy: 'manager', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('manager'), 'PurchaseOrders/po2'), { poNumber: 'PO-9', status: 'draft' }));
  });

  it('the audit log is admin-read-only and immutable', async () => {
    await assertSucceeds(getDoc(doc(as('admin'), 'AuditLog/a1')));
    await assertFails(getDoc(doc(as('manager'), 'AuditLog/a1')));
    await assertFails(updateDoc(doc(as('admin'), 'AuditLog/a1'), { summary: 'edited' }));
  });
});

describe('Phase 5: growth', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'Notifications/n1'), { uid: 'alice', title: 'x', read: false });
      await setDoc(doc(db, 'Orders/done'), { ...baseOrder, status: 'completed', qcStatus: 'passed' });
      await setDoc(doc(db, 'Orders/o1/ChatState/state'), { customerId: 'alice', customerUnread: 3, staffUnread: 2 });
      await setDoc(doc(db, 'Companies/acme'), {
        name: 'Acme', kraPin: '', discountPercent: 10, creditEnabled: true, creditLimit: 0,
        paymentTermsDays: 30, memberIds: ['alice'], updatedBy: 'admin', updatedAt: now,
      });
      await setDoc(doc(db, 'Companies/acme/Programs/p1'), { name: 'Staff polos', active: true, items: [] });
      await setDoc(doc(db, 'LoyaltyAccounts/alice'), { points: 500 });
      await setDoc(doc(db, 'Reviews/approvedOne'), { customerId: 'bob', status: 'approved', rating: 5 });
    });
  });

  it('notifications are private and only the read flag can change', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'Notifications/n1')));
    await assertFails(getDoc(doc(as('bob'), 'Notifications/n1')));
    await assertSucceeds(updateDoc(doc(as('alice'), 'Notifications/n1'), { read: true }));
    await assertFails(updateDoc(doc(as('alice'), 'Notifications/n1'), { title: 'spoof' }));
    await assertFails(setDoc(doc(as('alice'), 'Notifications/n2'), { uid: 'alice', title: 'x', read: false }));
  });

  it('chat: customer and staff post as themselves only', async () => {
    const msg = (from, role) => ({ from, fromRole: role, fromName: 'X', text: 'Hello', attachments: [], at: serverTimestamp() });
    await assertSucceeds(setDoc(doc(as('alice'), 'Orders/o1/Messages/m1'), msg('alice', 'customer')));
    await assertFails(setDoc(doc(as('alice'), 'Orders/o1/Messages/m2'), msg('alice', 'staff')));
    await assertFails(setDoc(doc(as('bob'), 'Orders/o1/Messages/m3'), msg('bob', 'customer')));
    await assertSucceeds(setDoc(doc(as('manager'), 'Orders/o1/Messages/m4'), msg('manager', 'staff')));
    await assertFails(getDoc(doc(as('bob'), 'Orders/o1/Messages/m1')));
  });

  it('chat unread counters: each side clears only its own', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), 'Orders/o1/ChatState/state'), { customerUnread: 0 }));
    await assertFails(updateDoc(doc(as('alice'), 'Orders/o1/ChatState/state'), { staffUnread: 0 }));
  });

  it('reviews only for your own completed orders, and start pending', async () => {
    const review = { customerId: 'alice', customerName: 'Alice', rating: 5, comment: 'Great', photoUrls: [], itemIds: ['cap1'], createdAt: serverTimestamp() };
    await assertFails(setDoc(doc(as('alice'), 'Reviews/o1'), { ...review, status: 'pending' }));
    await assertFails(setDoc(doc(as('alice'), 'Reviews/done'), { ...review, status: 'approved' }));
    await assertSucceeds(setDoc(doc(as('alice'), 'Reviews/done'), { ...review, status: 'pending' }));
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'Reviews/approvedOne')));
  });

  it('company members see their company and programs; others cannot', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'Companies/acme')));
    await assertSucceeds(getDoc(doc(as('alice'), 'Companies/acme/Programs/p1')));
    await assertFails(getDoc(doc(as('bob'), 'Companies/acme')));
    await assertFails(getDoc(doc(as('bob'), 'Companies/acme/Programs/p1')));
    await assertFails(updateDoc(doc(as('alice'), 'Companies/acme'), { discountPercent: 90, updatedBy: 'alice', updatedAt: serverTimestamp() }));
  });

  it('loyalty balances and referrals cannot be edited by customers', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'LoyaltyAccounts/alice')));
    await assertFails(getDoc(doc(as('bob'), 'LoyaltyAccounts/alice')));
    await assertFails(setDoc(doc(as('alice'), 'LoyaltyAccounts/alice'), { points: 99999 }));
    await assertFails(setDoc(doc(as('alice'), 'Referrals/alice'), { referrerUid: 'bob', status: 'pending' }));
    await assertFails(getDoc(doc(as('alice'), 'ReferralCodes/ABCD1234')));
  });

  it('customers cannot redeem points by editing the order', async () => {
    await assertFails(updateDoc(doc(as('alice'), 'Orders/o1'), { loyaltyDiscount: 5000, lastUpdatedBy: 'alice', updatedAt: serverTimestamp() }));
  });
});

describe('Phase 6: platform', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'Stats/totals'), { ordersPlaced: 3 });
      await setDoc(doc(db, 'ClientErrors/e1'), { uid: 'alice', message: 'x' });
      await setDoc(doc(db, 'RateLimits/placeOrder_alice'), { count: 1, windowStart: 0 });
      await setDoc(doc(db, 'CatalogItems/cap1'), { name: 'Cap', searchKeywords: ['ca', 'cap'] });
    });
  });

  it('stats are readable by managers and admins only, and never client-writable', async () => {
    await assertSucceeds(getDoc(doc(as('manager'), 'Stats/totals')));
    await assertSucceeds(getDoc(doc(as('admin'), 'Stats/totals')));
    await assertFails(getDoc(doc(as('alice'), 'Stats/totals')));
    await assertFails(setDoc(doc(as('admin'), 'Stats/totals'), { ordersPlaced: 0 }));
  });

  it('client error reports are admin-readable and written only by the server', async () => {
    await assertSucceeds(getDoc(doc(as('admin'), 'ClientErrors/e1')));
    await assertFails(getDoc(doc(as('alice'), 'ClientErrors/e1')));
    await assertFails(getDoc(doc(as('manager'), 'ClientErrors/e1')));
    await assertFails(setDoc(doc(as('alice'), 'ClientErrors/e2'), { message: 'spam' }));
  });

  it('rate-limit counters are unreachable', async () => {
    await assertFails(getDoc(doc(as('alice'), 'RateLimits/placeOrder_alice')));
    await assertFails(setDoc(doc(as('alice'), 'RateLimits/placeOrder_alice'), { count: 0, windowStart: 0 }));
    await assertFails(getDoc(doc(as('admin'), 'RateLimits/placeOrder_alice')));
  });

  it('search keywords on orders are server-maintained', async () => {
    await assertFails(updateDoc(doc(as('manager'), 'Orders/o1'), { searchKeywords: ['x'], lastUpdatedBy: 'manager', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('alice'), 'Orders/o1'), { searchKeywords: ['x'], lastUpdatedBy: 'alice', updatedAt: serverTimestamp() }));
  });

  it('business settings accept working hours up to 200 characters', async () => {
    const base = {
      businessName: 'BrightBrush Creations', appBaseUrl: 'https://bright-brush.web.app', supportPhone: '', supportEmail: '',
      kraPin: '', vatEnabled: true, vatRate: 0.16, pricesIncludeVat: true, deliveryFlatFee: 300,
      freeDeliveryThreshold: 20000, allowDeposit: true, depositPercent: 50, updatedBy: 'admin', updatedAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(as('admin'), 'Settings/business'), { ...base, workingHours: 'Mon–Fri 8am–6pm' }));
    await assertFails(setDoc(doc(as('admin'), 'Settings/business'), { ...base, workingHours: 'x'.repeat(201) }));
  });
});

describe('Languages', () => {
  it('a user saves their own app language; nobody else can', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), 'Users/alice/Settings/preferences'), { language: 'sw', updatedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(as('alice'), 'Users/alice/Settings/preferences')));
    await assertFails(setDoc(doc(as('bob'), 'Users/alice/Settings/preferences'), { language: 'en' }));
    await assertFails(getDoc(doc(as('bob'), 'Users/alice/Settings/preferences')));
  });
});
