// Fakes for the node --test suite: a mock issuer behind `fetch`, Web Storage,
// location and history, Web Locks, document visibility, a clock and timers.
import { createHash, randomBytes } from 'node:crypto';
import { createAxiomAuth } from '../dist/index.js';

export const ISSUER = 'https://auth.axiomcore.dev/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222';
export const ORIGIN = 'https://shop.example.com';
export const REDIRECT_URI = ORIGIN + '/auth/callback';
export const LOGOUT_URI = ORIGIN + '/signed-out';
export const START = Date.UTC(2026, 9, 26, 12, 0, 0);

export const flush = async () => {
  for (let i = 0; i < 30; i++) await new Promise((resolve) => setImmediate(resolve));
};

const b64u = (value) => Buffer.from(typeof value === 'string' ? value : JSON.stringify(value)).toString('base64url');

export function s256(verifier) {
  return createHash('sha256').update(verifier, 'ascii').digest('base64url');
}

export function makeClock(start = START) {
  let now = start;
  let nextId = 0;
  const timers = new Map();
  return {
    now: () => now,
    set(ms) { now = ms; },
    setTimeout: (fn, ms) => {
      const handle = ++nextId;
      timers.set(handle, { at: now + Math.max(0, ms), fn });
      return handle;
    },
    clearTimeout: (handle) => { timers.delete(handle); },
    pending: () => Array.from(timers.values()).map((t) => t.at).sort((a, b) => a - b),
    async advance(ms) {
      const target = now + ms;
      for (;;) {
        let next = null;
        for (const [handle, t] of timers) {
          if (t.at <= target && (next === null || t.at < next[1].at)) next = [handle, t];
        }
        if (next === null) break;
        timers.delete(next[0]);
        now = next[1].at;
        next[1].fn();
        await flush();
      }
      now = target;
      await flush();
    },
  };
}

export class FakeStorage {
  constructor() { this.map = new Map(); }
  get length() { return this.map.size; }
  key(i) { return Array.from(this.map.keys())[i] ?? null; }
  getItem(k) { return this.map.has(k) ? this.map.get(k) : null; }
  setItem(k, v) { this.map.set(k, String(v)); }
  removeItem(k) { this.map.delete(k); }
  clear() { this.map.clear(); }
  keys() { return Array.from(this.map.keys()); }
  dump() { return JSON.stringify(Array.from(this.map.entries())); }
}

export function makeLocks() {
  const queues = new Map();
  const locks = {
    requests: [],
    async request(name, callback) {
      locks.requests.push(name);
      const previous = queues.get(name) ?? Promise.resolve();
      let release;
      const mine = new Promise((resolve) => { release = resolve; });
      queues.set(name, previous.then(() => mine));
      await previous;
      try {
        return await callback();
      } finally {
        release();
      }
    },
  };
  return locks;
}

export function makeBrowser({ href = ORIGIN + '/', localStorage = new FakeStorage(), locks } = {}) {
  const events = [];
  const location = {
    href,
    get origin() { return new URL(this.href).origin; },
    assigned: [],
    assign(url) { this.assigned.push(url); },
  };
  const listeners = [];
  const browser = {
    events,
    location,
    history: {
      state: null,
      calls: [],
      replaceState(state, unused, url) {
        this.calls.push(url);
        events.push('replaceState');
        location.href = new URL(url, location.href).href;
      },
    },
    localStorage,
    sessionStorage: new FakeStorage(),
    navigator: locks ? { locks } : {},
    document: {
      visibilityState: 'visible',
      addEventListener(type, fn) { if (type === 'visibilitychange') listeners.push(fn); },
      setVisibility(state) {
        this.visibilityState = state;
        for (const fn of listeners) fn();
      },
    },
    crypto: globalThis.crypto,
  };
  return browser;
}

export function makeSharedAdapter() {
  const map = new Map();
  return {
    shared: true,
    map,
    async get(k) { return map.has(k) ? { ...map.get(k) } : null; },
    async set(k, v) { map.set(k, { ...v }); },
    async remove(k) { map.delete(k); },
  };
}

const REQUIRED_INIT = { credentials: 'omit', cache: 'no-store', redirect: 'error', referrerPolicy: 'no-referrer' };

export class FakeIssuer {
  constructor({ clock, issuer = ISSUER, ttl = 900, refreshLifetime = 7 * 24 * 3600, roles = ['member'], permissions = ['orders.read'] } = {}) {
    this.clock = clock;
    this.issuer = issuer;
    this.ttl = ttl;
    this.refreshLifetime = refreshLifetime;
    this.roles = roles;
    this.permissions = permissions;
    this.calls = [];
    this.violations = [];
    this.handlers = new Map();
    this.sessions = new Map();
    this.codes = new Map();
    this.links = new Map();
    this.linkRequests = [];
    this.supersededPresented = 0;
    this.rotations = 0;
    this.earlyRefreshes = 0;
    this.issuedAccess = [];
    this.issuedRefresh = [];
    this.fetch = (url, init) => this.handle(url, init);
  }

