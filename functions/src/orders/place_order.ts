import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { loadCaller } from '../core/authz';
import {
  asObject,
  optionalString,
  requireEnum,
  requireString,
} from '../core/validate';
import { loadBusinessSettings } from '../settings/business_settings';
import {
  loadDecorationPricing,
  parseCartLines,
  priceCartLines,
} from '../customization/cart_lines';
import {
  OrderContact,
  PricedLine,
  lineTotalOf,
  nextOrderNumber,
  writeOrder,
} from './order_writer';
import { computeTotals } from './pricing';

/// Cart keys with this prefix are seasonal packages; everything else is a
/// CatalogItems id. Mirrors `packageCartKeyPrefix` in cart_providers.dart.
export const PACKAGE_PREFIX = 'pkg:';

const MAX_LINES = 50;
const MAX_QUANTITY = 100000;

export function readContact(data: Record<string, unknown>): OrderContact {
  return {
    contactName: requireString(data, 'contactName', 'Contact name', 2, 80),
    contactPhone: requireString(data, 'contactPhone', 'Contact phone', 3, 30),
    deliveryAddress: requireString(
      data,
      'deliveryAddress',
      'Delivery address',
      5,
      300,
    ),
    notes: optionalString(data, 'notes', 'Notes', 1000),
  };
}

/// Places an order from the caller's *saved* cart (Carts/{uid}). The client
/// sends only contact details and a payment plan — never items, prices or
/// totals — so nothing about what's charged can be tampered with.
export const placeOrder = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const contact = readContact(data);
  const paymentPlan = requireEnum(data, 'paymentPlan', ['full', 'deposit'], 'full');
  const [settings, decorationPricing] = await Promise.all([
    loadBusinessSettings(),
    loadDecorationPricing(),
  ]);

  const cartRef = db.collection('Carts').doc(caller.uid);
  const orderRef = db.collection('Orders').doc();

  const result = await db.runTransaction(async (tx) => {
    const cartSnap = await tx.get(cartRef);
    const rawItems = (cartSnap.data()?.items ?? {}) as Record<string, unknown>;
    const entries = Object.entries(rawItems).filter(
      ([, qty]) => typeof qty === 'number' && qty > 0,
    );
    const customLines = parseCartLines(cartSnap.data()?.lines);
    if (entries.length === 0 && customLines.length === 0) {
      throw new HttpsError('failed-precondition', 'Your cart is empty.');
    }
    if (entries.length + customLines.length > MAX_LINES) {
      throw new HttpsError(
        'failed-precondition',
        `An order can hold at most ${MAX_LINES} different items.`,
      );
    }

    const refs = entries.map(([key]) =>
      key.startsWith(PACKAGE_PREFIX)
        ? db.collection('Packages').doc(key.substring(PACKAGE_PREFIX.length))
        : db.collection('CatalogItems').doc(key),
    );
    const snaps = refs.length ? await tx.getAll(...refs) : [];
    const pricedCustom = await priceCartLines(
      tx,
      customLines,
      caller.uid,
      decorationPricing,
    );
    const now = Date.now();

    const lines: PricedLine[] = entries.map(([key, rawQty], index) => {
      const snap = snaps[index];
      const d = snap.data();
      const quantity = Math.floor(rawQty as number);
      const isPackage = key.startsWith(PACKAGE_PREFIX);
      if (!snap.exists || !d || d.isActive !== true) {
        throw new HttpsError(
          'failed-precondition',
          'An item in your cart is no longer available. Remove it and try again.',
        );
      }
      if (quantity > MAX_QUANTITY) {
        throw new HttpsError(
          'failed-precondition',
          `"${d.name}" exceeds the maximum quantity of ${MAX_QUANTITY}.`,
        );
      }
      if (isPackage) {
        const validFrom = d.validFrom?.toMillis?.() as number | undefined;
        const validTo = d.validTo?.toMillis?.() as number | undefined;
        if ((validFrom && now < validFrom) || (validTo && now > validTo)) {
          throw new HttpsError(
            'failed-precondition',
            `The "${d.name}" package isn't on offer right now.`,
          );
        }
        return {
          kind: 'package',
          itemId: snap.id,
          name: d.name as string,
          category: 'package',
          unitPrice: d.price as number,
          quantity,
        };
      }
      const moq = typeof d.moq === 'number' && d.moq > 0 ? d.moq : 1;
      if (quantity < moq) {
        throw new HttpsError(
          'failed-precondition',
          `"${d.name}" has a minimum order of ${moq}. You have ${quantity}.`,
        );
      }
      return {
        kind: 'item',
        itemId: snap.id,
        name: d.name as string,
        category: (d.category as string) ?? 'other',
        unitPrice: d.basePrice as number,
        quantity,
      };
    });

    lines.push(...pricedCustom);
    const subtotal = lines.reduce((s, l) => s + lineTotalOf(l), 0);
    const totals = computeTotals(subtotal, settings, {
      paymentPlan,
      includeDelivery: true,
    });
    const orderNumber = await nextOrderNumber(tx);

    writeOrder(tx, {
      ref: orderRef,
      orderNumber,
      customerId: caller.uid,
      customerEmail: caller.email ?? '',
      contact,
      lines,
      totals,
      source: 'cart',
      requiresProof: pricedCustom.some(
        (l) => ((l.customization?.decorations as unknown[]) ?? []).length > 0,
      ),
    });
    tx.set(cartRef, { items: {}, lines: {}, updatedAt: new Date() });
    return { orderNumber, totals };
  });

  logger.info('[placeOrder] created', {
    orderId: orderRef.id,
    orderNumber: result.orderNumber,
    uid: caller.uid,
    total: result.totals.total,
  });
  return {
    orderId: orderRef.id,
    orderNumber: result.orderNumber,
    total: result.totals.total,
    depositAmount: result.totals.depositAmount,
  };
});
