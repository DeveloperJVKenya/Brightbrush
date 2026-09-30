import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';

/// Every function runs close to Kenya (the client uses the same region in
/// `firebaseFunctionsProvider` — the two must always match).
export const REGION = 'europe-west1';

/// enforceAppCheck: callables reject requests that don't carry a valid App
/// Check token (the app attaches one automatically), which blocks scripted
/// abuse from outside the real app. Webhooks (onRequest) are unaffected.
setGlobalOptions({ region: REGION, maxInstances: 20, enforceAppCheck: true });

export const app = initializeApp();

/// bright-brush provisions Firestore as a *named* database, not the default
/// one — mirrors `firestoreDatabaseId` in lib/core/firebase/firebase_providers.dart.
export const DATABASE_ID = 'brightbrush-main';

export const db = getFirestore(app, DATABASE_ID);
export const auth = getAuth(app);

/// Public base URL of the deployed HTTP functions — what payment providers
/// call back into (webhooks, redirects). Gen2 functions also get a
/// cloudfunctions.net alias in this exact shape.
export function functionsBaseUrl(): string {
  const projectId =
    process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? 'bright-brush';
  return `https://${REGION}-${projectId}.cloudfunctions.net`;
}