  on(route, fn) { this.handlers.set(route, fn); }
  callsTo(route) { return this.calls.filter((c) => c.route === route); }

  accessToken(sid, expMs) {
    const s = this.sessions.get(sid);
    const iat = Math.floor(this.clock.now() / 1000);
    const payload = {
      iss: this.issuer, aud: this.issuer + '/api', sub: s.sub, sid, iat, nbf: iat,
      exp: Math.floor(expMs / 1000), jti: randomBytes(16).toString('base64url'), token_use: 'access',
      amr: ['pwd'], auth_time: iat, roles: this.roles, permissions: this.permissions, authz_ver: 1, epoch: 1,
    };
    if (s.tenant) payload.tenant = s.tenant;
    if (s.acr) { payload.acr = s.acr; payload.amr = s.amr; payload.auth_time = s.authTime ?? iat; }
    const token = b64u({ alg: 'EdDSA', typ: 'at+jwt', kid: 'k1' }) + '.' + b64u(payload) + '.' + randomBytes(64).toString('base64url');
    this.issuedAccess.push(token);
    return token;
  }

  newRefresh(sid, counter) {
    const token = `axr1_${Buffer.from(sid).toString('base64url').slice(0, 22)}.${counter}.${randomBytes(32).toString('base64url')}.${randomBytes(16).toString('base64url')}`;
    this.issuedRefresh.push(token);
    return token;
  }

  createSession(sub = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') {
    const sid = crypto.randomUUID();
    const now = this.clock.now();
    const s = { sid, sub, tenant: null, counter: 0, current: null, previous: new Set(), lastRotated: now, accessExp: now + this.ttl * 1000, ended: false, refreshExpiresAt: now + this.refreshLifetime * 1000 };
    s.current = this.newRefresh(sid, 0);
    this.sessions.set(sid, s);
    return s;
  }

  tokens(s) {
    return {
      access_token: this.accessToken(s.sid, s.accessExp),
      token_type: 'Bearer',
      expires_in: Math.round((s.accessExp - this.clock.now()) / 1000),
      refresh_token: s.current,
      refresh_expires_at: new Date(s.refreshExpiresAt).toISOString(),
      session: { id: s.sid, absolute_expires_at: new Date(s.refreshExpiresAt).toISOString(), tenant: s.tenant },
      user: { id: s.sub, kind: 'password', email: 'jo@example.com' },
    };
  }

  findByRefresh(token) {
    for (const s of this.sessions.values()) {
      if (s.current === token || s.previous.has(token)) return s;
    }
    return null;
  }

  async handle(url, init = {}) {
    const u = new URL(url);
    const route = (init.method ?? 'GET') + ' ' + u.pathname.slice(this.issuer.length - new URL(this.issuer).origin.length);
    for (const [k, v] of Object.entries(REQUIRED_INIT)) {
      if (init[k] !== v) this.violations.push(`${route}: ${k}=${init[k]}`);
    }
    let body;
    if (init.body !== undefined) {
      if (init.headers?.['Content-Type'] !== 'application/json') this.violations.push(`${route}: content-type`);
      body = JSON.parse(init.body);
    }
    if (!url.startsWith(this.issuer + '/')) this.violations.push(`${route}: foreign url ${url}`);
    const call = { route, url, init, body, headers: init.headers ?? {} };
    this.calls.push(call);
    await Promise.resolve();
    const custom = this.handlers.get(route);
    if (custom) {
      const out = await custom(body, call, this);
      if (out !== undefined) return this.respond(out);
    }
    return this.respond(this.defaultRoute(route, body, call));
  }

