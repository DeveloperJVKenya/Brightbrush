import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { loadCaller, requireRole } from '../core/authz';
import { asObject, optionalString, requireEnum, requireString } from '../core/validate';

/// Orders this far along can still receive a (new) proof.
const PROOFABLE = ['pendingReview', 'confirmed', 'awaitingProof'];

/// Staff send a digital proof (mockup / stitch-out photos) for approval.
/// The order moves to 'awaitingProof' and firestore.rules keep it out of
/// production until the customer approves.
export const sendProof = onCall(async (request) => {
  const caller = await requireRole(request, ['systemManager', 'admin']);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const note = optionalString(data, 'note', 'Note', 2000);
  const stitchCount =
    typeof data.stitchCount === 'number' && data.stitchCount > 0
      ? Math.floor(data.stitchCount)
      : null;
  const imageUrls = (Array.isArray(data.imageUrls) ? data.imageUrls : [])
    .filter(
      (u): u is string =>
        typeof u === 'string' &&
        u.startsWith('https://firebasestorage.googleapis.com/') &&
        u.length <= 1000,
    )
    .slice(0, 8);
  if (imageUrls.length === 0) {
    throw new HttpsError('invalid-argument', 'Attach at least one proof image.');
  }

  const orderRef = db.collection('Orders').doc(orderId);
  const version = await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    const order = snap.data();
    if (!snap.exists || !order) throw new HttpsError('not-found', 'Order not found.');
    if (!PROOFABLE.includes(order.status)) {
      throw new HttpsError(
        'failed-precondition',
        'Proofs can only be sent before production starts.',
      );
    }
    const next = ((order.proofVersion as number | undefined) ?? 0) + 1;
    tx.create(orderRef.collection('Proofs').doc(), {
      version: next,
      imageUrls,
      note,
      ...(stitchCount ? { stitchCount } : {}),
      status: 'pending',
      createdBy: caller.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(orderRef, {
      status: 'awaitingProof',
      proofStatus: 'pending',
      proofVersion: next,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return next;
  });
  logger.info('[sendProof] sent', { orderId, version, by: caller.uid });
  return { version };
});

/// The customer approves the latest proof or asks for changes.
export const respondToProof = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = asObject(request.data);
  const orderId = requireString(data, 'orderId', 'Order', 1, 100);
  const proofId = requireString(data, 'proofId', 'Proof', 1, 100);
  const decision = requireEnum(data, 'decision', ['approved', 'changesRequested']);
  const comment = optionalString(data, 'comment', 'Comment', 2000);
  if (decision === 'changesRequested' && !comment) {
    throw new HttpsError('invalid-argument', 'Tell us what to change.');
  }

  const orderRef = db.collection('Orders').doc(orderId);
  const proofRef = orderRef.collection('Proofs').doc(proofId);
  await db.runTransaction(async (tx) => {
    const [orderSnap, proofSnap] = await Promise.all([tx.get(orderRef), tx.get(proofRef)]);
    const order = orderSnap.data();
    const proof = proofSnap.data();
    if (!order || order.customerId !== caller.uid || !proof) {
      throw new HttpsError('not-found', 'Proof not found.');
    }
    if (proof.status !== 'pending' || proof.version !== order.proofVersion) {
      throw new HttpsError(
        'failed-precondition',
        'This proof has already been answered or replaced by a newer one.',
      );
    }
    tx.update(proofRef, {
      status: decision,
      ...(comment ? { customerComment: comment } : {}),
      respondedAt: FieldValue.serverTimestamp(),
    });
    tx.update(orderRef, {
      proofStatus: decision,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  logger.info('[respondToProof]', { orderId, proofId, decision });
  return { status: decision };
});
