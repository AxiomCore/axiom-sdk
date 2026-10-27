import test from 'node:test';
import assert from 'node:assert/strict';
import * as pkg from '../dist/index.js';
import { AxiomAuthError, createAxiomAuth, memoryStorage, sessionStorageAdapter } from '../dist/index.js';
import { FakeStorage, ISSUER, REDIRECT_URI, flush, setup } from './helpers.mjs';

function secretsOf(issuer) {
  return [...issuer.issuedAccess, ...issuer.issuedRefresh];
}

function assertNoSecret(text, secrets, where) {
  for (const s of secrets) assert.ok(!text.includes(s), `${where} contains a token`);
}

test('exports are exactly the contract block', () => {
  assert.deepEqual(Object.keys(pkg).sort(), ['AxiomAuthError', 'createAxiomAuth', 'memoryStorage', 'sessionStorageAdapter']);
});

test('memory default: nothing in sessionStorage, only PKCE transactions in localStorage', async () => {
  const ctx = setup();
  await ctx.auth.restore();
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  await ctx.auth.refresh();
  await ctx.auth.requestMagicLink('jo@example.com', { returnTo: '/orders' });
  ctx.auth.signInHosted();
  await flush();
  assert.equal(ctx.browser.sessionStorage.length, 0);
  const keys = ctx.browser.localStorage.keys();
  assert.equal(keys.length, 2);
  for (const k of keys) {
    assert.ok(k.startsWith('axiom-auth:tx:'));
    const tx = JSON.parse(ctx.browser.localStorage.getItem(k));
    assert.deepEqual(Object.keys(tx), ['v', 'state', 'verifier', 'kind', 'provider', 'issuer', 'audience', 'redirectUri', 'returnTo', 'createdAt']);
  }
  assertNoSecret(ctx.browser.localStorage.dump(), secretsOf(ctx.issuer), 'localStorage');
});

test('no token in JSON.stringify(auth), session(), errors or the global object', async () => {
  const globalsBefore = Object.getOwnPropertyNames(globalThis).sort();
  const ctx = setup();
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  await ctx.auth.refresh();
  ctx.issuer.on('POST /v1/token/refresh', (_b, _c, iss) => iss.error(503, 'AXAUTH_UNAVAILABLE', { 'Retry-After': '3' }));
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  const err = await ctx.auth.refresh().catch((e) => e);
  const secrets = secretsOf(ctx.issuer);
  assert.ok(secrets.length >= 4);

  const json = JSON.stringify(ctx.auth);
  assert.deepEqual(JSON.parse(json), { issuer: ISSUER, session: JSON.parse(JSON.stringify(ctx.auth.session())) });
  assertNoSecret(json, secrets, 'JSON.stringify(auth)');
  assertNoSecret(JSON.stringify(ctx.auth.session()), secrets, 'session()');
  assert.deepEqual(Object.keys(ctx.auth.session()).sort(), ['id', 'principal', 'status']);
  assert.deepEqual(Object.keys(ctx.auth.session().principal).sort(), ['permissions', 'roles', 'subject', 'tenant']);

  assert.ok(err instanceof AxiomAuthError);
  assert.equal(err.message, 'unavailable');
  assert.deepEqual(Object.keys(err).sort(), ['code', 'name', 'retryAfterSeconds', 'status']);
  assertNoSecret(JSON.stringify(err) + err.message + String(err.stack), secrets, 'error');

  // The client wrote nothing to the injected window object or to globalThis.
  assert.deepEqual(Object.keys(ctx.browser).sort(), ['crypto', 'document', 'events', 'history', 'localStorage', 'location', 'navigator', 'sessionStorage']);
  assertNoSecret(JSON.stringify({ ...ctx.browser, crypto: null }), secrets, 'window');
  assert.deepEqual(Object.getOwnPropertyNames(globalThis).sort(), globalsBefore);
  for (const name of Object.getOwnPropertyNames(globalThis)) {
    let value;
    try { value = globalThis[name]; } catch { continue; }
    if (typeof value === 'string') assertNoSecret(value, secrets, `globalThis.${name}`);
  }
});

test('errors carry only code, status and retryAfterSeconds, never request data', async () => {
  const ctx = setup();
  ctx.issuer.on('POST /v1/sign-in/password', () => ({ status: 401, body: { error: { code: 'AXAUTH_INVALID_CREDENTIALS', message: 'raw server text', email: 'jo@example.com' } } }));
  const err = await ctx.auth.signInWithPassword('jo@example.com', 'hunter2-secret').catch((e) => e);
  assert.equal(err.code, 'invalid_credentials');
  assert.equal(err.status, 401);
  assert.equal(err.retryAfterSeconds, undefined);
  const dump = JSON.stringify(err) + err.message + String(err.stack);
  for (const leaked of ['hunter2-secret', 'jo@example.com', 'raw server text', ISSUER]) assert.ok(!dump.includes(leaked), leaked);

  const start = new URL(REDIRECT_URI);
  start.searchParams.set('code', 'axc1_secret_code');
  start.searchParams.set('state', 'secret_state_value');
  start.searchParams.set('iss', ISSUER);
  const redirectErr = await ctx.auth.handleRedirect(start.href).catch((e) => e);
  const dump2 = JSON.stringify(redirectErr) + redirectErr.message + String(redirectErr.stack);
  for (const leaked of ['axc1_secret_code', 'secret_state_value']) assert.ok(!dump2.includes(leaked));
});

