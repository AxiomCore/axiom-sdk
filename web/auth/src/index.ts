// @axiomcore/auth-web: browser client for Axiom project authentication
// (auth-surfaces/v1 "Web client", auth-core/v1 "Public protocol").
//
// Erasable TypeScript only (no enums, namespaces or parameter properties), so the
// build is a plain type strip. No runtime dependencies: WebCrypto and fetch.
//
// Secrets live only in the closure of createAxiomAuth: the access token (pushed out
// through onTokens), the refresh token (also written to the storage adapter) and a
// captured password-reset token. Nothing is placed on the global object.

export type AuthStatus = 'unknown' | 'loading' | 'error' | 'anonymous' | 'authenticated' | 'expired' | 'refreshing';
export interface PublicPrincipal { subject: string; tenant: string | null; roles: string[]; permissions: string[] }
export interface PublicSession { id: string; status: AuthStatus; principal: PublicPrincipal | null }
export interface AuthUser { id: string; kind: 'password' | 'external'; email?: string; emailVerified: boolean; hasPassword: boolean; providers: string[] }
export type AuthErrorCode = string;
export interface RefreshRecord { refreshToken: string; refreshExpiresAt: string; issuer: string; audience: string; sessionId: string }
export interface AuthStorageAdapter {
  get(key: string): Promise<RefreshRecord | null>;
  set(key: string, value: RefreshRecord): Promise<void>;
  remove(key: string): Promise<void>;
  readonly shared: boolean;
}

