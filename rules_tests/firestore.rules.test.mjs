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
      updateDoc(doc(as('alice'), 'Orders/o1'), { paymentStatus: 'paid', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/o1'), { amountPaid: 25000, updatedAt: serverTimestamp() }),
    );
  });

  it('customer cannot rewrite totals or the deposit', async () => {
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/o1'), { total: 1, updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/o1'), { depositAmount: 1, updatedAt: serverTimestamp() }),
    );
  });

  it('customer can cancel an unpaid pending order, but not one with money on it', async () => {
    await assertSucceeds(
      updateDoc(doc(as('alice'), 'Orders/o1'), { status: 'cancelled', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/paid'), { status: 'cancelled', updatedAt: serverTimestamp() }),
    );
  });

  it('manager can flag invoiced but cannot mark paid by hand', async () => {
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Orders/o1'), { paymentStatus: 'invoiced', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/o1'), { paymentStatus: 'paid', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/paid'), { paymentStatus: 'unpaid', updatedAt: serverTimestamp() }),
    );
  });

  it('manager can still move production status', async () => {
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Orders/o1'), { status: 'confirmed', updatedAt: serverTimestamp() }),
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
      updateDoc(doc(as('manager'), 'Orders/o1'), { contactPhone: deleteField(), updatedAt: serverTimestamp() }),
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
      updateDoc(doc(as('manager'), 'Orders/decorated'), { status: 'inProduction', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('manager'), 'Orders/decorated'), { proofStatus: 'approved', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(as('alice'), 'Orders/decorated'), { proofStatus: 'approved', updatedAt: serverTimestamp() }),
    );
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'Orders/decorated'), { proofStatus: 'approved' }),
    );
    await assertSucceeds(
      updateDoc(doc(as('manager'), 'Orders/decorated'), { status: 'inProduction', updatedAt: serverTimestamp() }),
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
