import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { loadCaller } from '../core/authz';
import {
  loadCustomerAccount,
  normalizeCouponCode,
  outstandingBalance,
  readCoupon,
  redeemCoupon,
} from '../accounts/accounts';
import { asObject, requireEnum } from '../core/validate';
import {
  applyPoints,
  loadLoyaltySettings,
  readBalance,
  redeemable,
} from '../loyalty/loyalty';
import { loadBusinessSettings } from '../settings/business_settings';
import {
  loadDecorationPricing,
  parseCartLines,
  priceCartLines,
} from '../customization/cart_lines';
import { fulfilmentFields, readContact, readFulfilment } from './fulfilment';
import {
  PricedLine,
  lineTotalOf,
  nextOrderNumber,
  writeOrder,
} from './order_writer';
import { computeDiscount, computeTotals } from './pricing';

export { readContact } from './fulfilment';

/// Cart keys with this prefix are seasonal packages; everything else is a
/// CatalogItems id. Mirrors `packageCartKeyPrefix` in cart_providers.dart.
export const PACKAGE_PREFIX = 'pkg:';

const MAX_LINES = 50;
const MAX_QUANTITY = 100000;

/// Places an order from the caller's *saved* cart (Carts/{uid}). The client
/// sends only contact details and a payment plan — never items, prices or
/// totals — so nothing about what's charged can be tampered with.
export const placeOrder = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const paymentPlan = requireEnum(data, 'paymentPlan', ['full', 'deposit', 'credit'], 'full');
  const couponCode = normalizeCouponCode(
    typeof data.couponCode === 'string' ? data.couponCode : '',
  );
  const [settings, decorationPricing, account] = await Promise.all([
    loadBusinessSettings(),
    loadDecorationPricing(),
    loadCustomerAccount(caller.uid),
  ]);
  const fulfilment = readFulfilment(data, settings);
  const contact = readContact(data, {
    pickup: fulfilment.method === 'pickup',
    pickupAddress: settings.pickupAddress,
  });
  if (paymentPlan === 'credit' && !account.creditEnabled) {
    throw new HttpsError(
      'failed-precondition',
      'Credit terms aren\'t enabled on your account. Choose another way to pay.',
    );
  }
  const owed = paymentPlan === 'credit' ? await outstandingBalance(caller.uid, account.memberIds) : 0;
  const requestedPoints =
    typeof data.redeemPoints === 'number' && data.redeemPoints > 0 ? Math.floor(data.redeemPoints) : 0;
  const loyalty = requestedPoints > 0 ? await loadLoyaltySettings() : null;
  // Exact drop-off pin chosen on the map at checkout.
  const pin =
    typeof data.deliveryLat === 'number' && typeof data.deliveryLng === 'number' &&
    Math.abs(data.deliveryLat) <= 90 && Math.abs(data.deliveryLng) <= 180
      ? { deliveryLat: data.deliveryLat, deliveryLng: data.deliveryLng }
      : {};

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
    const couponRead = couponCode
      ? await readCoupon(tx, couponCode, caller.uid)
      : null;
    const pointsBalance = loyalty ? await readBalance(tx, caller.uid) : 0;
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
        leadTimeDays: typeof d.leadTimeDays === 'number' ? d.leadTimeDays : 7,
      };
    });

    lines.push(...pricedCustom);
    const subtotal = lines.reduce((s, l) => s + lineTotalOf(l), 0);
    const discount = computeDiscount(subtotal, {
      corporatePercent: account.discountPercent,
      coupon: couponRead?.coupon,
    });
    if (couponRead && discount.coupon === 0) {
      throw new HttpsError(
        'failed-precondition',
        `Spend at least KES ${couponRead.coupon.minSubtotal} to use "${couponCode}".`,
      );
    }
    const points = loyalty
      ? redeemable(requestedPoints, pointsBalance, subtotal - discount.total, loyalty)
      : { points: 0, value: 0 };
    const totals = computeTotals(subtotal, settings, {
      paymentPlan,
      includeDelivery: fulfilment.method === 'delivery',
      deliveryFee: fulfilment.deliveryFee,
      discount: discount.total + points.value,
      creditAllowed: account.creditEnabled,
    });
    if (
      totals.paymentPlan === 'credit' &&
      account.creditLimit > 0 &&
      owed + totals.total > account.creditLimit
    ) {
      throw new HttpsError(
        'failed-precondition',
        `This order would take you over your credit limit (KES ${account.creditLimit}; KES ${Math.round(owed)} already outstanding). Pay a deposit or in full instead.`,
      );
    }
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
      extra: {
        ...fulfilmentFields(fulfilment),
        ...(discount.corporate > 0 ? { corporateDiscount: discount.corporate } : {}),
        ...(couponRead ? { couponCode, couponDiscount: discount.coupon } : {}),
        ...(account.companyName ? { customerCompany: account.companyName } : {}),
        ...(account.companyId ? { companyId: account.companyId } : {}),
        ...(points.points > 0 ? { pointsRedeemed: points.points, loyaltyDiscount: points.value } : {}),
        ...pin,
        ...(account.kraPin ? { customerKraPin: account.kraPin } : {}),
        ...(totals.paymentPlan === 'credit'
          ? { dueDate: new Date(now + account.paymentTermsDays * 86400000) }
          : {}),
      },
    });
    if (points.points > 0) {
      applyPoints(tx, caller.uid, pointsBalance, -points.points, 'redeemed', orderRef.id);
    }
    if (couponRead) {
      redeemCoupon(tx, couponCode, caller.uid, couponRead.redemptionCount, orderRef.id);
    }
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