  respond({ status = 200, body, headers = {} }) {
    return new Response(body === undefined ? '' : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', ...headers } });
  }

  error(status, code, headers) {
    return { status, body: { error: { code } }, headers };
  }

  defaultRoute(route, body, call) {
    const now = this.clock.now();
    switch (route) {
      case 'POST /v1/sign-in/password':
      case 'POST /v1/email/code/verify':
      case 'POST /v1/signup/verify':
        return { status: route === 'POST /v1/signup/verify' ? 201 : 200, body: this.tokens(this.createSession()) };
      case 'POST /v1/signup':
        return { status: 201, body: this.tokens(this.createSession()) };
      case 'POST /v1/email/code':
        return { status: 202, body: { challenge_id: 'ch-1', expires_in: 600, resend_after: 60 } };
      case 'POST /v1/email/link': {
        const token = 'axl1_' + randomBytes(24).toString('base64url');
        this.links.set(token, { challenge: body.code_challenge, state: body.state, redirectUri: body.redirect_uri });
        this.linkRequests.push({ token, ...body });
        return { status: 202, body: { challenge_id: 'ch-link', expires_in: 900, resend_after: 60 } };
      }
      case 'POST /v1/email/link/verify': {
        const link = this.links.get(body.token);
        this.links.delete(body.token);
        if (!link || s256(body.code_verifier) !== link.challenge) return this.error(400, 'AXAUTH_INVALID_CODE');
        return { body: this.tokens(this.createSession()) };
      }
      case 'POST /v1/token/authorization-code': {
        const grant = this.codes.get(body.code);
        this.codes.delete(body.code);
        if (!grant || grant.redirectUri !== body.redirect_uri || s256(body.code_verifier) !== grant.challenge) return this.error(400, 'AXAUTH_INVALID_GRANT');
        return { body: this.tokens(this.createSession()) };
      }
      case 'POST /v1/token/refresh': {
        const s = this.findByRefresh(body.refresh_token);
        if (!s || s.ended) return this.error(401, 'AXAUTH_INVALID_REFRESH');
        if (s.current !== body.refresh_token) {
          this.supersededPresented++;
          s.ended = true;
          return this.error(401, 'AXAUTH_INVALID_REFRESH');
        }
        if (body.tenant !== undefined) s.tenant = body.tenant;
        const interval = this.ttl * 1000 - 120000;
        if (s.lastRotated > now - interval) {
          this.earlyRefreshes++;
          return { body: this.tokens(s) };
        }
        s.previous.add(s.current);
        s.counter++;
        s.current = this.newRefresh(s.sid, s.counter);
        s.lastRotated = now;
        s.accessExp = now + this.ttl * 1000;
        this.rotations++;
        return { body: this.tokens(s) };
      }
      case 'POST /v1/logout':
      case 'POST /v1/logout-all': {
        const s = this.findByRefresh(body.refresh_token);
        if (s) s.ended = true;
        return { body: { ended: true } };
      }
      case 'POST /v1/password':
        if (!call.headers.Authorization?.startsWith('Bearer ')) return this.error(401, 'AXAUTH_INVALID_TOKEN');
        return { body: { changed: true } };
      case 'POST /v1/password/reset':
        return { status: 202, body: { challenge_id: 'ch-reset', expires_in: 900, resend_after: 60 } };
      case 'POST /v1/password/reset/confirm':
        return body.token === 'axp1_reset' ? { body: { reset: true } } : this.error(400, 'AXAUTH_INVALID_CODE');
      case 'GET /v1/user':
        if (!call.headers.Authorization?.startsWith('Bearer ')) return this.error(401, 'AXAUTH_INVALID_TOKEN');
        return {
          body: {
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', kind: 'external', email: 'jo@example.com', email_verified: true,
            display_name: 'Jo', created_at: '2026-10-01T00:00:00Z', has_password: false,
            identities: [
              { id: 'i1', provider: 'google', kind: 'google', login: 'jo', email: 'jo@example.com', email_verified: true, created_at: '2026-10-01T00:00:00Z' },
              { id: 'i2', provider: 'github', kind: 'github', login: 'jo', email: null, email_verified: false, created_at: '2026-10-02T00:00:00Z' },
              { id: 'i3', provider: 'google', kind: 'google', login: 'jo2', email: null, email_verified: false, created_at: '2026-10-03T00:00:00Z' },
            ],
          },
        };
      default:
        return this.error(404, 'AXAUTH_NOT_FOUND');
    }
  }

  // Simulates the provider callback: a code bound to the start URL's challenge.
  grantFor(startUrl) {
    const u = new URL(startUrl);
    const code = 'axc1_' + randomBytes(24).toString('base64url');
    this.codes.set(code, { challenge: u.searchParams.get('code_challenge'), redirectUri: u.searchParams.get('redirect_uri') });
    return { code, state: u.searchParams.get('state') };
  }
}

export function setup({ browser, clock, issuer, storage, ttl, refreshLifetime, audience, onTokens, ...rest } = {}) {
  clock ??= makeClock();
  browser ??= makeBrowser();
  issuer ??= new FakeIssuer({ clock, ttl, refreshLifetime });
  const tokens = [];
  const auth = createAxiomAuth({
    issuer: ISSUER,
    audience,
    redirectUri: REDIRECT_URI,
    logoutUri: LOGOUT_URI,
    storage,
    onTokens: onTokens ?? ((t) => tokens.push(t)),
    fetch: issuer.fetch,
    clock: clock.now,
    setTimeout: clock.setTimeout,
    clearTimeout: clock.clearTimeout,
    globalObject: browser,
    ...rest,
  });
  return { auth, browser, clock, issuer, tokens };
}

// The web host forwards to its coordinator only on these changes (feasibility S21).
export function hostForwarder(auth) {
  const forwarded = [];
  let last = auth.session();
  auth.subscribe((s) => {
    if (s.id !== last.id || s.principal !== last.principal || s.status === 'expired' || s.status === 'anonymous') forwarded.push(s);
    last = s;
  });
  return forwarded;
}