const MAPPING = [
  ['AXAUTH_INVALID_REQUEST', 400, 'invalid_request'], ['AXAUTH_WEAK_PASSWORD', 400, 'weak_password'],
  ['AXAUTH_INVALID_CREDENTIALS', 401, 'invalid_credentials'], ['AXAUTH_INVALID_REFRESH', 401, 'invalid_refresh'],
  ['AXAUTH_INVALID_TOKEN', 401, 'invalid_token'], ['AXAUTH_USER_DISABLED', 403, 'user_disabled'],
  ['AXAUTH_SIGNUP_DISABLED', 403, 'signup_disabled'], ['AXAUTH_TENANT_DENIED', 403, 'tenant_denied'],
  ['AXAUTH_ORIGIN', 403, 'origin'], ['AXAUTH_NOT_FOUND', 404, 'not_found'], ['AXAUTH_ACCOUNT_EXISTS', 409, 'account_exists'],
  ['AXAUTH_REFRESH_TOO_SOON', 429, 'refresh_too_soon'], ['AXAUTH_RATE_LIMITED', 429, 'rate_limited'],
  ['AXAUTH_QUOTA', 429, 'quota'], ['AXAUTH_RESERVE_EXHAUSTED', 429, 'reserve_exhausted'], ['AXAUTH_UNAVAILABLE', 503, 'unavailable'],
  ['AXAUTH_FORBIDDEN', 403, 'forbidden'], ['AXAUTH_CONFLICT', 409, 'conflict'], ['AXAUTH_LIMIT', 409, 'limit'],
  ['AXAUTH_KEY_LIMIT', 409, 'key_limit'], ['AXAUTH_TOO_MANY_PERMISSIONS', 409, 'too_many_permissions'],
  ['AXAUTH_ISSUER_SCOPE', 401, 'issuer_scope'],
  ['AXAUTH_INVALID_CODE', 400, 'invalid_code'], ['AXAUTH_INVALID_GRANT', 400, 'invalid_grant'],
  ['AXAUTH_REDIRECT_URI', 400, 'redirect_uri'], ['AXAUTH_CAPTCHA', 400, 'captcha'],
  ['AXAUTH_REAUTH_REQUIRED', 401, 'reauth_required'], ['AXAUTH_EMAIL_UNVERIFIED', 403, 'email_unverified'],
  ['AXAUTH_METHOD_DISABLED', 403, 'method_disabled'], ['AXAUTH_ACCOUNT_LINK_REQUIRED', 409, 'account_link_required'],
  ['AXAUTH_IDENTITY_LINKED', 409, 'identity_linked'], ['AXAUTH_LAST_METHOD', 409, 'last_method'],
  ['AXAUTH_UPGRADE_PENDING', 503, 'upgrade_pending'],
  ['AXAUTH_SOMETHING_NEW', 400, 'unavailable'], ['axauth_invalid_code', 400, 'unavailable'], ['free text', 400, 'unavailable'],
  [42, 400, 'unavailable'],
];

test('error-code mapping table: AXAUTH_FOO_BAR -> foo_bar, unknown -> unavailable', async () => {
  for (const [code, status, expected] of MAPPING) {
    const ctx = setup();
    ctx.issuer.on('POST /v1/email/code', (_b, _c, iss) => iss.error(status, code));
    const err = await ctx.auth.requestEmailCode('jo@example.com').catch((e) => e);
    assert.equal(err.code, expected, String(code));
    assert.equal(err.message, expected);
    assert.equal(err.status, status);
  }
  const shapes = [
    [() => new Response(JSON.stringify('not an error object'), { status: 500 }), 500],
    [() => new Response('<html>oops</html>', { status: 502 }), 502],
    [() => new Response('{"challenge_id":', { status: 202 }), 202],
    [() => { throw new TypeError('Failed to fetch'); }, 0],
  ];
  for (const [shape, status] of shapes) {
    const ctx = setup();
    ctx.issuer.handle = async () => shape();
    const err = await ctx.auth.requestEmailCode('jo@example.com').catch((e) => e);
    assert.equal(err.code, 'unavailable');
    assert.equal(err.status, status);
  }
  const ctx = setup();
  ctx.issuer.on('POST /v1/email/code', (_b, _c, iss) => iss.error(429, 'AXAUTH_QUOTA', { 'Retry-After': '120' }));
  assert.equal((await ctx.auth.requestEmailCode('x@example.com').catch((e) => e)).retryAfterSeconds, 120);
});

