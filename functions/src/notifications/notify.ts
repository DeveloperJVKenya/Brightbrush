import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { app, db } from '../core/app';
import { requireRole } from '../core/authz';
import { asObject, requireEnum } from '../core/validate';
import { callProvider } from '../payments/http_util';
import { maskSecret } from '../payments/gateway_config';
import { loadBusinessSettings } from '../settings/business_settings';

export interface Notice {
  /// e.g. 'order.status', 'order.proof', 'payment.received', 'chat.message'
  type: string;
  title: string;
  body: string;
  /// In-app route to open, e.g. /customer/orders/<id>
  link?: string;
  orderId?: string;
}

/// Channel credentials, set by Admin/CEO (Payments & Settings →
/// Notifications). No SMS by design.
const pubRef = db.collection('Integrations').doc('notifications');
const secRef = db.collection('IntegrationSecrets').doc('notifications');

export const EMAIL_PROVIDERS = ['resend', 'sendgrid', 'brevo'] as const;

interface ChannelConfig {
  emailEnabled: boolean;
  emailProvider: (typeof EMAIL_PROVIDERS)[number];
  emailApiKey: string;
  emailFrom: string;
  whatsappEnabled: boolean;
  whatsappPhoneNumberId: string;
  whatsappToken: string;
  whatsappTemplate: string;
  whatsappLanguage: string;
}

async function loadChannels(): Promise<ChannelConfig> {
  const [p, s] = await Promise.all([pubRef.get(), secRef.get()]);
  const pub = p.data() ?? {};
  const sec = s.data() ?? {};
  return {
    emailEnabled: pub.emailEnabled === true && !!sec.emailApiKey && !!pub.emailFrom,
    emailProvider: EMAIL_PROVIDERS.includes(pub.emailProvider) ? pub.emailProvider : 'resend',
    emailApiKey: String(sec.emailApiKey ?? ''),
    emailFrom: String(pub.emailFrom ?? ''),
    whatsappEnabled: pub.whatsappEnabled === true && !!sec.whatsappToken && !!pub.whatsappPhoneNumberId && !!pub.whatsappTemplate,
    whatsappPhoneNumberId: String(pub.whatsappPhoneNumberId ?? ''),
    whatsappToken: String(sec.whatsappToken ?? ''),
    whatsappTemplate: String(pub.whatsappTemplate ?? ''),
    whatsappLanguage: String(pub.whatsappLanguage ?? 'en'),
  };
}

export function kenyanWhatsappNumber(phone: string): string | null {
  const digits = phone.replace(/[^\d]/g, '');
  if (/^0[17]\d{8}$/.test(digits)) return `254${digits.slice(1)}`;
  if (/^254[17]\d{8}$/.test(digits)) return digits;
  return null;
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

async function sendEmail(c: ChannelConfig, to: string, subject: string, text: string, link: string | undefined, businessName: string) {
  const html = `<div style="font-family:Arial,sans-serif;font-size:15px;color:#222">
<h2 style="color:#5B2A86">${escapeHtml(businessName)}</h2>
<p>${escapeHtml(text).replace(/\n/g, '<br>')}</p>
${link ? `<p><a href="${escapeHtml(link)}" style="background:#5B2A86;color:#fff;padding:10px 16px;border-radius:6px;text-decoration:none">Open in the app</a></p>` : ''}
<p style="color:#999;font-size:12px">You can change which messages you get in Profile → Notifications.</p></div>`;
  switch (c.emailProvider) {
    case 'resend':
      await callProvider('https://api.resend.com/emails', {
        headers: { Authorization: `Bearer ${c.emailApiKey}` },
        json: { from: c.emailFrom, to: [to], subject, text, html },
      });
      break;
    case 'sendgrid':
      await callProvider('https://api.sendgrid.com/v3/mail/send', {
        headers: { Authorization: `Bearer ${c.emailApiKey}` },
        json: {
          personalizations: [{ to: [{ email: to }] }],
          from: { email: c.emailFrom.replace(/.*<|>.*/g, ''), name: businessName },
          subject,
          content: [{ type: 'text/plain', value: text }, { type: 'text/html', value: html }],
        },
      });
      break;
    case 'brevo':
      await callProvider('https://api.brevo.com/v3/smtp/email', {
        headers: { 'api-key': c.emailApiKey },
        json: {
          sender: { email: c.emailFrom.replace(/.*<|>.*/g, ''), name: businessName },
          to: [{ email: to }],
          subject,
          textContent: text,
          htmlContent: html,
        },
      });
      break;
  }
}

/// Business-initiated WhatsApp messages must use a Meta-approved template.
/// The template is expected to have two body parameters: {{1}} a title and
/// {{2}} the message.
async function sendWhatsapp(c: ChannelConfig, to: string, title: string, body: string) {
  await callProvider(`https://graph.facebook.com/v21.0/${c.whatsappPhoneNumberId}/messages`, {
    headers: { Authorization: `Bearer ${c.whatsappToken}` },
    json: {
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: c.whatsappTemplate,
        language: { code: c.whatsappLanguage },
        components: [{ type: 'body', parameters: [{ type: 'text', text: title.slice(0, 60) }, { type: 'text', text: body.slice(0, 900) }] }],
      },
    },
  });
}

