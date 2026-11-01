// Generated from src/index.ts by scripts/build.mjs. Do not edit.
// @axiomcore/auth-web: browser client for Axiom project authentication
// (auth-surfaces/v1 "Web client", auth-core/v1 "Public protocol").
//
// Erasable TypeScript only (no enums, namespaces or parameter properties), so the
// build is a plain type strip. No runtime dependencies: WebCrypto and fetch.
//
// Secrets live only in the closure of createAxiomAuth: the access token (pushed out
// through onTokens), the refresh token (also written to the storage adapter) and a
// captured password-reset token. Nothing is placed on the global object.

// Codes of auth-core/v1 and auth-surfaces/v1 "Public protocol additions". Any other
// value, a missing code or a network failure maps to "unavailable".
const KNOWN_CODES = new Set([
  'INVALID_REQUEST', 'WEAK_PASSWORD', 'INVALID_CREDENTIALS', 'INVALID_REFRESH', 'INVALID_TOKEN',
  'USER_DISABLED', 'SIGNUP_DISABLED', 'TENANT_DENIED', 'ORIGIN', 'NOT_FOUND', 'ACCOUNT_EXISTS',
  'REFRESH_TOO_SOON', 'RATE_LIMITED', 'QUOTA', 'RESERVE_EXHAUSTED', 'UNAVAILABLE', 'FORBIDDEN',
  'CONFLICT', 'LIMIT', 'KEY_LIMIT', 'TOO_MANY_PERMISSIONS', 'ISSUER_SCOPE',
  'INVALID_CODE', 'INVALID_GRANT', 'REDIRECT_URI', 'CAPTCHA', 'REAUTH_REQUIRED', 'EMAIL_UNVERIFIED',
  'METHOD_DISABLED', 'ACCOUNT_LINK_REQUIRED', 'IDENTITY_LINKED', 'LAST_METHOD', 'UPGRADE_PENDING',
  // auth-advanced/v1 13
  'MFA_REQUIRED', 'MFA_ENROLLMENT_REQUIRED', 'STEP_UP_REQUIRED', 'WEBAUTHN', 'FACTOR_LIMIT', 'FACTOR_REQUIRED',
  'PHONE_NOT_ALLOWED', 'FEATURE_DISABLED', 'HOOK_FAILED',
]);

// Redirect outcomes keep their names (auth-surfaces/v1 "Error names").
const REDIRECT_OUTCOMES = new Set([
  'invalid_request', 'access_denied', 'provider_error', 'temporarily_unavailable',
  'account_link_required', 'identity_linked', 'signup_disabled', 'user_disabled', 'quota', 'method_disabled',
  'mfa_required', 'mfa_enrollment_required',
]);

const ACR_RANK                         = { aal1: 1, aal2: 2, phr: 3 };
const STEP_UP_METHODS = new Set(['password', 'totp', 'sms', 'recovery', 'passkey']);
const FACTOR_TYPES = new Set(['totp', 'passkey', 'sms']);
// Sealed MFA and enroll tickets (axs1), never shown to app code.
const TICKET_MAX = 4096;

const TX_PREFIX = 'axiom-auth:tx:';
const RETURN_KEY = 'axiom-auth:return';
const TX_MAX_PENDING = 4;
const TX_LIFETIME_MS = 15 * 60 * 1000;
const EXP_MARGIN_MS = 60 * 1000;
const ROTATION_MARGIN_MS = 120 * 1000;
const JITTER_MAX_MS = 10 * 1000;
const DEFAULT_RETRY_MS = 30 * 1000;
const CALLBACK_QUERY = ['code', 'state', 'iss', 'error', 'error_code', 'mfa_ticket', 'enroll_ticket'];

