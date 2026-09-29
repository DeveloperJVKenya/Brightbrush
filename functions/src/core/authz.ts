import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';

import { db } from './app';

export type Role =
  | 'user'
  | 'deliveryStaff'
  | 'systemManager'
  | 'admin'
  | 'developer';

export interface Caller {
  uid: string;
  email: string | undefined;
  role: Role;
}

export function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Please sign in to continue.');
  }
  return uid;
}

/// Resolves the caller's role from Users/{uid} — the same source of truth
/// firestore.rules' hasStaffRole() uses, including the 'disabled' suspension
/// flag. 'developer' passes every role check, mirroring the rules.
export async function loadCaller(request: CallableRequest): Promise<Caller> {
  const uid = requireAuth(request);
  const snap = await db.collection('Users').doc(uid).get();
  const data = snap.data() ?? {};
  if (data.disabled === true) {
    throw new HttpsError(
      'permission-denied',
      'This account has been suspended. Contact an administrator.',
    );
  }
  return {
    uid,
    email: request.auth?.token.email,
    role: (data.role as Role | undefined) ?? 'user',
  };
}

export async function requireRole(
  request: CallableRequest,
  allowed: Role[],
): Promise<Caller> {
  const caller = await loadCaller(request);
  if (caller.role !== 'developer' && !allowed.includes(caller.role)) {
    throw new HttpsError(
      'permission-denied',
      'Your role is not allowed to do this.',
    );
  }
  return caller;
}

export function isStaff(role: Role, allowed: Role[]): boolean {
  return role === 'developer' || allowed.includes(role);
}
