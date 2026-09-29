/// Thin fetch wrapper for provider REST APIs: JSON in/out, a hard timeout,
/// and errors that carry the provider's own message (surfaced to the admin
/// on "Test connection" and logged for failed customer payments).

export class ProviderError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly body: unknown,
  ) {
    super(message);
  }
}

export async function callProvider<T = Record<string, unknown>>(
  url: string,
  init: {
    method?: string;
    headers?: Record<string, string>;
    json?: unknown;
    form?: Record<string, string>;
    timeoutMs?: number;
  } = {},
): Promise<T> {
  const headers: Record<string, string> = { ...(init.headers ?? {}) };
  let body: string | undefined;
  if (init.json !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(init.json);
  } else if (init.form !== undefined) {
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    body = new URLSearchParams(init.form).toString();
  }
  const response = await fetch(url, {
    method: init.method ?? (body ? 'POST' : 'GET'),
    headers,
    body,
    signal: AbortSignal.timeout(init.timeoutMs ?? 20000),
  });
  const text = await response.text();
  let parsed: unknown = text;
  try {
    parsed = text ? JSON.parse(text) : {};
  } catch {
    // Non-JSON error pages are kept as text.
  }
  if (!response.ok) {
    throw new ProviderError(
      extractMessage(parsed) ?? `HTTP ${response.status}`,
      response.status,
      parsed,
    );
  }
  return parsed as T;
}

function extractMessage(body: unknown): string | undefined {
  if (!body || typeof body !== 'object') {
    return typeof body === 'string' && body.length < 300 ? body : undefined;
  }
  const b = body as Record<string, any>;
  return (
    b.errorMessage ??
    b.error?.message ??
    b.error_description ??
    b.message ??
    b.details?.[0]?.description ??
    (typeof b.error === 'string' ? b.error : undefined)
  );
}

export function basicAuth(user: string, pass: string): string {
  return `Basic ${Buffer.from(`${user}:${pass}`).toString('base64')}`;
}
