import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { functionsBaseUrl } from '../core/app';
import { requireRole } from '../core/authz';
import { asObject, requireEnum } from '../core/validate';
import {
  GATEWAY_IDS,
  GATEWAY_SPECS,
  GatewayId,
  isComplete,
  loadGateway,
  maskSecret,
  publicRef,
  recordTestResult,
  secretRef,
} from './gateway_config';
import { PROVIDERS } from './providers';

/// URLs the admin must paste into each provider's dashboard (M-Pesa's is
/// set per request automatically, so it's shown for reference only).
function integrationUrls(id: GatewayId): Record<string, string> {
  const base = functionsBaseUrl();
  switch (id) {
    case 'mpesa':
      return { 'Callback URL (set automatically per payment)': `${base}/mpesaCallback/…` };
    case 'stripe':
      return { 'Webhook endpoint URL': `${base}/stripeWebhook` };
    case 'paypal':
      return { 'Return URL (set automatically per payment)': `${base}/paypalReturn` };
    case 'flutterwave':
      return {
        'Webhook URL': `${base}/flutterwaveWebhook`,
        'Redirect URL (set automatically per payment)': `${base}/flutterwaveReturn`,
      };
  }
}

/// Everything the Payments & Settings screen needs to render each gateway
/// card: its field specs, which fields are filled (secrets masked, never
/// returned in full), status, and the URLs to register with the provider.
export const adminGetPaymentGateways = onCall(async (request) => {
  await requireRole(request, ['admin']);
  const gateways = await Promise.all(
    GATEWAY_IDS.map(async (id) => {
      const spec = GATEWAY_SPECS[id];
      const [config, pub] = await Promise.all([loadGateway(id), publicRef(id).get()]);
      const lastTest = pub.data()?.lastTest;
      return {
        id,
        displayName: spec.displayName,
        description: spec.description,
        signupUrl: spec.signupUrl,
        mode: config.mode,
        enabled: config.enabled,
        configured: config.configured,
        integrationUrls: integrationUrls(id),
        lastTest: lastTest
          ? {
              ok: lastTest.ok === true,
              message: String(lastTest.message ?? ''),
              at: lastTest.at?.toMillis?.() ?? null,
            }
          : null,
        fields: spec.fields.map((f) => {
          const value = config.values[f.key] ?? '';
          return {
            key: f.key,
            label: f.label,
            help: f.help,
            secret: f.secret,
            required: f.required,
            options: f.options ?? null,
            hasValue: value.length > 0,
            value: f.secret ? '' : value || f.defaultValue || '',
            preview: f.secret ? maskSecret(value) : value,
          };
        }),
      };
    }),
  );
  return { gateways };
});

/// Saves credentials. A blank secret field means "keep the current value",
/// so an admin can flip mode or rotate one key without re-typing the rest.
/// A gateway can only be enabled once every required field is present.
export const adminSavePaymentGateway = onCall(async (request) => {
  const caller = await requireRole(request, ['admin']);
  const data = asObject(request.data);
  const id = requireEnum<GatewayId>(data, 'id', GATEWAY_IDS);
  const mode = requireEnum(data, 'mode', ['sandbox', 'live'], 'sandbox');
  const wantEnabled = data.enabled === true;
  const incoming = asObject(data.values ?? {});
  const spec = GATEWAY_SPECS[id];

  const current = await loadGateway(id);
  const values: Record<string, string> = { ...current.values };
  for (const field of spec.fields) {
    const raw = incoming[field.key];
    if (raw === undefined || raw === null) continue;
    if (typeof raw !== 'string' || raw.length > 4000) {
      throw new HttpsError('invalid-argument', `Invalid value for ${field.label}.`);
    }
    const value = raw.trim();
    if (field.secret && value === '') continue;
    if (field.options && value && !field.options.includes(value)) {
      throw new HttpsError('invalid-argument', `Invalid choice for ${field.label}.`);
    }
    values[field.key] = value;
  }
  // "Remove credentials" on the admin screen wipes everything for this
  // gateway (e.g. when switching merchant accounts).
  if (data.clear === true) {
    for (const key of Object.keys(values)) delete values[key];
  }

  const configured = isComplete(id, values);
  if (wantEnabled && !configured) {
    throw new HttpsError(
      'failed-precondition',
      'Fill in every required field before enabling this gateway.',
    );
  }
  await secretRef(id).set({
    values,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: caller.uid,
  });
  await publicRef(id).set(
    {
      id,
      displayName: spec.customerLabel,
      enabled: wantEnabled && configured,
      configured,
      mode,
      // Public keys the client may need (e.g. PayPal JS SDK later).
      publicKey:
        id === 'stripe'
          ? values.publishableKey ?? ''
          : id === 'paypal'
            ? values.clientId ?? ''
            : id === 'flutterwave'
              ? values.publicKey ?? ''
              : '',
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: caller.uid,
    },
    { merge: true },
  );
  logger.info('[adminSavePaymentGateway] saved', {
    id,
    mode,
    enabled: wantEnabled && configured,
    configured,
    by: caller.uid,
  });
  return { configured, enabled: wantEnabled && configured };
});

export const adminTestPaymentGateway = onCall(async (request) => {
  await requireRole(request, ['admin']);
  const data = asObject(request.data);
  const id = requireEnum<GatewayId>(data, 'id', GATEWAY_IDS);
  const config = await loadGateway(id);
  if (!config.configured) {
    throw new HttpsError('failed-precondition', 'Save all required credentials first.');
  }
  try {
    const message = await PROVIDERS[id].test(config);
    await recordTestResult(id, true, message);
    return { ok: true, message };
  } catch (error) {
    const message = `Connection failed: ${error instanceof Error ? error.message : String(error)}`;
    await recordTestResult(id, false, message);
    return { ok: false, message };
  }
});