test('every request uses credentials omit, no-store, redirect error, no-referrer and JSON bodies', async () => {
  const ctx = setup({ storage: sessionStorageAdapter(new FakeStorage()) });
  await ctx.auth.restore();
  assert.deepEqual(await ctx.auth.signUp('jo@example.com', 'pw'), { status: 'signed_in' });
  ctx.issuer.on('POST /v1/signup', () => ({ status: 202, body: { challenge_id: 'ch-s', expires_in: 600, resend_after: 60 } }));
  assert.deepEqual(await ctx.auth.signUp('jo@example.com', 'pw'), { status: 'verification_sent', challenge: 'ch-s', resendAfterSeconds: 60 });
  await ctx.auth.verifySignUp('ch-s', '123456');
  await ctx.auth.signInWithPassword('jo@example.com', 'pw', { tenant: 'org-1' });
  assert.deepEqual(await ctx.auth.requestEmailCode('jo@example.com'), { challenge: 'ch-1', resendAfterSeconds: 60 });
  await ctx.auth.verifyEmailCode('ch-1', '123456');
  await ctx.auth.requestMagicLink('jo@example.com');
  await ctx.auth.requestPasswordReset('jo@example.com');
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  await ctx.auth.refresh();
  await ctx.auth.selectTenant('org-2');
  const user = await ctx.auth.user();
  assert.deepEqual(user, { id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', kind: 'external', emailVerified: true, hasPassword: false, providers: ['google', 'github'], email: 'jo@example.com' });
  await ctx.auth.changePassword('pw', 'pw2');
  const header = await ctx.auth.authorizationHeader();
  assert.equal(header, 'Bearer ' + ctx.issuer.issuedAccess.at(-1));
  await ctx.auth.signOut({ everywhere: true });

  const routes = new Set(ctx.issuer.calls.map((c) => c.route));
  for (const r of ['POST /v1/signup', 'POST /v1/signup/verify', 'POST /v1/sign-in/password', 'POST /v1/email/code', 'POST /v1/email/code/verify',
    'POST /v1/email/link', 'POST /v1/password/reset', 'POST /v1/token/refresh', 'GET /v1/user', 'POST /v1/password', 'POST /v1/logout-all']) {
    assert.ok(routes.has(r), r);
  }
  assert.deepEqual(ctx.issuer.violations, []);
  for (const c of ctx.issuer.calls) {
    assert.equal(c.init.credentials, 'omit');
    assert.equal(c.init.cache, 'no-store');
    assert.equal(c.init.redirect, 'error');
    assert.equal(c.init.referrerPolicy, 'no-referrer');
    if (c.init.method === 'POST') assert.equal(c.headers['Content-Type'], 'application/json');
    else assert.equal(c.init.body, undefined);
  }
  const signIn = ctx.issuer.callsTo('POST /v1/sign-in/password')[0];
  assert.deepEqual(signIn.body, { email: 'jo@example.com', password: 'pw', tenant: 'org-1' });
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/email/code/verify')[0].body, { challenge_id: 'ch-1', code: '123456' });
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/password')[0].body, { current_password: 'pw', new_password: 'pw2' });
  assert.equal(ctx.issuer.callsTo('GET /v1/user')[0].headers.Authorization.startsWith('Bearer '), true);
  for (const c of ctx.issuer.calls) if (!['GET /v1/user', 'POST /v1/password'].includes(c.route)) assert.equal(c.headers.Authorization, undefined, c.route);
});

test('user() is null without a session; authenticated session maps claims', async () => {
  const ctx = setup();
  assert.equal(await ctx.auth.user(), null);
  assert.equal(await ctx.auth.authorizationHeader(), null);
  await assert.rejects(ctx.auth.changePassword('a', 'b'), { code: 'invalid_token' });
  assert.equal(ctx.issuer.calls.length, 0);
  const s = await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const sess = [...ctx.issuer.sessions.values()][0];
  assert.deepEqual(JSON.parse(JSON.stringify(s)), {
    id: sess.sid,
    status: 'authenticated',
    principal: { subject: sess.sub, tenant: null, roles: ['member'], permissions: ['orders.read'] },
  });
  assert.ok(Object.isFrozen(s));
});

test('memoryStorage and sessionStorageAdapter hold only the refresh record', async () => {
  const rec = { refreshToken: 'axr1_x', refreshExpiresAt: '2026-11-01T00:00:00.000Z', issuer: ISSUER, audience: ISSUER + '/api', sessionId: 's' };
  for (const adapter of [memoryStorage(), sessionStorageAdapter(new FakeStorage())]) {
    assert.equal(adapter.shared, false);
    assert.equal(await adapter.get('k'), null);
    await adapter.set('k', { ...rec, extra: 'dropped' });
    assert.deepEqual(await adapter.get('k'), rec);
    await adapter.remove('k');
    assert.equal(await adapter.get('k'), null);
  }
});

test('createAxiomAuth refuses a missing or malformed issuer', () => {
  assert.throws(() => createAxiomAuth({}), TypeError);
  assert.throws(() => createAxiomAuth({ issuer: 'not a url' }), TypeError);
});

test('review seams: captcha tokens, invitation links, hosted sign-up screen, shared storage without locks', async () => {
  const { setup, makeSharedAdapter, makeBrowser, REDIRECT_URI } = await import('./helpers.mjs');
  const ctx = setup();
  await ctx.auth.requestEmailCode('jo@example.com', { captchaToken: 'cf-token' });
  assert.equal(ctx.issuer.callsTo('POST /v1/email/code')[0].body.captcha_token, 'cf-token');
  await ctx.auth.requestPasswordReset('jo@example.com', { captchaToken: 'cf-2' });
  assert.equal(ctx.issuer.callsTo('POST /v1/password/reset')[0].body.captcha_token, 'cf-2');
  await ctx.auth.signInWithPassword('jo@example.com', 'correct horse battery', { captchaToken: 'cf-3' });
  assert.equal(ctx.issuer.callsTo('POST /v1/sign-in/password')[0].body.captcha_token, 'cf-3');
  await ctx.auth.requestEmailCode('jo@example.com');
  assert.equal('captcha_token' in ctx.issuer.callsTo('POST /v1/email/code')[1].body, false);
  await assert.rejects(ctx.auth.requestEmailCode('jo@example.com', { captchaToken: '' }), { code: 'invalid_request' });

  void ctx.auth.signInHosted({ screen: 'sign_up' });
  await new Promise((resolve) => setTimeout(resolve, 10));
  assert.equal(new URL(ctx.browser.location.assigned.at(-1)).searchParams.get('screen'), 'sign_up');

  const invited = setup({ browser: makeBrowser({ href: REDIRECT_URI + '#axiom_invitation=axi1_secret' }) });
  invited.issuer.on('POST /v1/invitations/accept', (body, call, issuer) => ({ body: issuer.tokens(issuer.createSession()) }));
  const r = await invited.auth.handleRedirect();
  assert.deepEqual(r, { handled: true, invitation: true });
  assert.ok(!invited.browser.location.href.includes('axi1_secret'), 'the invitation token is stripped');
  const s = await invited.auth.acceptInvitation({ password: 'correct horse battery' });
  assert.equal(s.status, 'authenticated');
  assert.deepEqual(invited.issuer.callsTo('POST /v1/invitations/accept')[0].body.token, 'axi1_secret');
  await assert.rejects(invited.auth.acceptInvitation(), { code: 'invalid_code' }, 'single use');

  const { createAxiomAuth } = await import('../dist/index.js');
  assert.throws(() => createAxiomAuth({ issuer: ctx.issuer.issuer, storage: makeSharedAdapter(), globalObject: makeBrowser() }), /navigator.locks/);
});

test('review: signOut before restore revokes the stored refresh token; a failed persist still pushes the rotated token', async () => {
  const { setup, FakeStorage, ISSUER } = await import('./helpers.mjs');
  const { sessionStorageAdapter } = await import('../dist/index.js');
  const backing = new FakeStorage();
  const first = setup({ storage: sessionStorageAdapter(backing) });
  await first.auth.signInWithPassword('jo@example.com', 'correct horse battery');
  const stored = JSON.parse(backing.getItem('axiom-auth:refresh:' + ISSUER)).refreshToken;
  const second = setup({ storage: sessionStorageAdapter(backing) });
  second.issuer.sessions = first.issuer.sessions;
  await second.auth.signOut();
  assert.equal(second.issuer.callsTo('POST /v1/logout')[0].body.refresh_token, stored);
  assert.equal(backing.length, 0);

  const full = new FakeStorage();
  const ctx = setup({ storage: sessionStorageAdapter(full) });
  await ctx.auth.signInWithPassword('jo@example.com', 'correct horse battery');
  full.setItem = () => { throw new Error('QuotaExceededError'); };
  await ctx.clock.advance(800 * 1000);
  assert.ok(ctx.issuer.rotations >= 1);
  assert.equal(ctx.tokens.at(-1), ctx.issuer.issuedAccess.at(-1), 'the rotated access token reaches the transport');
  assert.equal(ctx.auth.session().status, 'authenticated');
});