interface StorageLike {
  readonly length: number;
  key(index: number): string | null;
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

interface LockManagerLike {
  request<T>(name: string, callback: () => Promise<T>): Promise<T>;
}

export interface AuthGlobals {
  location?: { readonly href: string; readonly origin: string; assign(url: string): void };
  history?: { readonly state: unknown; replaceState(state: unknown, unused: string, url?: string): void };
  localStorage?: StorageLike;
  sessionStorage?: StorageLike;
  navigator?: { readonly locks?: LockManagerLike };
  document?: { readonly visibilityState?: string; addEventListener?(type: string, listener: () => void): void };
  crypto?: { getRandomValues<T extends ArrayBufferView>(array: T): T; readonly subtle: { digest(algorithm: string, data: ArrayBufferView): Promise<ArrayBuffer> } };
}

export interface AxiomAuthOptions {
  issuer: string;
  audience?: string;
  redirectUri?: string;
  storage?: AuthStorageAdapter;
  onTokens?: (accessToken: string | null) => void;
  fetch?: typeof fetch;
  clock?: () => number;
  logoutUri?: string;
  globalObject?: AuthGlobals;
  setTimeout?: (callback: () => void, ms: number) => unknown;
  clearTimeout?: (handle: unknown) => void;
}

export interface AxiomAuth {
  session(): PublicSession;
  user(): Promise<AuthUser | null>;
  subscribe(listener: (s: PublicSession) => void): () => void;
  restore(): Promise<PublicSession>;
  signUp(email: string, password: string): Promise<{ status: 'signed_in' | 'verification_sent'; challenge?: string; resendAfterSeconds?: number }>;
  verifySignUp(challenge: string, code: string): Promise<PublicSession>;
  signInWithPassword(email: string, password: string, opts?: { tenant?: string }): Promise<PublicSession>;
  requestEmailCode(email: string): Promise<{ challenge: string; resendAfterSeconds: number }>;
  verifyEmailCode(challenge: string, code: string): Promise<PublicSession>;
  requestMagicLink(email: string, opts?: { returnTo?: string }): Promise<{ sent: true }>;
  signInWithProvider(provider: string, opts?: { returnTo?: string }): Promise<never>;
  signInHosted(opts?: { returnTo?: string }): Promise<never>;
  handleRedirect(url?: string): Promise<{ handled: boolean; returnTo?: string }>;
  refresh(opts?: { tenant?: string }): Promise<PublicSession>;
  signOut(opts?: { everywhere?: boolean; redirect?: boolean; returnTo?: string }): Promise<PublicSession>;
  changePassword(current: string, next: string): Promise<void>;
  requestPasswordReset(email: string): Promise<{ sent: true }>;
  confirmPasswordReset(password: string): Promise<void>;
  selectTenant(tenant: string | null): Promise<PublicSession>;
  authorizationHeader(): Promise<string | null>;
  toJSON(): { issuer: string; session: PublicSession };
}

// Codes of auth-core/v1 and auth-surfaces/v1 "Public protocol additions". Any other
// value, a missing code or a network failure maps to "unavailable".
const KNOWN_CODES = new Set([
  'INVALID_REQUEST', 'WEAK_PASSWORD', 'INVALID_CREDENTIALS', 'INVALID_REFRESH', 'INVALID_TOKEN',
  'USER_DISABLED', 'SIGNUP_DISABLED', 'TENANT_DENIED', 'ORIGIN', 'NOT_FOUND', 'ACCOUNT_EXISTS',
  'REFRESH_TOO_SOON', 'RATE_LIMITED', 'QUOTA', 'RESERVE_EXHAUSTED', 'UNAVAILABLE', 'FORBIDDEN',
  'CONFLICT', 'LIMIT', 'KEY_LIMIT', 'TOO_MANY_PERMISSIONS', 'ISSUER_SCOPE',
  'INVALID_CODE', 'INVALID_GRANT', 'REDIRECT_URI', 'CAPTCHA', 'REAUTH_REQUIRED', 'EMAIL_UNVERIFIED',
  'METHOD_DISABLED', 'ACCOUNT_LINK_REQUIRED', 'IDENTITY_LINKED', 'LAST_METHOD', 'UPGRADE_PENDING',
]);

// Redirect outcomes keep their names (auth-surfaces/v1 "Error names").
const REDIRECT_OUTCOMES = new Set([
  'invalid_request', 'access_denied', 'provider_error', 'temporarily_unavailable',
  'account_link_required', 'identity_linked', 'signup_disabled', 'user_disabled', 'quota', 'method_disabled',
]);

const TX_PREFIX = 'axiom-auth:tx:';
const RETURN_KEY = 'axiom-auth:return';
const TX_MAX_PENDING = 4;
const TX_LIFETIME_MS = 15 * 60 * 1000;
const EXP_MARGIN_MS = 60 * 1000;
const ROTATION_MARGIN_MS = 120 * 1000;
const JITTER_MAX_MS = 10 * 1000;
const DEFAULT_RETRY_MS = 30 * 1000;
const CALLBACK_QUERY = ['code', 'state', 'iss', 'error', 'error_code'];

export class AxiomAuthError extends Error {
  readonly code: AuthErrorCode;
  readonly status: number;
  readonly retryAfterSeconds?: number;
  constructor(code: AuthErrorCode, status?: number, retryAfterSeconds?: number) {
    super(code);
    this.name = 'AxiomAuthError';
    this.code = code;
    this.status = status ?? 0;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function mapErrorCode(raw: unknown): AuthErrorCode {
  if (typeof raw === 'string' && raw.startsWith('AXAUTH_')) {
    const name = raw.slice(7);
    if (KNOWN_CODES.has(name)) return name.toLowerCase();
  }
  return 'unavailable';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isRefreshRecord(value: unknown): value is RefreshRecord {
  return isRecord(value) && typeof value.refreshToken === 'string' && typeof value.refreshExpiresAt === 'string'
    && typeof value.issuer === 'string' && typeof value.audience === 'string' && typeof value.sessionId === 'string';
}

function copyRecord(r: RefreshRecord): RefreshRecord {
  return { refreshToken: r.refreshToken, refreshExpiresAt: r.refreshExpiresAt, issuer: r.issuer, audience: r.audience, sessionId: r.sessionId };
}

export const memoryStorage = (): AuthStorageAdapter => {
  const slots = new Map<string, RefreshRecord>();
  return Object.freeze({
    shared: false,
    async get(key: string): Promise<RefreshRecord | null> {
      const r = slots.get(key);
      return r ? copyRecord(r) : null;
    },
    async set(key: string, value: RefreshRecord): Promise<void> {
      slots.set(key, copyRecord(value));
    },
    async remove(key: string): Promise<void> {
      slots.delete(key);
    },
  });
};

export const sessionStorageAdapter = (target?: StorageLike): AuthStorageAdapter => {
  const store = (): StorageLike => {
    const s = target ?? (globalThis as { sessionStorage?: StorageLike }).sessionStorage;
    if (!s) throw new AxiomAuthError('unavailable', 0);
    return s;
  };
  return Object.freeze({
    shared: false,
    async get(key: string): Promise<RefreshRecord | null> {
      const raw = store().getItem(key);
      if (raw === null) return null;
      try {
        const parsed: unknown = JSON.parse(raw);
        return isRefreshRecord(parsed) ? copyRecord(parsed) : null;
      } catch {
        return null;
      }
    },
    async set(key: string, value: RefreshRecord): Promise<void> {
      store().setItem(key, JSON.stringify(copyRecord(value)));
    },
    async remove(key: string): Promise<void> {
      store().removeItem(key);
    },
  });
};

function base64url(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeBase64url(text: string): Uint8Array {
  const b64 = text.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

interface Claims { sub: string; aud: string | null; tenant: string | null; roles: string[]; permissions: string[]; iat: number; exp: number }

// Decoded for display and scheduling only; the access token is never verified here.
function decodeClaims(token: string): Claims | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  let payload: unknown;
  try {
    payload = JSON.parse(new TextDecoder().decode(decodeBase64url(parts[1])));
  } catch {
    return null;
  }
  if (!isRecord(payload)) return null;
  const { sub, iat, exp } = payload;
  if (typeof sub !== 'string' || typeof iat !== 'number' || typeof exp !== 'number') return null;
  const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
  return {
    sub,
    aud: typeof payload.aud === 'string' ? payload.aud : null,
    tenant: typeof payload.tenant === 'string' ? payload.tenant : null,
    roles: strings(payload.roles),
    permissions: strings(payload.permissions),
    iat,
    exp,
  };
}

// auth-surfaces/v1 "returnTo" (security S-9).
function validReturnTo(value: unknown, origin: string): value is string {
  if (typeof value !== 'string' || value.length === 0) return false;
  if (value[0] !== '/' || value[1] === '/' || value[1] === '\\') return false;
  if (value.includes('\\')) return false;
  if (/[\u0000-\u001f\u007f]/.test(value)) return false;
  try {
    return new URL(value, origin).origin === origin;
  } catch {
    return false;
  }
}

function parseRetryAfter(header: string | null, now: number): number | undefined {
  if (header === null) return undefined;
  const text = header.trim();
  if (/^\d+$/.test(text)) return Number(text);
  const at = Date.parse(text);
  if (Number.isNaN(at)) return undefined;
  return Math.max(0, Math.ceil((at - now) / 1000));
}

interface Transaction {
  v: 1; state: string; verifier: string; kind: 'provider' | 'hosted' | 'magic_link'; provider: string | null;
  issuer: string; audience: string | null; redirectUri: string; returnTo: string | null; createdAt: number;
}

function isTransaction(value: unknown): value is Transaction {
  return isRecord(value) && value.v === 1 && typeof value.state === 'string' && typeof value.verifier === 'string'
    && (value.kind === 'provider' || value.kind === 'hosted' || value.kind === 'magic_link')
    && typeof value.issuer === 'string' && typeof value.redirectUri === 'string' && typeof value.createdAt === 'number';
}

interface Held {
  accessToken: string | null;
  claims: Claims | null;
  refreshToken: string;
  refreshExpiresAt: number;
  sessionId: string;
  audience: string;
  rotationAnchorMs: number;
  rotationIntervalMs: number;
}

export function createAxiomAuth(options: AxiomAuthOptions): AxiomAuth {
  if (!options || typeof options.issuer !== 'string') throw new TypeError('issuer is required');
  const issuer = options.issuer;
  new URL(issuer); // throws on a malformed issuer
  const redirectUri = options.redirectUri;
  const redirect = redirectUri ? new URL(redirectUri) : null;
  const logoutUri = options.logoutUri;
  const storage = options.storage ?? memoryStorage();
  const g: AuthGlobals = options.globalObject ?? (globalThis as unknown as AuthGlobals);
  const clock = options.clock ?? (() => Date.now());
  const fetchFn: typeof fetch = options.fetch ?? ((input, init) => globalThis.fetch(input, init));
  const setT = options.setTimeout ?? ((cb: () => void, ms: number): unknown => globalThis.setTimeout(cb, ms));
  const clearT = options.clearTimeout ?? ((h: unknown): void => globalThis.clearTimeout(h as ReturnType<typeof setTimeout>));
  const onTokens = options.onTokens;
  const storageKey = 'axiom-auth:refresh:' + issuer;
  const lockName = 'axiom-auth:' + issuer;

  let held: Held | null = null;
  let generation = 0;
  let current: PublicSession = Object.freeze({ id: '', status: 'unknown' as AuthStatus, principal: null });
  const listeners = new Set<(s: PublicSession) => void>();
  let inflight: Promise<PublicSession> | null = null;
  let timer: unknown = undefined;
  let retryNotBefore = 0;
  let retryCode: AuthErrorCode = 'unavailable';
  let resetToken: string | null = null;

  const cryptoApi = () => {
    const c = g.crypto ?? (globalThis as unknown as AuthGlobals).crypto;
    if (!c) throw new AxiomAuthError('unavailable', 0);
    return c;
  };
  const randomToken = (): string => base64url(cryptoApi().getRandomValues(new Uint8Array(32)));
  const jitter = (): number => cryptoApi().getRandomValues(new Uint32Array(1))[0] % (JITTER_MAX_MS + 1);
  const s256 = async (verifier: string): Promise<string> =>
    base64url(new Uint8Array(await cryptoApi().subtle.digest('SHA-256', new TextEncoder().encode(verifier))));

  // Session projection

  function emit(next: PublicSession): void {
    if (next.id === current.id && next.status === current.status && next.principal === current.principal) return;
    current = Object.freeze(next);
    for (const listener of Array.from(listeners)) {
      try {
        listener(current);
      } catch {
        // A listener failure never breaks the client.
      }
    }
  }

  function principalOf(claims: Claims): PublicPrincipal {
    const prev = current.principal;
    const same = (a: string[], b: string[]) => a.length === b.length && a.every((x, i) => x === b[i]);
    if (prev && prev.subject === claims.sub && prev.tenant === claims.tenant && same(prev.roles, claims.roles) && same(prev.permissions, claims.permissions)) {
      return prev;
    }
    return Object.freeze({
      subject: claims.sub,
      tenant: claims.tenant,
      roles: Object.freeze(claims.roles.slice()) as string[],
      permissions: Object.freeze(claims.permissions.slice()) as string[],
    });
  }

  function publishHeld(): void {
    if (held && held.claims) emit({ id: held.sessionId, status: 'authenticated', principal: principalOf(held.claims) });
  }

  function publishStatus(status: AuthStatus): void {
    if (status === 'anonymous' || status === 'expired' || status === 'unknown') {
      emit({ id: '', status, principal: null });
    } else {
      emit({ id: current.id, status, principal: current.principal });
    }
  }

  function pushToken(token: string | null): void {
    if (!onTokens) return;
    try {
      onTokens(token);
    } catch {
      // The sink is the host's; its failure is not ours to report.
    }
  }

  // Drops every credential held in memory and tells the transport sink.
  function dropCredentials(status: 'anonymous' | 'expired'): void {
    held = null;
    generation++;
    cancelTimer();
    retryNotBefore = 0;
    pushToken(null);
    publishStatus(status);
  }

  async function removeRecord(): Promise<void> {
    try {
      await storage.remove(storageKey);
    } catch {
      // Best effort; the record can no longer rotate once the session is ended.
    }
  }

  // Transport

  async function call(method: 'GET' | 'POST', path: string, body?: Record<string, unknown>, bearer?: string): Promise<{ status: number; data: unknown }> {
    const headers: Record<string, string> = { Accept: 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (bearer !== undefined) headers.Authorization = 'Bearer ' + bearer;
    const init: RequestInit = {
      method,
      headers,
      credentials: 'omit',
      cache: 'no-store',
      redirect: 'error',
      referrerPolicy: 'no-referrer',
    };
    if (body !== undefined) init.body = JSON.stringify(body);
    let response: Response;
    try {
      response = await fetchFn(issuer + path, init);
    } catch {
      throw new AxiomAuthError('unavailable', 0);
    }
    let text = '';
    try {
      text = await response.text();
    } catch {
      throw new AxiomAuthError('unavailable', response.status);
    }
    let data: unknown = null;
    let parsed = true;
    if (text.length > 0) {
      try {
        data = JSON.parse(text);
      } catch {
        parsed = false;
      }
    }
    if (response.status >= 200 && response.status < 300) {
      if (!parsed) throw new AxiomAuthError('unavailable', response.status);
      return { status: response.status, data };
    }
    const code = parsed && isRecord(data) && isRecord(data.error) ? mapErrorCode(data.error.code) : 'unavailable';
    throw new AxiomAuthError(code, response.status, parseRetryAfter(response.headers.get('Retry-After'), clock()));
  }

  function withAudience(body: Record<string, unknown>): Record<string, unknown> {
    if (options.audience !== undefined) body.audience = options.audience;
    return body;
  }

  // Validates a token response and turns it into the private slot. `previous` is the
  // slot the request presented, for early-refresh detection.
  function heldFrom(data: unknown, previous: Held | null): Held {
    if (!isRecord(data) || typeof data.access_token !== 'string' || typeof data.refresh_token !== 'string'
      || typeof data.refresh_expires_at !== 'string' || !isRecord(data.session) || typeof data.session.id !== 'string') {
      throw new AxiomAuthError('unavailable', 0);
    }
    const claims = decodeClaims(data.access_token);
    const refreshExpiresAt = Date.parse(data.refresh_expires_at);
    if (!claims || Number.isNaN(refreshExpiresAt)) throw new AxiomAuthError('unavailable', 0);
    const now = clock();
    let anchor = claims.iat * 1000;
    let interval = (claims.exp - claims.iat) * 1000 - ROTATION_MARGIN_MS;
    if (previous && previous.refreshToken === data.refresh_token && previous.rotationIntervalMs > 0) {
      // Early refresh: same refresh token, the rotation clock did not move. When the
      // anchor has already passed the issuer still saw a recent rotation, so wait a full
      // interval from now.
      interval = previous.rotationIntervalMs;
      anchor = previous.rotationAnchorMs + interval <= now ? now : previous.rotationAnchorMs;
    }
    return {
      accessToken: data.access_token,
      claims,
      refreshToken: data.refresh_token,
      refreshExpiresAt,
      sessionId: data.session.id,
      audience: claims.aud ?? options.audience ?? issuer + '/api',
      rotationAnchorMs: anchor,
      rotationIntervalMs: interval,
    };
  }

  async function persist(h: Held): Promise<void> {
    await storage.set(storageKey, {
      refreshToken: h.refreshToken,
      refreshExpiresAt: new Date(h.refreshExpiresAt).toISOString(),
      issuer,
      audience: h.audience,
      sessionId: h.sessionId,
    });
  }

  // A new session from a sign-in, verification or redirect completion.
  async function establish(data: unknown): Promise<PublicSession> {
    const next = heldFrom(data, null);
    generation++;
    held = next;
    retryNotBefore = 0;
    pushToken(next.accessToken);
    try {
      await persist(next);
    } catch {
      // The session works in memory; it only will not survive a reload.
    }
    if (held === next) {
      scheduleProactive();
      publishHeld();
    }
    return current;
  }

  // Timers

  function cancelTimer(): void {
    if (timer !== undefined) {
      clearT(timer);
      timer = undefined;
    }
  }

  function hidden(): boolean {
    return g.document?.visibilityState === 'hidden';
  }

  function scheduleAt(at: number): void {
    cancelTimer();
    if (!held || hidden()) return;
    const delay = Math.max(0, at - clock());
    timer = setT(() => {
      timer = undefined;
      if (hidden()) return;
      refresh().catch(() => undefined);
    }, delay);
  }

  function scheduleProactive(): void {
    if (!held || !held.claims) return;
    const exp = held.claims.exp * 1000;
    const at = held.rotationIntervalMs > 0 ? Math.min(exp - EXP_MARGIN_MS, held.rotationAnchorMs + held.rotationIntervalMs) : exp - EXP_MARGIN_MS;
    scheduleAt(at + jitter());
  }

  function onVisibility(): void {
    if (hidden()) {
      cancelTimer();
      return;
    }
    if (!held) return;
    const now = clock();
    if (retryNotBefore > now) {
      scheduleAt(retryNotBefore);
    } else if (!held.claims || now >= held.claims.exp * 1000 - EXP_MARGIN_MS) {
      refresh().catch(() => undefined);
    } else {
      scheduleProactive();
    }
  }

  try {
    g.document?.addEventListener?.('visibilitychange', onVisibility);
  } catch {
    // No document events: the timer alone drives refresh.
  }

  // Refresh

  function refresh(opts?: { tenant?: string }): Promise<PublicSession> {
    const tenant = opts?.tenant;
    if (inflight) {
      if (tenant === undefined) return inflight;
      return inflight.catch(() => undefined).then(() => refresh(opts));
    }
    const p: Promise<PublicSession> = rotate(tenant).finally(() => {
      if (inflight === p) inflight = null;
    });
    inflight = p;
    return p;
  }

  async function rotate(tenant?: string): Promise<PublicSession> {
    if (!held) throw new AxiomAuthError('invalid_refresh', 0);
    const now = clock();
    if (now >= held.refreshExpiresAt) {
      dropCredentials('expired');
      await removeRecord();
      throw new AxiomAuthError('invalid_refresh', 0);
    }
    if (retryNotBefore > now) {
      throw new AxiomAuthError(retryCode, 0, Math.ceil((retryNotBefore - now) / 1000));
    }
    const gen = generation;
    cancelTimer();
    publishStatus(held.claims ? 'refreshing' : 'loading');

    const run = async (): Promise<void> => {
      if (!held || generation !== gen) throw new AxiomAuthError('invalid_refresh', 0);
      if (storage.shared) {
        // Another tab may have rotated (or ended) the family while we waited.
        const record = await storage.get(storageKey);
        if (!held || generation !== gen) throw new AxiomAuthError('invalid_refresh', 0);
        if (!record || record.issuer !== issuer) {
          dropCredentials('expired');
          throw new AxiomAuthError('invalid_refresh', 0);
        }
        if (record.refreshToken !== held.refreshToken) {
          const adoptedExpiry = Date.parse(record.refreshExpiresAt);
          held = {
            ...held,
            refreshToken: record.refreshToken,
            refreshExpiresAt: Number.isNaN(adoptedExpiry) ? 0 : adoptedExpiry,
            sessionId: record.sessionId,
            audience: record.audience,
            // The other tab rotated: our anchor is stale, the next timer follows its token.
            rotationAnchorMs: clock(),
          };
        }
        if (clock() >= held.refreshExpiresAt) {
          dropCredentials('expired');
          await removeRecord();
          throw new AxiomAuthError('invalid_refresh', 0);
        }
      }
      const presented = held;
      const body: Record<string, unknown> = { refresh_token: presented.refreshToken };
      if (tenant !== undefined) body.tenant = tenant;
      const { data } = await call('POST', '/v1/token/refresh', withAudience(body));
      if (generation !== gen || held !== presented) return;
      const next = heldFrom(data, presented);
      held = next;
      if (next.refreshToken !== presented.refreshToken || storage.shared) await persist(next);
      else await persist(next).catch(() => undefined);
      if (held !== next) return;
      retryNotBefore = 0;
      pushToken(next.accessToken);
    };

    try {
      const locks = g.navigator?.locks;
      if (storage.shared && locks) await locks.request(lockName, run);
      else await run();
    } catch (err) {
      const e = err instanceof AxiomAuthError ? err : new AxiomAuthError('unavailable', 0);
      if (generation !== gen) throw e;
      if (e.code === 'invalid_refresh') {
        if (held) dropCredentials('expired');
        await removeRecord();
        throw e;
      }
      if (!held) throw e;
      if (e.code === 'unavailable' || e.code === 'rate_limited') {
        retryCode = e.code;
        retryNotBefore = clock() + (e.retryAfterSeconds !== undefined ? e.retryAfterSeconds * 1000 : DEFAULT_RETRY_MS);
        scheduleAt(retryNotBefore);
      } else if (e.code === 'refresh_too_soon') {
        // Back off to the next rotation interval.
        held = { ...held, rotationAnchorMs: clock() };
        scheduleProactive();
      } else {
        scheduleProactive();
      }
      if (held.claims) publishHeld();
      else publishStatus('error');
      throw e;
    }
    if (generation === gen && held) {
      scheduleProactive();
      publishHeld();
    }
    return current;
  }

  async function freshAccessToken(): Promise<string | null> {
    if (!held) return null;
    if (!held.accessToken || !held.claims || clock() >= held.claims.exp * 1000 - EXP_MARGIN_MS) {
      try {
        await refresh();
      } catch {
        // Fall through: an unexpired token is still usable.
      }
    }
    if (!held || !held.accessToken || !held.claims || clock() >= held.claims.exp * 1000) return null;
    return held.accessToken;
  }

  // PKCE transactions in localStorage

  function txKeys(): string[] {
    const ls = g.localStorage;
    if (!ls) return [];
    const keys: string[] = [];
    for (let i = 0; i < ls.length; i++) {
      const k = ls.key(i);
      if (k !== null && k.startsWith(TX_PREFIX)) keys.push(k);
    }
    return keys;
  }

  function readTx(key: string): Transaction | null {
    try {
      const raw = g.localStorage?.getItem(key);
      if (raw === null || raw === undefined) return null;
      const parsed: unknown = JSON.parse(raw);
      return isTransaction(parsed) ? parsed : null;
    } catch {
      return null;
    }
  }

  function txLive(tx: Transaction, now: number): boolean {
    return now - tx.createdAt < TX_LIFETIME_MS && tx.createdAt - now < TX_LIFETIME_MS;
  }

  function purgeTransactions(): void {
    try {
      const now = clock();
      for (const key of txKeys()) {
        const tx = readTx(key);
        if (!tx || !txLive(tx, now) || key !== TX_PREFIX + tx.state) g.localStorage?.removeItem(key);
      }
    } catch {
      // Storage unavailable: nothing to purge.
    }
  }

  async function beginTransaction(kind: Transaction['kind'], provider: string | null, returnTo: string | undefined): Promise<{ tx: Transaction; challenge: string }> {
    if (!redirectUri) throw new AxiomAuthError('redirect_uri', 0);
    const ls = g.localStorage;
    if (!ls) throw new AxiomAuthError('unavailable', 0);
    purgeTransactions();
    const origin = g.location?.origin ?? '';
    const tx: Transaction = {
      v: 1,
      state: randomToken(),
      verifier: randomToken(),
      kind,
      provider,
      issuer,
      audience: options.audience ?? null,
      redirectUri,
      returnTo: validReturnTo(returnTo, origin) ? returnTo : null,
      createdAt: clock(),
    };
    const challenge = await s256(tx.verifier);
    try {
      const pending = txKeys()
        .map((key) => ({ key, tx: readTx(key) }))
        .sort((a, b) => (a.tx?.createdAt ?? 0) - (b.tx?.createdAt ?? 0));
      while (pending.length >= TX_MAX_PENDING) {
        const oldest = pending.shift();
        if (oldest) ls.removeItem(oldest.key);
      }
      ls.setItem(TX_PREFIX + tx.state, JSON.stringify(tx));
    } catch {
      throw new AxiomAuthError('unavailable', 0);
    }
    return { tx, challenge };
  }

  // Loads and deletes (before use) the transaction for `state`.
  function takeTransaction(state: string | null): Transaction | null {
    if (state === null || state.length === 0) return null;
    const key = TX_PREFIX + state;
    const tx = readTx(key);
    try {
      g.localStorage?.removeItem(key);
    } catch {
      return null;
    }
    if (!tx || tx.state !== state || !txLive(tx, clock())) return null;
    return tx;
  }

  function startUrl(path: string, tx: Transaction, challenge: string): string {
    const u = new URL(issuer + path);
    u.searchParams.set('redirect_uri', tx.redirectUri);
    u.searchParams.set('state', tx.state);
    u.searchParams.set('code_challenge', challenge);
    u.searchParams.set('code_challenge_method', 'S256');
    return u.href;
  }

  function navigate(url: string): void {
    if (!g.location) throw new AxiomAuthError('unavailable', 0);
    g.location.assign(url);
  }

  // Redirect completion

  function handleRedirect(url?: string): Promise<{ handled: boolean; returnTo?: string }> {
    // Everything up to the first fetch runs synchronously, so the URL is clean before
    // any app code can observe it.
    let parsed: URL;
    try {
      parsed = new URL(url ?? g.location?.href ?? '');
    } catch {
      return Promise.resolve({ handled: false });
    }
    if (!redirect || parsed.origin !== redirect.origin || parsed.pathname !== redirect.pathname) {
      return Promise.resolve({ handled: false });
    }
    const query = parsed.searchParams;
    const fragment = new URLSearchParams(parsed.hash.slice(1));
    const viaQuery = query.has('code') || query.has('error');
    const link = fragment.get('axiom_link');
    const reset = fragment.get('axiom_reset');
    if (!viaQuery && link === null && reset === null) return Promise.resolve({ handled: false });

    const clean = new URL(parsed.href);
    for (const name of CALLBACK_QUERY) clean.searchParams.delete(name);
    if (Array.from(fragment.keys()).some((k) => k.startsWith('axiom_') || k === 'state')) clean.hash = '';
    try {
      g.history?.replaceState(g.history.state, '', clean.pathname + clean.search + clean.hash);
    } catch {
      // A history failure must not leave the flow half done; the code is single use.
    }

    if (!viaQuery && link === null) {
      resetToken = reset;
      return Promise.resolve({ handled: true });
    }

    const tx = takeTransaction(viaQuery ? query.get('state') : fragment.get('state'));
    if (!tx || tx.issuer !== issuer || tx.redirectUri !== redirectUri) {
      return Promise.reject(new AxiomAuthError('state_mismatch', 0));
    }
    const origin = g.location?.origin ?? parsed.origin;
    const returnTo = validReturnTo(tx.returnTo, origin) ? tx.returnTo : undefined;

    let path: string;
    let body: Record<string, unknown>;
    if (viaQuery) {
      if (tx.kind === 'magic_link') return Promise.reject(new AxiomAuthError('state_mismatch', 0));
      if (query.get('iss') !== issuer) return Promise.reject(new AxiomAuthError('invalid_grant', 0));
      const outcome = query.get('error');
      if (outcome !== null) {
        return Promise.reject(new AxiomAuthError(REDIRECT_OUTCOMES.has(outcome) ? outcome : 'unavailable', 0));
      }
      const code = query.get('code');
      if (!code) return Promise.reject(new AxiomAuthError('invalid_grant', 0));
      path = '/v1/token/authorization-code';
      body = withAudience({ code, code_verifier: tx.verifier, redirect_uri: redirectUri });
    } else {
      if (tx.kind !== 'magic_link') return Promise.reject(new AxiomAuthError('state_mismatch', 0));
      path = '/v1/email/link/verify';
      body = withAudience({ token: link, code_verifier: tx.verifier });
    }
    return call('POST', path, body)
      .then(({ data }) => establish(data))
      .then(() => (returnTo === undefined ? { handled: true } : { handled: true, returnTo }));
  }

  function isCallbackLocation(): boolean {
    if (!redirect || !g.location) return false;
    try {
      const u = new URL(g.location.href);
      if (u.origin !== redirect.origin || u.pathname !== redirect.pathname) return false;
      const f = new URLSearchParams(u.hash.slice(1));
      return u.searchParams.has('code') || u.searchParams.has('error') || f.has('axiom_link') || f.has('axiom_reset');
    } catch {
      return false;
    }
  }

  async function restoreStored(): Promise<PublicSession> {
    if (held) return current;
    publishStatus('loading');
    let record: RefreshRecord | null = null;
    try {
      record = await storage.get(storageKey);
    } catch {
      record = null;
    }
    if (held) return current;
    if (!record || !isRefreshRecord(record) || record.issuer !== issuer
      || (options.audience !== undefined && record.audience !== options.audience)) {
      publishStatus('anonymous');
      return current;
    }
    const expiresAt = Date.parse(record.refreshExpiresAt);
    if (Number.isNaN(expiresAt) || clock() >= expiresAt) {
      await removeRecord();
      dropCredentials('expired');
      return current;
    }
    generation++;
    held = {
      accessToken: null,
      claims: null,
      refreshToken: record.refreshToken,
      refreshExpiresAt: expiresAt,
      sessionId: record.sessionId,
      audience: record.audience,
      rotationAnchorMs: 0,
      rotationIntervalMs: 0,
    };
    try {
      await refresh();
    } catch {
      // The status says what happened: expired, or error with a retry scheduled.
    }
    return current;
  }

  function restore(): Promise<PublicSession> {
    purgeTransactions();
    if (isCallbackLocation()) {
      return handleRedirect().then(() => restoreStored());
    }
    return restoreStored();
  }

  purgeTransactions();

  const api: AxiomAuth = {
    session: () => current,

    async user(): Promise<AuthUser | null> {
      const token = await freshAccessToken();
      if (!token) return null;
      const { data } = await call('GET', '/v1/user', undefined, token);
      if (!isRecord(data) || typeof data.id !== 'string' || (data.kind !== 'password' && data.kind !== 'external')) {
        throw new AxiomAuthError('unavailable', 0);
      }
      const providers: string[] = [];
      if (Array.isArray(data.identities)) {
        for (const identity of data.identities) {
          if (isRecord(identity) && typeof identity.provider === 'string' && !providers.includes(identity.provider)) {
            providers.push(identity.provider);
          }
        }
      }
      const user: AuthUser = {
        id: data.id,
        kind: data.kind,
        emailVerified: data.email_verified === true,
        hasPassword: data.has_password === true,
        providers,
      };
      if (typeof data.email === 'string') user.email = data.email;
      return user;
    },

    subscribe(listener: (s: PublicSession) => void): () => void {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    restore,

    async signUp(email: string, password: string) {
      const { data } = await call('POST', '/v1/signup', withAudience({ email, password }));
      if (isRecord(data) && typeof data.access_token === 'string') {
        await establish(data);
        return { status: 'signed_in' as const };
      }
      if (!isRecord(data) || typeof data.challenge_id !== 'string') throw new AxiomAuthError('unavailable', 0);
      const out: { status: 'verification_sent'; challenge: string; resendAfterSeconds?: number } = { status: 'verification_sent', challenge: data.challenge_id };
      if (typeof data.resend_after === 'number') out.resendAfterSeconds = data.resend_after;
      return out;
    },

    async verifySignUp(challenge: string, code: string) {
      const { data } = await call('POST', '/v1/signup/verify', withAudience({ challenge_id: challenge, code }));
      return establish(data);
    },

    async signInWithPassword(email: string, password: string, opts?: { tenant?: string }) {
      const body: Record<string, unknown> = { email, password };
      if (opts?.tenant !== undefined) body.tenant = opts.tenant;
      const { data } = await call('POST', '/v1/sign-in/password', withAudience(body));
      return establish(data);
    },

    async requestEmailCode(email: string) {
      const { data } = await call('POST', '/v1/email/code', { email });
      if (!isRecord(data) || typeof data.challenge_id !== 'string') throw new AxiomAuthError('unavailable', 0);
      return { challenge: data.challenge_id, resendAfterSeconds: typeof data.resend_after === 'number' ? data.resend_after : 60 };
    },

    async verifyEmailCode(challenge: string, code: string) {
      const { data } = await call('POST', '/v1/email/code/verify', withAudience({ challenge_id: challenge, code }));
      return establish(data);
    },

    async requestMagicLink(email: string, opts?: { returnTo?: string }) {
      const { tx, challenge } = await beginTransaction('magic_link', null, opts?.returnTo);
      try {
        await call('POST', '/v1/email/link', {
          email,
          redirect_uri: tx.redirectUri,
          state: tx.state,
          code_challenge: challenge,
          code_challenge_method: 'S256',
        });
      } catch (err) {
        try {
          g.localStorage?.removeItem(TX_PREFIX + tx.state);
        } catch {
          // Purged at expiry anyway.
        }
        throw err;
      }
      return { sent: true as const };
    },

    async signInWithProvider(provider: string, opts?: { returnTo?: string }): Promise<never> {
      if (typeof provider !== 'string' || provider.length === 0) throw new AxiomAuthError('invalid_request', 0);
      const { tx, challenge } = await beginTransaction('provider', provider, opts?.returnTo);
      navigate(startUrl('/v1/providers/' + encodeURIComponent(provider) + '/start', tx, challenge));
      return new Promise<never>(() => undefined);
    },

    async signInHosted(opts?: { returnTo?: string }): Promise<never> {
      const { tx, challenge } = await beginTransaction('hosted', null, opts?.returnTo);
      navigate(startUrl('/sign-in', tx, challenge));
      return new Promise<never>(() => undefined);
    },

    handleRedirect,

    refresh,

    async signOut(opts?: { everywhere?: boolean; redirect?: boolean; returnTo?: string }) {
      if (inflight) {
        try {
          await inflight;
        } catch {
          // Sign-out proceeds whatever the rotation did.
        }
      }
      const refreshToken = held ? held.refreshToken : null;
      dropCredentials('anonymous');
      await removeRecord();
      if (refreshToken !== null) {
        const path = opts?.everywhere ? '/v1/logout-all' : '/v1/logout';
        for (let attempt = 0; attempt < 2; attempt++) {
          try {
            await call('POST', path, { refresh_token: refreshToken });
            break;
          } catch (err) {
            if (!(err instanceof AxiomAuthError) || err.status !== 0) break;
          }
        }
      }
      if (opts?.redirect && logoutUri) {
        const origin = g.location?.origin ?? '';
        try {
          if (validReturnTo(opts.returnTo, origin)) g.sessionStorage?.setItem(RETURN_KEY, opts.returnTo);
          else g.sessionStorage?.removeItem(RETURN_KEY);
        } catch {
          // The app falls back to its signed-out route.
        }
        const u = new URL(issuer + '/v1/logout');
        u.searchParams.set('post_logout_redirect_uri', logoutUri);
        u.searchParams.set('state', randomToken());
        navigate(u.href);
      }
      return current;
    },

    async changePassword(currentPassword: string, next: string): Promise<void> {
      const token = await freshAccessToken();
      if (!token) throw new AxiomAuthError('invalid_token', 0);
      await call('POST', '/v1/password', { current_password: currentPassword, new_password: next }, token);
    },

    async requestPasswordReset(email: string) {
      const body: Record<string, unknown> = { email };
      if (redirectUri) body.redirect_uri = redirectUri;
      await call('POST', '/v1/password/reset', body);
      return { sent: true as const };
    },

    async confirmPasswordReset(password: string): Promise<void> {
      const token = resetToken;
      if (token === null) throw new AxiomAuthError('invalid_code', 0);
      try {
        await call('POST', '/v1/password/reset/confirm', { token, new_password: password });
      } catch (err) {
        if (!(err instanceof AxiomAuthError) || err.code !== 'weak_password') resetToken = null;
        throw err;
      }
      resetToken = null;
    },

    selectTenant(tenant: string | null): Promise<PublicSession> {
      return refresh(tenant === null ? undefined : { tenant });
    },

    async authorizationHeader(): Promise<string | null> {
      const token = await freshAccessToken();
      return token === null ? null : 'Bearer ' + token;
    },

    toJSON() {
      return { issuer, session: current };
    },
  };
  return Object.freeze(api);
}