export class AxiomAuthError extends Error {
  code;
  status;
  retryAfterSeconds;
  constructor(code               , status         , retryAfterSeconds         ) {
    super(code);
    this.name = 'AxiomAuthError';
    this.code = code;
    this.status = status ?? 0;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function mapErrorCode(raw         )                {
  if (typeof raw === 'string' && raw.startsWith('AXAUTH_')) {
    const name = raw.slice(7);
    if (KNOWN_CODES.has(name)) return name.toLowerCase();
  }
  return 'unavailable';
}

function isRecord(value         )                                   {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isRefreshRecord(value         )                         {
  return isRecord(value) && typeof value.refreshToken === 'string' && typeof value.refreshExpiresAt === 'string'
    && typeof value.issuer === 'string' && typeof value.audience === 'string' && typeof value.sessionId === 'string';
}

function copyRecord(r               )                {
  return { refreshToken: r.refreshToken, refreshExpiresAt: r.refreshExpiresAt, issuer: r.issuer, audience: r.audience, sessionId: r.sessionId };
}

export const memoryStorage = ()                     => {
  const slots = new Map                       ();
  return Object.freeze({
    shared: false,
    async get(key        )                                {
      const r = slots.get(key);
      return r ? copyRecord(r) : null;
    },
    async set(key        , value               )                {
      slots.set(key, copyRecord(value));
    },
    async remove(key        )                {
      slots.delete(key);
    },
  });
};

export const sessionStorageAdapter = (target              )                     => {
  const store = ()              => {
    const s = target ?? (globalThis                                    ).sessionStorage;
    if (!s) throw new AxiomAuthError('unavailable', 0);
    return s;
  };
  return Object.freeze({
    shared: false,
    async get(key        )                                {
      const raw = store().getItem(key);
      if (raw === null) return null;
      try {
        const parsed          = JSON.parse(raw);
        return isRefreshRecord(parsed) ? copyRecord(parsed) : null;
      } catch {
        return null;
      }
    },
    async set(key        , value               )                {
      store().setItem(key, JSON.stringify(copyRecord(value)));
    },
    async remove(key        )                {
      store().removeItem(key);
    },
  });
};

function base64url(bytes            )         {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeBase64url(text        )             {
  const b64 = text.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// Decoded for display and scheduling only; the access token is never verified here.
function decodeClaims(token        )                {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  let payload         ;
  try {
    payload = JSON.parse(new TextDecoder().decode(decodeBase64url(parts[1])));
  } catch {
    return null;
  }
  if (!isRecord(payload)) return null;
  const { sub, iat, exp } = payload;
  if (typeof sub !== 'string' || typeof iat !== 'number' || typeof exp !== 'number') return null;
  const strings = (v         )           => (Array.isArray(v) ? v.filter((x)              => typeof x === 'string') : []);
  return {
    sub,
    aud: typeof payload.aud === 'string' ? payload.aud : null,
    tenant: typeof payload.tenant === 'string' ? payload.tenant : null,
    roles: strings(payload.roles),
    permissions: strings(payload.permissions),
    iat,
    exp,
    // W7.1 issuers omit `acr`: absent means aal1 (auth-advanced/v1 7.4).
    acr: payload.acr === 'aal2' || payload.acr === 'phr' ? payload.acr : 'aal1',
    authTime: typeof payload.auth_time === 'number' ? payload.auth_time : iat,
  };
}

// Error bodies that carry a sealed ticket. The ticket is read once into the client's
// closure; the error the caller sees never holds it.
const challengeBodies = new WeakMap                                 ();

// RFC 9470: `WWW-Authenticate: Bearer error="insufficient_user_authentication", acr_values="aal2", max_age=600`.
export function parseStepUpChallenge(response          )                                        {
  let header                = null;
  try {
    header = response.headers.get('WWW-Authenticate');
  } catch {
    return null;
  }
  if (header === null || !/^\s*Bearer\b/i.test(header)) return null;
  const params = new Map                ();
  const re = /([A-Za-z_]+)\s*=\s*(?:"([^"]*)"|([^\s,]+))/g;
  let m                        ;
  while ((m = re.exec(header)) !== null) params.set(m[1].toLowerCase(), m[2] ?? m[3]);
  if (params.get('error') !== 'insufficient_user_authentication') return null;
  const out                                 = {};
  const acr = (params.get('acr_values') ?? '').split(' ').find((v) => v in ACR_RANK);
  if (acr !== undefined) out.acr = acr       ;
  const maxAge = params.get('max_age');
  if (maxAge !== undefined && /^\d{1,9}$/.test(maxAge)) out.maxAge = Number(maxAge);
  return out;
}

// The Acore runtime's refusal body: {"error":{"code":"authorization_changed"|"step_up_required","message":...}}.
// Cross-origin responses do not expose WWW-Authenticate, so the body is the portable signal.
export function runtimeAuthRefusal(body         )                                                                                                      {
  let value = body;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }
  if (!isRecord(value) || !isRecord(value.error)) return null;
  const { code, message } = value.error;
  if (code === 'authorization_changed') return { code };
  if (code !== 'step_up_required') return null;
  const out                                                           = { code };
  const m = typeof message === 'string' ? /acr_values=(aal1|aal2|phr)(?:, max_age=(\d{1,9}))?$/.exec(message) : null;
  if (m) {
    out.acr = m[1]       ;
    if (m[2] !== undefined) out.maxAge = Number(m[2]);
  }
  return out;
}

// WebAuthn JSON (go-webauthn): binary members are base64url strings.
function bufferOf(text         )              {
  if (typeof text !== 'string') throw new AxiomAuthError('webauthn', 0);
  const bytes = decodeBase64url(text);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)               ;
}

function descriptors(list         )          {
  if (!Array.isArray(list)) return undefined;
  return list.filter(isRecord).map((d) => ({ ...d, id: bufferOf(d.id) }));
}

function creationOptions(json         )          {
  if (!isRecord(json) || !isRecord(json.user) || !isRecord(json.rp)) throw new AxiomAuthError('webauthn', 0);
  const out                          = { ...json, challenge: bufferOf(json.challenge), user: { ...json.user, id: bufferOf(json.user.id) } };
  if (json.excludeCredentials !== undefined) out.excludeCredentials = descriptors(json.excludeCredentials);
  return out;
}

function requestOptions(json         )          {
  if (!isRecord(json)) throw new AxiomAuthError('webauthn', 0);
  const out                          = { ...json, challenge: bufferOf(json.challenge) };
  if (json.allowCredentials !== undefined) out.allowCredentials = descriptors(json.allowCredentials);
  return out;
}

function bytesOf(value         )                     {
  if (value instanceof ArrayBuffer) return base64url(new Uint8Array(value));
  if (ArrayBuffer.isView(value)) return base64url(new Uint8Array(value.buffer, value.byteOffset, value.byteLength));
  return undefined;
}

// PublicKeyCredential to its JSON form; works where `toJSON` is missing.
function credentialJSON(credential         )                          {
  if (!isRecord(credential) || typeof credential.id !== 'string' || !isRecord(credential.response)) throw new AxiomAuthError('webauthn', 0);
  const r = credential.response;
  const response                          = { clientDataJSON: bytesOf(r.clientDataJSON) };
  if (r.attestationObject !== undefined) {
    response.attestationObject = bytesOf(r.attestationObject);
    if (typeof r.getTransports === 'function') {
      try {
        response.transports = (r.getTransports                  ).call(r);
      } catch {
        // Optional metadata.
      }
    }
  } else {
    response.authenticatorData = bytesOf(r.authenticatorData);
    response.signature = bytesOf(r.signature);
    const handle = bytesOf(r.userHandle);
    if (handle !== undefined) response.userHandle = handle;
  }
  if (typeof response.clientDataJSON !== 'string') throw new AxiomAuthError('webauthn', 0);
  let extensions          = {};
  if (typeof credential.getClientExtensionResults === 'function') {
    try {
      extensions = (credential.getClientExtensionResults                 ).call(credential);
    } catch {
      extensions = {};
    }
  }
  const out                          = {
    id: credential.id,
    rawId: bytesOf(credential.rawId) ?? credential.id,
    type: 'public-key',
    response,
    clientExtensionResults: isRecord(extensions) ? extensions : {},
  };
  if (typeof credential.authenticatorAttachment === 'string') out.authenticatorAttachment = credential.authenticatorAttachment;
  return out;
}

function factorOf(value         )                {
  if (!isRecord(value) || typeof value.id !== 'string' || typeof value.type !== 'string' || !FACTOR_TYPES.has(value.type)
    || typeof value.label !== 'string' || (value.status !== 'pending' && value.status !== 'active')) return null;
  const f         = {
    id: value.id,
    type: value.type                  ,
    label: value.label,
    status: value.status,
    createdAt: typeof value.created_at === 'string' ? value.created_at : '',
  };
  if (typeof value.last_used_on === 'string') f.lastUsedOn = value.last_used_on;
  return f;
}

function frozen   (items     )      {
  return Object.freeze(items)       ;
}

function stringList(value         )                       {
  if (!Array.isArray(value) || !value.every((x) => typeof x === 'string')) return undefined;
  return value.slice();
}

// auth-surfaces/v1 "returnTo" (security S-9).
function validReturnTo(value         , origin        )                  {
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

function parseRetryAfter(header               , now        )                     {
  if (header === null) return undefined;
  const text = header.trim();
  if (/^\d+$/.test(text)) return Number(text);
  const at = Date.parse(text);
  if (Number.isNaN(at)) return undefined;
  return Math.max(0, Math.ceil((at - now) / 1000));
}

function isTransaction(value         )                       {
  return isRecord(value) && value.v === 1 && typeof value.state === 'string' && typeof value.verifier === 'string'
    && (value.kind === 'provider' || value.kind === 'hosted' || value.kind === 'magic_link')
    && typeof value.issuer === 'string' && typeof value.redirectUri === 'string' && typeof value.createdAt === 'number';
}

export function createAxiomAuth(options                  )            {
  if (!options || typeof options.issuer !== 'string') throw new TypeError('issuer is required');
  const issuer = options.issuer;
  new URL(issuer); // throws on a malformed issuer
  const redirectUri = options.redirectUri;
  const redirect = redirectUri ? new URL(redirectUri) : null;
  const logoutUri = options.logoutUri;
  const storage = options.storage ?? memoryStorage();
  const g              = options.globalObject ?? (globalThis                          );
  const clock = options.clock ?? (() => Date.now());
  const fetchFn               = options.fetch ?? ((input, init) => globalThis.fetch(input, init));
  const setT = options.setTimeout ?? ((cb            , ms        )          => globalThis.setTimeout(cb, ms));
  const clearT = options.clearTimeout ?? ((h         )       => globalThis.clearTimeout(h                                 ));
  const onTokens = options.onTokens;
  if (storage.shared && !g.navigator?.locks) {
    // Tabs sharing a rotating refresh token without a cross-tab lock would end
    // each other's family through reuse detection.
    throw new TypeError('a shared storage adapter requires navigator.locks');
  }
  const storageKey = 'axiom-auth:refresh:' + issuer;
  const lockName = 'axiom-auth:' + issuer;

  let held              = null;
  let generation = 0;
  let current                = Object.freeze({ id: '', status: 'unknown'              , principal: null, acr: 'aal1'       , authTime: 0 });
  const listeners = new Set                            ();
  let inflight                                = null;
  let timer          = undefined;
  let retryNotBefore = 0;
  let retryCode                = 'unavailable';
  let resetToken                = null;
  let invitationToken                = null;
  // auth-advanced/v1 17.1: the MFA or enroll ticket of an unfinished sign-in, bound to the
  // PKCE verifier of the flow that produced it. Module-private memory only.
  let pending                                                                                                                         = null;

  const cryptoApi = () => {
    const c = g.crypto ?? (globalThis                          ).crypto;
    if (!c) throw new AxiomAuthError('unavailable', 0);
    return c;
  };
  const randomToken = ()         => base64url(cryptoApi().getRandomValues(new Uint8Array(32)));
  const jitter = ()         => cryptoApi().getRandomValues(new Uint32Array(1))[0] % (JITTER_MAX_MS + 1);
  const s256 = async (verifier        )                  =>
    base64url(new Uint8Array(await cryptoApi().subtle.digest('SHA-256', new TextEncoder().encode(verifier))));

  // Session projection

  function emit(next               )       {
    if (next.id === current.id && next.status === current.status && next.principal === current.principal
      && next.acr === current.acr && next.authTime === current.authTime) return;
    current = Object.freeze(next);
    for (const listener of Array.from(listeners)) {
      try {
        listener(current);
      } catch {
        // A listener failure never breaks the client.
      }
    }
  }

  function principalOf(claims        )                  {
    const prev = current.principal;
    const same = (a          , b          ) => a.length === b.length && a.every((x, i) => x === b[i]);
    if (prev && prev.subject === claims.sub && prev.tenant === claims.tenant && same(prev.roles, claims.roles) && same(prev.permissions, claims.permissions)) {
      return prev;
    }
    return Object.freeze({
      subject: claims.sub,
      tenant: claims.tenant,
      roles: Object.freeze(claims.roles.slice())            ,
      permissions: Object.freeze(claims.permissions.slice())            ,
    });
  }

  function publishHeld()       {
    if (held && held.claims) emit({ id: held.sessionId, status: 'authenticated', principal: principalOf(held.claims), acr: held.claims.acr, authTime: held.claims.authTime });
  }

  function publishStatus(status            )       {
    if (status === 'anonymous' || status === 'expired' || status === 'unknown') {
      emit({ id: '', status, principal: null, acr: 'aal1', authTime: 0 });
    } else {
      emit({ id: current.id, status, principal: current.principal, acr: current.acr, authTime: current.authTime });
    }
  }

  function pushToken(token               )       {
    if (!onTokens) return;
    try {
      onTokens(token);
    } catch {
      // The sink is the host's; its failure is not ours to report.
    }
  }

  // Drops every credential held in memory and tells the transport sink.
  function dropCredentials(status                         )       {
    held = null;
    generation++;
    cancelTimer();
    retryNotBefore = 0;
    pushToken(null);
    publishStatus(status);
  }

  async function removeRecord()                {
    try {
      await storage.remove(storageKey);
    } catch {
      // Best effort; the record can no longer rotate once the session is ended.
    }
  }

  // Transport

  async function call(method                           , path        , body                          , bearer         )                                             {
    const headers                         = { Accept: 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (bearer !== undefined) headers.Authorization = 'Bearer ' + bearer;
    const init              = {
      method,
      headers,
      credentials: 'omit',
      cache: 'no-store',
      redirect: 'error',
      referrerPolicy: 'no-referrer',
    };
    if (body !== undefined) init.body = JSON.stringify(body);
    let response          ;
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
    let data          = null;
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
    const failure = new AxiomAuthError(code, response.status, parseRetryAfter(response.headers.get('Retry-After'), clock()));
    if ((code === 'mfa_required' || code === 'mfa_enrollment_required') && isRecord(data) && isRecord(data.error)) {
      challengeBodies.set(failure, data.error);
    }
    throw failure;
  }

  // auth-advanced/v1 8.2: a first-factor flow answered AXAUTH_MFA_REQUIRED or
  // AXAUTH_MFA_ENROLLMENT_REQUIRED. Keeps the ticket private and rethrows a plain error.
  function capture(err         , verifier               )        {
    const body = err instanceof AxiomAuthError ? challengeBodies.get(err) : undefined;
    if (err instanceof AxiomAuthError && body !== undefined) {
      challengeBodies.delete(err);
      const now = clock();
      if (err.code === 'mfa_required' && isRecord(body.mfa) && typeof body.mfa.ticket === 'string' && body.mfa.ticket.length <= TICKET_MAX) {
        const factors                          = [];
        if (Array.isArray(body.mfa.factors)) {
          for (const f of body.mfa.factors) {
            if (isRecord(f) && typeof f.id === 'string' && typeof f.type === 'string' && FACTOR_TYPES.has(f.type) && typeof f.label === 'string' && f.usable !== false) {
              factors.push(Object.freeze({ id: f.id, type: f.type                  , label: f.label }));
            }
          }
        }
        const ttl = typeof body.mfa.expires_in === 'number' && body.mfa.expires_in > 0 ? Math.min(body.mfa.expires_in, 300) : 300;
        pending = { kind: 'mfa', ticket: body.mfa.ticket, verifier, expiresAt: now + ttl * 1000,
          challenge: Object.freeze({ factors: frozen(factors), recoveryCodes: body.mfa.recovery_codes === true }) };
      } else if (err.code === 'mfa_enrollment_required' && isRecord(body.mfa_enrollment) && typeof body.mfa_enrollment.ticket === 'string' && body.mfa_enrollment.ticket.length <= TICKET_MAX) {
        const types = (stringList(body.mfa_enrollment.types) ?? []).filter((t) => FACTOR_TYPES.has(t));
        pending = { kind: 'enroll', ticket: body.mfa_enrollment.ticket, verifier, expiresAt: now + 300 * 1000,
          challenge: Object.freeze({ factors: frozen                                 ([]), recoveryCodes: false, enrollment: Object.freeze({ types: frozen(types) }) }) };
      }
      throw new AxiomAuthError(err.code, err.status);
    }
    throw err;
  }

  // A first-factor call: clears any earlier unfinished MFA and captures a new one.
  async function firstFactor(path        , body                         , verifier                = null)                   {
    pending = null;
    try {
      return (await call('POST', path, body)).data;
    } catch (err) {
      return capture(err, verifier);
    }
  }

  function livePending(kind                         )                                                                                                                         {
    if (pending && clock() >= pending.expiresAt) pending = null;
    if (!pending || (kind !== null && pending.kind !== kind)) return null;
    return pending;
  }

  // The ticket carries the audience; the routes decode strictly, so nothing else is sent.
  // Only the completion routes take the PKCE verifier (8.2); the enrollment routes do not.
  function ticketBody(p                                             , body                         , verifier         )                          {
    body.ticket = p.ticket;
    if (verifier && p.verifier !== null) body.code_verifier = p.verifier;
    return body;
  }

  // Turnstile: `captcha_token` where the issuer requires it for this flow.
  function captcha(body                         , opts                            )                          {
    if (opts?.captchaToken !== undefined) {
      if (typeof opts.captchaToken !== 'string' || opts.captchaToken.length === 0 || opts.captchaToken.length > 4096) throw new AxiomAuthError('invalid_request', 0);
      body.captcha_token = opts.captchaToken;
    }
    return body;
  }

  function withAudience(body                         )                          {
    if (options.audience !== undefined) body.audience = options.audience;
    return body;
  }

  // Validates a token response and turns it into the private slot. `previous` is the
  // slot the request presented, for early-refresh detection.
  function heldFrom(data         , previous             )       {
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

  async function persist(h      )                {
    await storage.set(storageKey, {
      refreshToken: h.refreshToken,
      refreshExpiresAt: new Date(h.refreshExpiresAt).toISOString(),
      issuer,
      audience: h.audience,
      sessionId: h.sessionId,
    });
  }

  // A new session from a sign-in, verification or redirect completion.
  async function establish(data         )                         {
    const next = heldFrom(data, null);
    pending = null;
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

  function cancelTimer()       {
    if (timer !== undefined) {
      clearT(timer);
      timer = undefined;
    }
  }

  function hidden()          {
    return g.document?.visibilityState === 'hidden';
  }

  function scheduleAt(at        )       {
    cancelTimer();
    if (!held || hidden()) return;
    const delay = Math.max(0, at - clock());
    timer = setT(() => {
      timer = undefined;
      if (hidden()) return;
      refresh().catch(() => undefined);
    }, delay);
  }

  function scheduleProactive()       {
    if (!held || !held.claims) return;
    const exp = held.claims.exp * 1000;
    const at = held.rotationIntervalMs > 0 ? Math.min(exp - EXP_MARGIN_MS, held.rotationAnchorMs + held.rotationIntervalMs) : exp - EXP_MARGIN_MS;
    scheduleAt(at + jitter());
  }

  function onVisibility()       {
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

  function refresh(opts                      )                         {
    const tenant = opts?.tenant;
    if (inflight) {
      if (tenant === undefined) return inflight;
      return inflight.catch(() => undefined).then(() => refresh(opts));
    }
    const p                         = rotate((presented) => {
      const body                          = { refresh_token: presented.refreshToken };
      if (tenant !== undefined) body.tenant = tenant;
      return call('POST', '/v1/token/refresh', withAudience(body)).then((r) => r.data);
    }, false).finally(() => {
      if (inflight === p) inflight = null;
    });
    inflight = p;
    return p;
  }

  // auth-advanced/v1 8.6: reauthentication rotates the refresh token, so it runs as the
  // one in-flight rotation (and under the cross-tab lock), never beside a refresh.
  async function reauthenticate(request                                                       )                         {
    while (inflight) {
      try {
        await inflight;
      } catch {
        // The step-up runs on whatever the rotation left.
      }
    }
    const bearer = await freshAccessToken();
    if (bearer === null) throw new AxiomAuthError('invalid_token', 0);
    while (inflight) {
      try {
        await inflight;
      } catch {
        // As above.
      }
    }
    const p                         = rotate((presented) => request(presented, bearer), true).finally(() => {
      if (inflight === p) inflight = null;
    });
    // Refresh callers that coalesce onto a step-up get the session, not its failure.
    const shared                         = p.catch(() => current);
    inflight = shared;
    p.finally(() => {
      if (inflight === shared) inflight = null;
    }).catch(() => undefined);
    return p;
  }

  async function rotate(request                                       , reauth         )                         {
    if (!held) throw new AxiomAuthError('invalid_refresh', 0);
    const now = clock();
    if (now >= held.refreshExpiresAt) {
      dropCredentials('expired');
      await removeRecord();
      throw new AxiomAuthError('invalid_refresh', 0);
    }
    if (!reauth && retryNotBefore > now) {
      throw new AxiomAuthError(retryCode, 0, Math.ceil((retryNotBefore - now) / 1000));
    }
    const gen = generation;
    cancelTimer();
    publishStatus(held.claims ? 'refreshing' : 'loading');

    const run = async ()                => {
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
      const data = await request(presented);
      if (generation !== gen || held !== presented) return;
      const next = heldFrom(data, reauth ? null : presented);
      if (next.sessionId !== presented.sessionId) throw new AxiomAuthError('unavailable', 0);
      held = next;
      retryNotBefore = 0;
      pushToken(next.accessToken);
      // A failed persist (quota, private mode) keeps the session in memory; a
      // shared adapter must persist, or another tab would present the old token.
      if (storage.shared) await persist(next);
      else await persist(next).catch(() => undefined);
      if (held !== next) return;
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
      if (reauth) {
        // A refused step-up (wrong code, below the session's level) changes nothing.
        scheduleProactive();
        if (held.claims) publishHeld();
        else publishStatus('error');
        throw e;
      }
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

  async function freshAccessToken()                         {
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

  function txKeys()           {
    const ls = g.localStorage;
    if (!ls) return [];
    const keys           = [];
    for (let i = 0; i < ls.length; i++) {
      const k = ls.key(i);
      if (k !== null && k.startsWith(TX_PREFIX)) keys.push(k);
    }
    return keys;
  }

  function readTx(key        )                     {
    try {
      const raw = g.localStorage?.getItem(key);
      if (raw === null || raw === undefined) return null;
      const parsed          = JSON.parse(raw);
      return isTransaction(parsed) ? parsed : null;
    } catch {
      return null;
    }
  }

  function txLive(tx             , now        )          {
    return now - tx.createdAt < TX_LIFETIME_MS && tx.createdAt - now < TX_LIFETIME_MS;
  }

  function purgeTransactions()       {
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

  async function beginTransaction(kind                     , provider               , returnTo                    )                                                  {
    if (!redirectUri) throw new AxiomAuthError('redirect_uri', 0);
    const ls = g.localStorage;
    if (!ls) throw new AxiomAuthError('unavailable', 0);
    purgeTransactions();
    const origin = g.location?.origin ?? '';
    const tx              = {
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
  function takeTransaction(state               )                     {
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

  function startUrl(path        , tx             , challenge        )         {
    const u = new URL(issuer + path);
    u.searchParams.set('redirect_uri', tx.redirectUri);
    u.searchParams.set('state', tx.state);
    u.searchParams.set('code_challenge', challenge);
    u.searchParams.set('code_challenge_method', 'S256');
    return u.href;
  }

  function navigate(url        )       {
    if (!g.location) throw new AxiomAuthError('unavailable', 0);
    g.location.assign(url);
  }

  // Redirect completion

  function handleRedirect(url         )                                                   {
    // Everything up to the first fetch runs synchronously, so the URL is clean before
    // any app code can observe it.
    let parsed     ;
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
    const invitation = fragment.get('axiom_invitation');
    if (!viaQuery && link === null && reset === null && invitation === null) return Promise.resolve({ handled: false });

    const clean = new URL(parsed.href);
    for (const name of CALLBACK_QUERY) clean.searchParams.delete(name);
    if (Array.from(fragment.keys()).some((k) => k.startsWith('axiom_') || k === 'state')) clean.hash = '';
    try {
      g.history?.replaceState(g.history.state, '', clean.pathname + clean.search + clean.hash);
    } catch {
      // A history failure must not leave the flow half done; the code is single use.
    }

    if (!viaQuery && link === null && invitation !== null) {
      invitationToken = invitation;
      return Promise.resolve({ handled: true, invitation: true });
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

    let path        ;
    let body                         ;
    if (viaQuery) {
      if (tx.kind === 'magic_link') return Promise.reject(new AxiomAuthError('state_mismatch', 0));
      if (query.get('iss') !== issuer) return Promise.reject(new AxiomAuthError('invalid_grant', 0));
      const outcome = query.get('error');
      if (outcome !== null) {
        // auth-advanced/v1 8.2: the ticket is bound to this transaction's PKCE challenge,
        // so the completion sends its verifier. The factor list is not in the URL.
        const ticket = outcome === 'mfa_required' ? query.get('mfa_ticket') : outcome === 'mfa_enrollment_required' ? query.get('enroll_ticket') : null;
        if (ticket !== null && ticket.length > 0 && ticket.length <= TICKET_MAX) {
          pending = outcome === 'mfa_required'
            ? { kind: 'mfa', ticket, verifier: tx.verifier, expiresAt: clock() + 300 * 1000, challenge: Object.freeze({ factors: frozen                                 ([]), recoveryCodes: true }) }
            : { kind: 'enroll', ticket, verifier: tx.verifier, expiresAt: clock() + 300 * 1000, challenge: Object.freeze({ factors: frozen                                 ([]), recoveryCodes: false, enrollment: Object.freeze({ types: frozen        ([]) }) }) };
        }
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
    const verifier = tx.verifier;
    return firstFactor(path, body, verifier)
      .then((data) => establish(data))
      .then(() => (returnTo === undefined ? { handled: true } : { handled: true, returnTo }));
  }

  function isCallbackLocation()          {
    if (!redirect || !g.location) return false;
    try {
      const u = new URL(g.location.href);
      if (u.origin !== redirect.origin || u.pathname !== redirect.pathname) return false;
      const f = new URLSearchParams(u.hash.slice(1));
      return u.searchParams.has('code') || u.searchParams.has('error') || f.has('axiom_link') || f.has('axiom_reset') || f.has('axiom_invitation');
    } catch {
      return false;
    }
  }

  async function restoreStored()                         {
    if (held) return current;
    publishStatus('loading');
    let record                       = null;
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

  function restore()                         {
    purgeTransactions();
    if (isCallbackLocation()) {
      return handleRedirect().then(() => restoreStored());
    }
    return restoreStored();
  }

  // WebAuthn ceremonies run on the application origin (auth-advanced/v1 8.5).
  function credentials()                  {
    const c = g.navigator?.credentials ?? (globalThis                                                                ).navigator?.credentials;
    if (!c) throw new AxiomAuthError('webauthn', 0);
    return c;
  }

  async function assertion(options         )                                   {
    let credential         ;
    try {
      credential = await credentials().get({ publicKey: requestOptions(options) });
    } catch (err) {
      if (err instanceof AxiomAuthError) throw err;
      throw new AxiomAuthError('webauthn', 0);
    }
    if (credential === null || credential === undefined) throw new AxiomAuthError('webauthn', 0);
    return credentialJSON(credential);
  }

  async function attestation(options         )                                   {
    let credential         ;
    try {
      credential = await credentials().create({ publicKey: creationOptions(options) });
    } catch (err) {
      if (err instanceof AxiomAuthError) throw err;
      throw new AxiomAuthError('webauthn', 0);
    }
    if (credential === null || credential === undefined) throw new AxiomAuthError('webauthn', 0);
    return credentialJSON(credential);
  }

  function ceremony(data         )                                          {
    if (!isRecord(data) || typeof data.challenge !== 'string' || !isRecord(data.options)) throw new AxiomAuthError('unavailable', 0);
    return { challenge: data.challenge, options: data.options };
  }

  async function bearer()                  {
    const token = await freshAccessToken();
    if (token === null) throw new AxiomAuthError('invalid_token', 0);
    return token;
  }

  // Bearer for a signed-in user, else the enroll ticket of an enrollment-required sign-in.
  async function enrollActor()                                                                                    {
    const p = livePending('enroll');
    if (!held && p) return { ticket: p };
    return { token: await bearer() };
  }

  // A factor confirmation: recovery codes go to the caller once and are not kept;
  // `tokens` completes an enrollment-required sign-in.
  async function confirmation(data         )                                                               {
    if (!isRecord(data)) throw new AxiomAuthError('unavailable', 0);
    const out                                                      = { factor: factorOf(data.factor) };
    const codes = stringList(data.recovery_codes);
    if (codes !== undefined) out.recoveryCodes = codes;
    if (isRecord(data.tokens)) await establish(data.tokens);
    return out;
  }

  function replayable(body         )          {
    return body === undefined || body === null || typeof body === 'string' || body instanceof URLSearchParams
      || (typeof Blob !== 'undefined' && body instanceof Blob) || body instanceof ArrayBuffer || ArrayBuffer.isView(body)
      || (typeof FormData !== 'undefined' && body instanceof FormData);
  }

  async function authorizationChanged(response          )                   {
    try {
      if (/error_description="authorization_changed"/.test(response.headers.get('WWW-Authenticate') ?? '')) return true;
    } catch {
      // Fall through to the body.
    }
    try {
      return runtimeAuthRefusal(await response.clone().text())?.code === 'authorization_changed';
    } catch {
      return false;
    }
  }

  purgeTransactions();

  const api            = {
    session: () => current,

    async user()                           {
      const token = await freshAccessToken();
      if (!token) return null;
      const { data } = await call('GET', '/v1/user', undefined, token);
      if (!isRecord(data) || typeof data.id !== 'string' || (data.kind !== 'password' && data.kind !== 'external')) {
        throw new AxiomAuthError('unavailable', 0);
      }
      const providers           = [];
      if (Array.isArray(data.identities)) {
        for (const identity of data.identities) {
          if (isRecord(identity) && typeof identity.provider === 'string' && !providers.includes(identity.provider)) {
            providers.push(identity.provider);
          }
        }
      }
      const user           = {
        id: data.id,
        kind: data.kind,
        emailVerified: data.email_verified === true,
        hasPassword: data.has_password === true,
        providers,
      };
      if (typeof data.email === 'string') user.email = data.email;
      return user;
    },

    subscribe(listener                            )             {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    restore,

    async signUp(email        , password        , opts                            ) {
      const data = await firstFactor('/v1/signup', withAudience(captcha({ email, password }, opts)));
      if (isRecord(data) && typeof data.access_token === 'string') {
        await establish(data);
        return { status: 'signed_in'          };
      }
      if (!isRecord(data) || typeof data.challenge_id !== 'string') throw new AxiomAuthError('unavailable', 0);
      const out                                                                                  = { status: 'verification_sent', challenge: data.challenge_id };
      if (typeof data.resend_after === 'number') out.resendAfterSeconds = data.resend_after;
      return out;
    },

    async verifySignUp(challenge        , code        ) {
      const data = await firstFactor('/v1/signup/verify', withAudience({ challenge_id: challenge, code }));
      return establish(data);
    },

    async signInWithPassword(email        , password        , opts                                             ) {
      const body                          = captcha({ email, password }, opts);
      if (opts?.tenant !== undefined) body.tenant = opts.tenant;
      const data = await firstFactor('/v1/sign-in/password', withAudience(body));
      return establish(data);
    },

    async requestEmailCode(email        , opts                            ) {
      const { data } = await call('POST', '/v1/email/code', captcha({ email }, opts));
      if (!isRecord(data) || typeof data.challenge_id !== 'string') throw new AxiomAuthError('unavailable', 0);
      return { challenge: data.challenge_id, resendAfterSeconds: typeof data.resend_after === 'number' ? data.resend_after : 60 };
    },

    async verifyEmailCode(challenge        , code        ) {
      const data = await firstFactor('/v1/email/code/verify', withAudience({ challenge_id: challenge, code }));
      return establish(data);
    },

    async requestMagicLink(email        , opts                                               ) {
      const { tx, challenge } = await beginTransaction('magic_link', null, opts?.returnTo);
      try {
        await call('POST', '/v1/email/link', captcha({
          email,
          redirect_uri: tx.redirectUri,
          state: tx.state,
          code_challenge: challenge,
          code_challenge_method: 'S256',
        }, opts));
      } catch (err) {
        try {
          g.localStorage?.removeItem(TX_PREFIX + tx.state);
        } catch {
          // Purged at expiry anyway.
        }
        throw err;
      }
      return { sent: true          };
    },

    async signInWithProvider(provider        , opts                        )                 {
      if (typeof provider !== 'string' || provider.length === 0) throw new AxiomAuthError('invalid_request', 0);
      const { tx, challenge } = await beginTransaction('provider', provider, opts?.returnTo);
      navigate(startUrl('/v1/providers/' + encodeURIComponent(provider) + '/start', tx, challenge));
      return new Promise       (() => undefined);
    },

    async signInHosted(opts                                                        )                 {
      if (opts?.screen !== undefined && opts.screen !== 'sign_in' && opts.screen !== 'sign_up') throw new AxiomAuthError('invalid_request', 0);
      const { tx, challenge } = await beginTransaction('hosted', null, opts?.returnTo);
      const url = new URL(startUrl('/sign-in', tx, challenge));
      if (opts?.screen) url.searchParams.set('screen', opts.screen);
      navigate(url.href);
      return new Promise       (() => undefined);
    },

    handleRedirect,

    refresh,

    async signOut(opts                                                                  ) {
      if (inflight) {
        try {
          await inflight;
        } catch {
          // Sign-out proceeds whatever the rotation did.
        }
      }
      let refreshToken = held ? held.refreshToken : null;
      if (refreshToken === null) {
        // A stored record not yet restored is revoked, not merely forgotten.
        try {
          const stored = await storage.get(storageKey);
          if (isRefreshRecord(stored) && stored.issuer === issuer) refreshToken = stored.refreshToken;
        } catch {
          // Nothing readable to revoke.
        }
      }
      pending = null;
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

    async changePassword(currentPassword        , next        )                {
      const token = await freshAccessToken();
      if (!token) throw new AxiomAuthError('invalid_token', 0);
      await call('POST', '/v1/password', { current_password: currentPassword, new_password: next }, token);
    },

    async requestPasswordReset(email        , opts                            ) {
      const body                          = captcha({ email }, opts);
      if (redirectUri) body.redirect_uri = redirectUri;
      await call('POST', '/v1/password/reset', body);
      return { sent: true          };
    },

    async confirmPasswordReset(password        )                {
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

    async acceptInvitation(opts                                         )                         {
      const token = invitationToken;
      if (token === null) throw new AxiomAuthError('invalid_code', 0);
      const body                          = { token };
      if (opts?.password !== undefined) body.password = opts.password;
      if (opts?.tenant !== undefined) body.tenant = opts.tenant;
      let data         ;
      try {
        data = await firstFactor('/v1/invitations/accept', withAudience(body));
      } catch (err) {
        if (!(err instanceof AxiomAuthError) || err.code !== 'weak_password') invitationToken = null;
        throw err;
      }
      invitationToken = null;
      return establish(data);
    },

    selectTenant(tenant               )                         {
      return refresh(tenant === null ? undefined : { tenant });
    },

    async authorizationHeader()                         {
      const token = await freshAccessToken();
      return token === null ? null : 'Bearer ' + token;
    },

    // branches-v1 "Clients" (B10): on `401 authorization_changed` refresh once and retry once.
    async authorizedFetch(input                        , init              )                    {
      const base = typeof Request !== 'undefined' && input instanceof Request ? input : null;
      const retryable = base === null ? replayable(init?.body) : base.body === null || base.bodyUsed === false;
      const spare = base !== null && retryable ? base.clone() : null;
      const send = (token               , req                        )                    => {
        const headers = new Headers(init?.headers ?? (req instanceof Request ? req.headers : undefined));
        if (token !== null) headers.set('Authorization', 'Bearer ' + token);
        else headers.delete('Authorization');
        return fetchFn(req, { ...init, headers });
      };
      const first = await freshAccessToken();
      const response = await send(first, input);
      if (response.status !== 401 || first === null || !retryable || !(await authorizationChanged(response))) return response;
      try {
        await refresh();
      } catch {
        return response;
      }
      const second = held && held.accessToken && held.claims && clock() < held.claims.exp * 1000 ? held.accessToken : null;
      if (second === null || second === first) return response;
      return send(second, spare ?? input);
    },

    mfaChallenge()                      {
      return livePending(null)?.challenge ?? null;
    },

    async verifyMfa(factorId        , code        )                         {
      const p = livePending('mfa');
      if (!p) throw new AxiomAuthError('mfa_required', 0);
      const { data } = await call('POST', '/v1/mfa/verify', ticketBody(p, { factor_id: factorId, code }, true));
      return establish(data);
    },

    async verifyRecoveryCode(code        )                         {
      const p = livePending('mfa');
      if (!p) throw new AxiomAuthError('mfa_required', 0);
      const { data } = await call('POST', '/v1/mfa/verify', ticketBody(p, { recovery_code: code }, true));
      return establish(data);
    },

    async sendSmsCode(factorId        )                                          {
      const p = livePending('mfa');
      if (!p) throw new AxiomAuthError('mfa_required', 0);
      const { data } = await call('POST', '/v1/mfa/sms/send', ticketBody(p, { factor_id: factorId }, false));
      return { resendAfterSeconds: isRecord(data) && typeof data.resend_after === 'number' ? data.resend_after : 60 };
    },

    async verifyMfaWithPasskey()                         {
      const p = livePending('mfa');
      if (!p) throw new AxiomAuthError('mfa_required', 0);
      const { challenge, options: publicKey } = ceremony((await call('POST', '/v1/mfa/webauthn/options', ticketBody(p, {}, false))).data);
      const credential = await assertion(publicKey);
      const { data } = await call('POST', '/v1/mfa/webauthn/verify', ticketBody(p, { challenge, credential }, true));
      return establish(data);
    },

    async signInWithPasskey(opts                      )                         {
      pending = null;
      const { challenge, options: publicKey } = ceremony((await call('POST', '/v1/passkeys/options', {})).data);
      const credential = await assertion(publicKey);
      const body                          = { challenge, credential };
      if (opts?.tenant !== undefined) body.tenant = opts.tenant;
      const { data } = await call('POST', '/v1/sign-in/passkey', withAudience(body));
      return establish(data);
    },

    stepUp(opts                                                                                          )                         {
      if (!opts || !STEP_UP_METHODS.has(opts.method) || (opts.acr !== undefined && !(opts.acr in ACR_RANK))) {
        return Promise.reject(new AxiomAuthError('invalid_request', 0));
      }
      if (!held) return Promise.reject(new AxiomAuthError('invalid_token', 0));
      return reauthenticate(async (presented, token) => {
        const body                          = { refresh_token: presented.refreshToken, method: opts.method };
        if (opts.acr !== undefined) body.acr = opts.acr;
        if (opts.method === 'password') {
          if (typeof opts.password !== 'string') throw new AxiomAuthError('invalid_request', 0);
          body.password = opts.password;
        } else if (opts.method === 'recovery') {
          if (typeof opts.code !== 'string') throw new AxiomAuthError('invalid_request', 0);
          body.recovery_code = opts.code;
        } else if (opts.method === 'passkey') {
          const { challenge, options: publicKey } = ceremony((await call('POST', '/v1/reauthenticate/webauthn/options', {}, token)).data);
          body.challenge = challenge;
          body.credential = await assertion(publicKey);
        } else {
          if (typeof opts.code !== 'string') throw new AxiomAuthError('invalid_request', 0);
          let factorId = opts.factorId;
          if (factorId === undefined) {
            // The one active factor of that type; more than one needs `factorId`.
            const { data } = await call('GET', '/v1/factors', undefined, token);
            const list = isRecord(data) && Array.isArray(data.factors) ? data.factors : [];
            const matches = list.filter((f) => isRecord(f) && f.type === opts.method && f.status === 'active' && f.usable !== false && typeof f.id === 'string');
            if (matches.length !== 1) throw new AxiomAuthError('invalid_request', 0);
            factorId = (matches[0]                           ).id          ;
          }
          body.factor_id = factorId;
          body.code = opts.code;
        }
        if (options.audience !== undefined) body.audience = options.audience;
        return (await call('POST', '/v1/reauthenticate', body, token)).data;
      });
    },

    async listFactors() {
      const { data } = await call('GET', '/v1/factors', undefined, await bearer());
      if (!isRecord(data) || !Array.isArray(data.factors)) throw new AxiomAuthError('unavailable', 0);
      const factors = data.factors.map(factorOf).filter((f)              => f !== null);
      const out                                                                                    = {
        factors,
        recoveryCodesRemaining: typeof data.recovery_codes_remaining === 'number' ? data.recovery_codes_remaining : 0,
      };
      if (isRecord(data.phone) && typeof data.phone.masked === 'string') out.phone = { masked: data.phone.masked };
      return out;
    },

    async enrollTotp(label        )                          {
      const actor = await enrollActor();
      const body                          = actor.ticket ? ticketBody(actor.ticket, { label }, false) : { label };
      const { data } = await call('POST', '/v1/factors/totp', body, actor.token);
      if (!isRecord(data) || typeof data.factor_id !== 'string' || typeof data.secret !== 'string' || typeof data.otpauth_uri !== 'string') {
        throw new AxiomAuthError('unavailable', 0);
      }
      // Returned to the trusted UI once; never cached here.
      return { factorId: data.factor_id, secret: data.secret, otpauthUri: data.otpauth_uri };
    },

    async confirmTotp(factorId        , code        )                                        {
      if (typeof factorId !== 'string' || !/^[0-9a-f-]{36}$/.test(factorId)) throw new AxiomAuthError('invalid_request', 0);
      const actor = await enrollActor();
      const body                          = actor.ticket ? ticketBody(actor.ticket, { code }, false) : { code };
      const { data } = await call('POST', '/v1/factors/totp/' + encodeURIComponent(factorId) + '/confirm', body, actor.token);
      const out = await confirmation(data);
      return out.recoveryCodes !== undefined ? { recoveryCodes: out.recoveryCodes } : {};
    },

    async registerPasskey(label        )                                                 {
      const actor = await enrollActor();
      const optionsBody                          = actor.ticket ? ticketBody(actor.ticket, { label }, false) : { label };
      const { challenge, options: publicKey } = ceremony((await call('POST', '/v1/factors/passkeys/options', optionsBody, actor.token)).data);
      const credential = await attestation(publicKey);
      const body                          = { challenge, label, credential };
      if (actor.ticket) ticketBody(actor.ticket, body, false);
      const { data } = await call('POST', '/v1/factors/passkeys', body, actor.token);
      const out = await confirmation(data);
      if (out.factor === null) throw new AxiomAuthError('unavailable', 0);
      return out.recoveryCodes !== undefined ? { ...out.factor, recoveryCodes: out.recoveryCodes } : out.factor;
    },

    async removeFactor(factorId        )                {
      if (typeof factorId !== 'string' || !/^[0-9a-f-]{36}$/.test(factorId)) throw new AxiomAuthError('invalid_request', 0);
      await call('DELETE', '/v1/factors/' + encodeURIComponent(factorId), undefined, await bearer());
    },

    async regenerateRecoveryCodes()                    {
      const { data } = await call('POST', '/v1/recovery-codes', {}, await bearer());
      const codes = isRecord(data) ? stringList(data.recovery_codes) : undefined;
      if (codes === undefined) throw new AxiomAuthError('unavailable', 0);
      return codes;
    },

    async addPhone(phone        , opts                            )                                   {
      const { data } = await call('POST', '/v1/phone', captcha({ phone }, opts), await bearer());
      if (!isRecord(data) || typeof data.challenge_id !== 'string') throw new AxiomAuthError('unavailable', 0);
      return { challengeId: data.challenge_id };
    },

    async verifyPhone(challengeId        , code        )                {
      await call('POST', '/v1/phone/verify', { challenge_id: challengeId, code }, await bearer());
    },

    async enableSmsFactor()                  {
      const { data } = await call('POST', '/v1/factors/sms', {}, await bearer());
      const factor = isRecord(data) ? factorOf(data.factor) : null;
      if (factor === null) throw new AxiomAuthError('unavailable', 0);
      return factor;
    },

    async listConsents() {
      const { data } = await call('GET', '/v1/consents', undefined, await bearer());
      if (!isRecord(data) || !Array.isArray(data.consents)) throw new AxiomAuthError('unavailable', 0);
      const out                                                         = [];
      for (const c of data.consents) {
        if (isRecord(c) && typeof c.client_id === 'string' && typeof c.name === 'string') {
          out.push({ clientId: c.client_id, name: c.name, scopes: stringList(c.scopes) ?? [] });
        }
      }
      return out;
    },

    async revokeConsent(clientId        )                {
      if (typeof clientId !== 'string' || !/^axcl_[A-Za-z0-9_-]{22}$/.test(clientId)) throw new AxiomAuthError('invalid_request', 0);
      await call('DELETE', '/v1/consents/' + clientId, undefined, await bearer());
    },

    toJSON() {
      return { issuer, session: current };
    },
  };
  return Object.freeze(api);
}