/// Delivers a notice to one user on every channel they allow: in-app
/// inbox (always), push to their devices, email and WhatsApp (when the
/// admin has configured those channels). Never throws — a failed channel
/// is logged and the others still go out.
export async function notifyUser(uid: string, notice: Notice): Promise<void> {
  try {
    const userRef = db.collection('Users').doc(uid);
    const [user, prefsSnap, devices, channels, settings] = await Promise.all([
      userRef.get(),
      // Preferences live in a sub-document: the Users doc itself only allows
      // a fixed set of profile fields (firestore.rules).
      userRef.collection('Settings').doc('notifications').get(),
      userRef.collection('Devices').get(),
      loadChannels(),
      loadBusinessSettings(),
    ]);
    const u = user.data() ?? {};
    const prefs = { push: true, email: true, whatsapp: true, marketing: true, ...(prefsSnap.data() ?? {}) };
    if (notice.type.startsWith('marketing') && prefs.marketing === false) return;
    const link = notice.link ? `${settings.appBaseUrl}/#${notice.link}` : undefined;

    await db.collection('Notifications').add({
      uid,
      type: notice.type,
      title: notice.title,
      body: notice.body,
      link: notice.link ?? null,
      orderId: notice.orderId ?? null,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    const jobs: Promise<unknown>[] = [];
    const tokens = devices.docs.map((d) => d.id);
    if (prefs.push && tokens.length) {
      jobs.push(
        getMessaging(app)
          .sendEachForMulticast({
            tokens,
            notification: { title: notice.title, body: notice.body },
            data: { link: notice.link ?? '', type: notice.type },
            webpush: link ? { fcmOptions: { link } } : undefined,
          })
          .then(async (res) => {
            // Drop tokens FCM says are gone.
            const dead = res.responses
              .map((r, i) => (!r.success && /registration-token-not-registered|invalid-argument/.test(r.error?.code ?? '') ? tokens[i] : null))
              .filter((t): t is string => !!t);
            await Promise.all(dead.map((t) => userRef.collection('Devices').doc(t).delete()));
          }),
      );
    }
    if (prefs.email && channels.emailEnabled && u.email) {
      jobs.push(sendEmail(channels, String(u.email), notice.title, notice.body, link, settings.businessName));
    }
    const wa = kenyanWhatsappNumber(String(u.phone ?? ''));
    if (prefs.whatsapp && channels.whatsappEnabled && wa) {
      jobs.push(sendWhatsapp(channels, wa, notice.title, `${notice.body}${link ? `\n${link}` : ''}`));
    }
    const results = await Promise.allSettled(jobs);
    results.forEach((r) => {
      if (r.status === 'rejected') logger.warn('[notify] channel failed', { uid, type: notice.type, error: String(r.reason) });
    });
  } catch (error) {
    logger.error('[notify] failed', { uid, type: notice.type, error: String(error) });
  }
}

/// Alerts every active manager/admin (new orders, quote requests, customer
/// messages).
export async function notifyStaff(notice: Notice): Promise<void> {
  const staff = await db.collection('Users').where('role', 'in', ['systemManager', 'admin']).get();
  await Promise.all(
    staff.docs.filter((d) => d.data().disabled !== true).map((d) => notifyUser(d.id, notice)),
  );
}

export const adminGetNotificationChannels = onCall(async (request) => {
  await requireRole(request, ['admin']);
  const [p, s] = await Promise.all([pubRef.get(), secRef.get()]);
  const pub = p.data() ?? {};
  const sec = s.data() ?? {};
  return {
    emailEnabled: pub.emailEnabled === true,
    emailProvider: pub.emailProvider ?? 'resend',
    emailFrom: pub.emailFrom ?? '',
    emailApiKeyPreview: maskSecret(String(sec.emailApiKey ?? '')),
    whatsappEnabled: pub.whatsappEnabled === true,
    whatsappPhoneNumberId: pub.whatsappPhoneNumberId ?? '',
    whatsappTemplate: pub.whatsappTemplate ?? '',
    whatsappLanguage: pub.whatsappLanguage ?? 'en',
    whatsappTokenPreview: maskSecret(String(sec.whatsappToken ?? '')),
  };
});

export const adminSaveNotificationChannels = onCall(async (request) => {
  const caller = await requireRole(request, ['admin']);
  const d = asObject(request.data);
  const str = (k: string, max: number) => (typeof d[k] === 'string' ? (d[k] as string).trim().slice(0, max) : undefined);
  const secret: Record<string, string> = {};
  const emailApiKey = str('emailApiKey', 300);
  const whatsappToken = str('whatsappToken', 1000);
  if (emailApiKey) secret.emailApiKey = emailApiKey;
  if (whatsappToken) secret.whatsappToken = whatsappToken;
  if (Object.keys(secret).length) await secRef.set(secret, { merge: true });
  await pubRef.set({
    emailEnabled: d.emailEnabled === true,
    emailProvider: requireEnum(d, 'emailProvider', EMAIL_PROVIDERS, 'resend'),
    emailFrom: str('emailFrom', 200) ?? '',
    whatsappEnabled: d.whatsappEnabled === true,
    whatsappPhoneNumberId: str('whatsappPhoneNumberId', 50) ?? '',
    whatsappTemplate: str('whatsappTemplate', 100) ?? '',
    whatsappLanguage: str('whatsappLanguage', 10) || 'en',
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: caller.uid,
  }, { merge: true });
  return { saved: true };
});

/// Sends a test notice to the admin themselves on every configured channel.
export const adminTestNotification = onCall(async (request) => {
  const caller = await requireRole(request, ['admin']);
  const channels = await loadChannels();
  if (!channels.emailEnabled && !channels.whatsappEnabled) {
    // Push/in-app still work without email/WhatsApp.
  }
  const user = (await db.collection('Users').doc(caller.uid).get()).data() ?? {};
  const errors: string[] = [];
  if (channels.emailEnabled && user.email) {
    await sendEmail(channels, String(user.email), 'Test notification', 'Email notifications are working.', undefined, (await loadBusinessSettings()).businessName)
      .catch((e) => errors.push(`Email: ${e instanceof Error ? e.message : e}`));
  }
  const wa = kenyanWhatsappNumber(String(user.phone ?? ''));
  if (channels.whatsappEnabled) {
    if (!wa) errors.push('WhatsApp: add a Kenyan phone number to your profile to receive the test.');
    else await sendWhatsapp(channels, wa, 'Test notification', 'WhatsApp notifications are working.').catch((e) => errors.push(`WhatsApp: ${e instanceof Error ? e.message : e}`));
  }
  await db.collection('Notifications').add({
    uid: caller.uid, type: 'test', title: 'Test notification', body: 'In-app notifications are working.',
    link: null, orderId: null, read: false, createdAt: FieldValue.serverTimestamp(),
  });
  if (errors.length) throw new HttpsError('failed-precondition', errors.join(' '));
  return { ok: true, email: channels.emailEnabled, whatsapp: channels.whatsappEnabled };
});
