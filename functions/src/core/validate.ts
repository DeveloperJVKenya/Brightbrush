import { HttpsError } from 'firebase-functions/v2/https';

/// Small input guards for callable payloads — everything a client sends is
/// untrusted, so each field is checked for type and bounds before use.

export function asObject(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Malformed request.');
  }
  return value as Record<string, unknown>;
}

export function requireString(
  data: Record<string, unknown>,
  key: string,
  label: string,
  min: number,
  max: number,
): string {
  const raw = data[key];
  const value = typeof raw === 'string' ? raw.trim() : '';
  if (value.length < min || value.length > max) {
    throw new HttpsError(
      'invalid-argument',
      min > 0
        ? `${label} must be between ${min} and ${max} characters.`
        : `${label} must be at most ${max} characters.`,
    );
  }
  return value;
}

export function optionalString(
  data: Record<string, unknown>,
  key: string,
  label: string,
  max: number,
): string {
  if (data[key] === undefined || data[key] === null) return '';
  return requireString(data, key, label, 0, max);
}

export function requireEnum<T extends string>(
  data: Record<string, unknown>,
  key: string,
  allowed: readonly T[],
  fallback?: T,
): T {
  const raw = data[key];
  if (typeof raw === 'string' && (allowed as readonly string[]).includes(raw)) {
    return raw as T;
  }
  if (fallback !== undefined && (raw === undefined || raw === null)) {
    return fallback;
  }
  throw new HttpsError('invalid-argument', `Invalid value for ${key}.`);
}

export function requireNumber(
  data: Record<string, unknown>,
  key: string,
  label: string,
  min: number,
  max: number,
): number {
  const raw = data[key];
  if (typeof raw !== 'number' || !Number.isFinite(raw)) {
    throw new HttpsError('invalid-argument', `${label} must be a number.`);
  }
  if (raw < min || raw > max) {
    throw new HttpsError(
      'invalid-argument',
      `${label} must be between ${min} and ${max}.`,
    );
  }
  return raw;
}
