import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { app, auth, db } from '../core/app';
import { loadCaller } from '../core/authz';

const TERMINAL = ['completed', 'cancelled'];

/// In-app account deletion (required by Google Play and the App Store, and
/// the "right to erasure" under Kenya's Data Protection Act 2019).
///
/// Orders are *anonymised*, not deleted: they're the business's financial
/// and tax records, which must be retained. Everything else tied to the
/// account (profile, cart, quotes, profile photo, auth user) is removed.
/// Staff accounts must be demoted to User by an admin first so nobody can
/// delete an account that other records depend on by accident.
export const deleteMyAccount = onCall(async (request) => {
  const caller = await loadCaller(request);
  if (caller.role !== 'user') {
    throw new HttpsError(
      'failed-precondition',
      'Staff accounts can\'t be self-deleted. Ask an Admin to change your role to User first.',
    );
  }

  const orders = await db
    .collection('Orders')
    .where('customerId', '==', caller.uid)
    .get();
  const open = orders.docs.filter((d) => !TERMINAL.includes(d.data().status));
  if (open.length > 0) {
    throw new HttpsError(
      'failed-precondition',
      `You have ${open.length} order(s) still in progress. Wait until they're delivered or cancel them, then try again.`,
    );
  }

  const writer = db.bulkWriter();
  for (const order of orders.docs) {
    writer.update(order.ref, {
      contactName: 'Deleted user',
      contactPhone: 'deleted',
      deliveryAddress: 'Removed on account deletion',
      customerEmail: '',
      notes: '',
      customerDeleted: true,
    });
  }
  const [quotes, tickets, payments] = await Promise.all([
    db.collection('QuoteRequests').where('customerId', '==', caller.uid).get(),
    db.collection('SupportTickets').where('customerId', '==', caller.uid).get(),
    db.collection('Payments').where('customerId', '==', caller.uid).get(),
  ]);
  quotes.docs.forEach((d) => writer.delete(d.ref));
  tickets.docs.forEach((d) =>
    writer.update(d.ref, { customerName: 'Deleted user' }),
  );
  payments.docs.forEach((d) => writer.update(d.ref, { phone: '' }));
  writer.delete(db.collection('Carts').doc(caller.uid));
  writer.delete(db.collection('Users').doc(caller.uid));
  await writer.close();

  try {
    // Loaded lazily: the Storage SDK is heavy and only this rare path needs
    // it, so keeping it out of module load speeds up every cold start.
    const { getStorage } = await import('firebase-admin/storage');
    await getStorage(app).bucket().deleteFiles({ prefix: `profiles/${caller.uid}/` });
  } catch (error) {
    logger.warn('[deleteMyAccount] profile photo cleanup failed', {
      uid: caller.uid,
      error: String(error),
    });
  }
  await auth.deleteUser(caller.uid);
  logger.info('[deleteMyAccount] account deleted', {
    uid: caller.uid,
    ordersAnonymised: orders.size,
  });
  return { deleted: true };
});
