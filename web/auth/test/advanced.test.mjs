// auth-advanced/v1 17.1 (MFA, passkeys, step-up, factors, consents) and branches-v1 B10
// (refresh once and retry once on `401 authorization_changed`).
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import * as pkg from '../dist/index.js';
import { ISSUER, ORIGIN, REDIRECT_URI, flush, makeBrowser, makeClock, makeLocks, makeSharedAdapter, setup, s256 } from './helpers.mjs';

const { parseStepUpChallenge, runtimeAuthRefusal } = pkg;
const TOTP_ID = '0b5c3f0e-1111-4111-8111-000000000001';
const KEY_ID = '0b5c3f0e-1111-4111-8111-000000000002';
const SMS_ID = '0b5c3f0e-1111-4111-8111-000000000003';
const ticket = () => 'axs1.' + randomBytes(48).toString('base64url');
const b64u = (bytes) => Buffer.from(bytes).toString('base64url');

function mfaRequired(t, extra = {}) {
  return {
    status: 401,
    body: { error: { code: 'AXAUTH_MFA_REQUIRED', mfa: { ticket: t, expires_in: 300, recovery_codes: true, factors: [
      { id: TOTP_ID, type: 'totp', label: 'Phone' }, { id: KEY_ID, type: 'passkey', label: 'Laptop' },
      { id: SMS_ID, type: 'sms', label: 'SMS', usable: false },
    ], ...extra } } },
  };
}

function withAssurance(issuer, acr, amr) {
  const s = issuer.createSession();
  s.acr = acr;
  s.amr = amr;
  return { body: issuer.tokens(s) };
}

// Everything a test run has seen that must never reach storage, session() or JSON.
function assertAbsent(ctx, secrets) {
  const surfaces = {
    localStorage: ctx.browser.localStorage.dump(),
    sessionStorage: ctx.browser.sessionStorage.dump(),
    session: JSON.stringify(ctx.auth.session()),
    json: JSON.stringify(ctx.auth),
    challenge: JSON.stringify(ctx.auth.mfaChallenge()),
  };
  for (const [name, text] of Object.entries(surfaces)) {
    for (const secret of secrets) assert.ok(!text.includes(secret), `${name} holds a secret`);
  }
}

// A virtual authenticator: records the decoded options and returns binary members.
function fakeCredentials() {
  const seen = [];
  const bytes = (n, fill) => new Uint8Array(n).fill(fill).buffer;
  const credentials = {
    seen,
    async create({ publicKey }) {
      seen.push({ kind: 'create', publicKey });
      return {
        id: 'cred-1', rawId: bytes(16, 7), type: 'public-key', authenticatorAttachment: 'platform',
        response: { clientDataJSON: bytes(8, 1), attestationObject: bytes(8, 2), getTransports: () => ['internal'] },
        getClientExtensionResults: () => ({ credProps: { rk: true } }),
      };
    },
    async get({ publicKey }) {
      seen.push({ kind: 'get', publicKey });
      return {
        id: 'cred-1', rawId: bytes(16, 7), type: 'public-key',
        response: { clientDataJSON: bytes(8, 1), authenticatorData: bytes(8, 3), signature: bytes(8, 4), userHandle: bytes(16, 5) },
        getClientExtensionResults: () => ({}),
      };
    },
  };
  return credentials;
}

const requestOptionsJSON = () => ({ challenge: b64u([9, 9, 9]), timeout: 300000, rpId: 'localhost', userVerification: 'required', allowCredentials: [{ type: 'public-key', id: b64u([7, 7]) }] });

test('password sign-in with a second factor: private ticket, factor list, TOTP completion at aal2', async () => {
  const ctx = setup();
  const t = ticket();
  ctx.issuer.on('POST /v1/sign-in/password', () => mfaRequired(t));
  ctx.issuer.on('POST /v1/mfa/verify', (body, call, issuer) => withAssurance(issuer, 'aal2', ['mfa', 'pwd', 'totp']));
  const err = await ctx.auth.signInWithPassword('jo@example.com', 'pw').catch((e) => e);
  assert.equal(err.code, 'mfa_required');
  assert.equal(err.status, 401);
  assert.ok(!JSON.stringify(err).includes(t) && !String(err.stack).includes(t) && !Object.values(err).includes(t));
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.auth.mfaChallenge())), {
    factors: [{ id: TOTP_ID, type: 'totp', label: 'Phone' }, { id: KEY_ID, type: 'passkey', label: 'Laptop' }],
    recoveryCodes: true,
  });
  assert.ok(Object.isFrozen(ctx.auth.mfaChallenge()));
  assert.equal(ctx.auth.session().status, 'unknown');
  assertAbsent(ctx, [t]);

  await ctx.auth.verifyMfa(TOTP_ID, '000000');
  const [verify] = ctx.issuer.callsTo('POST /v1/mfa/verify');
  // Strict server decoding: exactly the completion members, no audience, no verifier for a JSON flow.
  assert.deepEqual(Object.keys(verify.body).sort(), ['code', 'factor_id', 'ticket']);
  assert.equal(verify.body.ticket, t);
  const s = ctx.auth.session();
  assert.equal(s.status, 'authenticated');
  assert.equal(s.acr, 'aal2');
  assert.equal(ctx.auth.mfaChallenge(), null, 'ticket cleared after completion');
  assertAbsent(ctx, [t]);
  assert.deepEqual(ctx.issuer.violations, []);
});

test('the ticket expires after expires_in; a wrong code keeps it; a recovery code completes', async () => {
  const ctx = setup();
  const t = ticket();
  ctx.issuer.on('POST /v1/sign-in/password', () => mfaRequired(t));
  let attempts = 0;
  ctx.issuer.on('POST /v1/mfa/verify', (body, call, issuer) => (++attempts === 1 ? issuer.error(401, 'AXAUTH_INVALID_CODE') : withAssurance(issuer, 'aal2', ['mfa', 'pwd', 'recovery'])));
  await assert.rejects(ctx.auth.signInWithPassword('jo@example.com', 'pw'), { code: 'mfa_required' });
  await assert.rejects(ctx.auth.verifyMfa(TOTP_ID, '111111'), { code: 'invalid_code' });
  assert.notEqual(ctx.auth.mfaChallenge(), null);
  await ctx.auth.verifyRecoveryCode('abcde-fghij');
  const calls = ctx.issuer.callsTo('POST /v1/mfa/verify');
  assert.deepEqual(Object.keys(calls[1].body).sort(), ['recovery_code', 'ticket']);
  assert.equal(ctx.auth.session().acr, 'aal2');

  const ctx2 = setup();
  ctx2.issuer.on('POST /v1/sign-in/password', () => mfaRequired(ticket()));
  await assert.rejects(ctx2.auth.signInWithPassword('jo@example.com', 'pw'), { code: 'mfa_required' });
  ctx2.clock.set(ctx2.clock.now() + 301 * 1000);
  assert.equal(ctx2.auth.mfaChallenge(), null);
  await assert.rejects(ctx2.auth.verifyMfa(TOTP_ID, '123456'), { code: 'mfa_required' });
  assert.equal(ctx2.issuer.callsTo('POST /v1/mfa/verify').length, 0);
});

test('a new first-factor attempt and signOut drop an unfinished MFA ticket', async () => {
  const ctx = setup();
  ctx.issuer.on('POST /v1/sign-in/password', () => mfaRequired(ticket()));
  await assert.rejects(ctx.auth.signInWithPassword('jo@example.com', 'pw'), { code: 'mfa_required' });
  ctx.issuer.on('POST /v1/sign-in/password', undefined);
  ctx.issuer.handlers.delete('POST /v1/sign-in/password');
  await ctx.auth.requestEmailCode('jo@example.com');
  await ctx.auth.verifyEmailCode('ch-1', '123456');
  assert.equal(ctx.auth.mfaChallenge(), null);
  ctx.issuer.on('POST /v1/email/code/verify', () => mfaRequired(ticket()));
  await assert.rejects(ctx.auth.verifyEmailCode('ch-1', '123456'), { code: 'mfa_required' });
  await ctx.auth.signOut();
  assert.equal(ctx.auth.mfaChallenge(), null);
});

test('SMS: send with the ticket, then verify; unusable factors are not offered', async () => {
  const ctx = setup();
  const t = ticket();
  ctx.issuer.on('POST /v1/sign-in/password', () => mfaRequired(t, { factors: [{ id: SMS_ID, type: 'sms', label: 'SMS' }] }));
  ctx.issuer.on('POST /v1/mfa/sms/send', () => ({ status: 202, body: { challenge_id: 'c', expires_in: 300, resend_after: 45 } }));
  ctx.issuer.on('POST /v1/mfa/verify', (body, call, issuer) => withAssurance(issuer, 'aal2', ['mfa', 'pwd', 'sms']));
  await assert.rejects(ctx.auth.signInWithPassword('jo@example.com', 'pw'), { code: 'mfa_required' });
  assert.deepEqual(await ctx.auth.sendSmsCode(SMS_ID), { resendAfterSeconds: 45 });
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/mfa/sms/send')[0].body, { ticket: t, factor_id: SMS_ID });
  await ctx.auth.verifyMfa(SMS_ID, '123456');
  assert.equal(ctx.auth.session().status, 'authenticated');
});

test('redirect MFA: mfa_ticket is stripped synchronously and bound to the PKCE verifier; passkey completes', async () => {
  const credentials = fakeCredentials();
  const browser = makeBrowser();
  browser.navigator = { credentials };
  const ctx = setup({ browser });
  ctx.auth.signInHosted();
  await flush();
  const start = new URL(ctx.browser.location.assigned.at(-1));
  const t = ticket();
  const cb = new URL(REDIRECT_URI);
  cb.searchParams.set('error', 'mfa_required');
  cb.searchParams.set('mfa_ticket', t);
  cb.searchParams.set('state', start.searchParams.get('state'));
  cb.searchParams.set('iss', ISSUER);
  ctx.browser.location.href = cb.href;
  const done = ctx.auth.handleRedirect();
  assert.equal(ctx.browser.location.href, REDIRECT_URI, 'URL clean before app code runs');
  await assert.rejects(done, { code: 'mfa_required' });
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.auth.mfaChallenge())), { factors: [], recoveryCodes: true });
  assertAbsent(ctx, [t]);

  ctx.issuer.on('POST /v1/mfa/webauthn/options', () => ({ body: { challenge: 'sealed-1', options: requestOptionsJSON() } }));
  ctx.issuer.on('POST /v1/mfa/webauthn/verify', (body, call, issuer) => withAssurance(issuer, 'phr', ['mfa', 'passkey', 'pwd']));
  await ctx.auth.verifyMfaWithPasskey();
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/mfa/webauthn/options')[0].body, { ticket: t });
  const verify = ctx.issuer.callsTo('POST /v1/mfa/webauthn/verify')[0].body;
  assert.deepEqual(Object.keys(verify).sort(), ['challenge', 'code_verifier', 'credential', 'ticket']);
  assert.equal(s256(verify.code_verifier), start.searchParams.get('code_challenge'));
  assert.equal(verify.challenge, 'sealed-1');
  assert.deepEqual(verify.credential.response, { clientDataJSON: b64u(new Uint8Array(8).fill(1)), authenticatorData: b64u(new Uint8Array(8).fill(3)), signature: b64u(new Uint8Array(8).fill(4)), userHandle: b64u(new Uint8Array(16).fill(5)) });
  const seen = credentials.seen[0].publicKey;
  assert.ok(seen.challenge instanceof ArrayBuffer && seen.allowCredentials[0].id instanceof ArrayBuffer);
  assert.equal(ctx.auth.session().acr, 'phr');
});

test('a redirect error without a matching transaction keeps no ticket', async () => {
  const ctx = setup();
  const cb = new URL(REDIRECT_URI);
  cb.searchParams.set('error', 'mfa_required');
  cb.searchParams.set('mfa_ticket', ticket());
  cb.searchParams.set('state', 'unknown');
  cb.searchParams.set('iss', ISSUER);
  await assert.rejects(ctx.auth.handleRedirect(cb.href), { code: 'state_mismatch' });
  assert.equal(ctx.auth.mfaChallenge(), null);
});

test('enrollment required: TOTP enrolled with the enroll ticket, tokens complete the sign-in, secrets not kept', async () => {
  const ctx = setup({ storage: undefined });
  const t = ticket();
  const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
  const codes = Array.from({ length: 10 }, (_, i) => `abcd${i}-efgh${i}`);
  ctx.issuer.on('POST /v1/sign-in/password', () => ({ status: 401, body: { error: { code: 'AXAUTH_MFA_ENROLLMENT_REQUIRED', mfa_enrollment: { ticket: t, types: ['totp', 'passkey', 'bogus'] } } } }));
  ctx.issuer.on('POST /v1/factors/totp', () => ({ status: 201, body: { factor_id: TOTP_ID, secret, otpauth_uri: `otpauth://totp/App:j***@example.com?secret=${secret}&issuer=App&digits=6&period=30` } }));
  ctx.issuer.on(`POST /v1/factors/totp/${TOTP_ID}/confirm`, (body, call, issuer) => {
    const s = issuer.createSession();
    s.acr = 'aal2';
    s.amr = ['mfa', 'pwd', 'totp'];
    return { body: { factor: { id: TOTP_ID, type: 'totp', label: 'Phone', status: 'active', usable: true, reenroll_required: false, created_at: '2026-11-01T00:00:00Z', last_used_on: null }, recovery_codes: codes, tokens: issuer.tokens(s) } };
  });
  await assert.rejects(ctx.auth.signInWithPassword('jo@example.com', 'pw'), { code: 'mfa_enrollment_required' });
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.auth.mfaChallenge())), { factors: [], recoveryCodes: false, enrollment: { types: ['totp', 'passkey'] } });
  const enrollment = await ctx.auth.enrollTotp('Phone');
  assert.equal(enrollment.secret, secret);
  const enroll = ctx.issuer.callsTo('POST /v1/factors/totp')[0];
  assert.deepEqual(enroll.body, { label: 'Phone', ticket: t });
  assert.equal(enroll.headers.Authorization, undefined, 'ticket in place of a bearer');
  const out = await ctx.auth.confirmTotp(TOTP_ID, '123456');
  assert.deepEqual(out, { recoveryCodes: codes });
  assert.deepEqual(ctx.issuer.callsTo(`POST /v1/factors/totp/${TOTP_ID}/confirm`)[0].body, { code: '123456', ticket: t });
  assert.equal(ctx.auth.session().status, 'authenticated');
  assert.equal(ctx.auth.session().acr, 'aal2');
  assert.equal(ctx.auth.mfaChallenge(), null);
  assertAbsent(ctx, [t, secret, ...codes]);
});

test('signInWithPasskey: discoverable options, assertion JSON, tenant and audience, phr session', async () => {
  const credentials = fakeCredentials();
  const browser = makeBrowser();
  browser.navigator = { credentials };
  const ctx = setup({ browser, audience: ISSUER + '/api' });
  ctx.issuer.on('POST /v1/passkeys/options', () => ({ body: { challenge: 'sealed-2', options: { challenge: b64u([1, 2, 3]), rpId: 'localhost', userVerification: 'required' } } }));
  ctx.issuer.on('POST /v1/sign-in/passkey', (body, call, issuer) => withAssurance(issuer, 'phr', ['passkey']));
  const s = await ctx.auth.signInWithPasskey({ tenant: 'org_1' });
  assert.equal(s.acr, 'phr');
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/passkeys/options')[0].body, {});
  const body = ctx.issuer.callsTo('POST /v1/sign-in/passkey')[0].body;
  assert.deepEqual(Object.keys(body).sort(), ['audience', 'challenge', 'credential', 'tenant']);
  assert.equal(body.credential.rawId, b64u(new Uint8Array(16).fill(7)));
  assert.equal(body.credential.type, 'public-key');

  const failing = setup({ browser: Object.assign(makeBrowser(), { navigator: { credentials: { get: async () => { throw new Error('NotAllowedError'); } } } }) });
  failing.issuer.on('POST /v1/passkeys/options', () => ({ body: { challenge: 'c', options: { challenge: b64u([1]) } } }));
  await assert.rejects(failing.auth.signInWithPasskey(), { code: 'webauthn' });
  assert.equal(failing.issuer.callsTo('POST /v1/sign-in/passkey').length, 0);
});

test('registerPasskey: creation options decoded, attestation posted, recovery codes returned once', async () => {
  const credentials = fakeCredentials();
  const browser = makeBrowser();
  browser.navigator = { credentials };
  const ctx = setup({ browser });
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  ctx.issuer.on('POST /v1/factors/passkeys/options', () => ({ body: { challenge: 'sealed-3', options: {
    challenge: b64u([4, 4]), rp: { id: 'localhost', name: 'App' }, user: { id: b64u([5, 5]), name: 'jo', displayName: 'jo' },
    pubKeyCredParams: [{ type: 'public-key', alg: -7 }], excludeCredentials: [{ type: 'public-key', id: b64u([6]) }],
  } } }));
  ctx.issuer.on('POST /v1/factors/passkeys', () => ({ status: 201, body: { factor: { id: KEY_ID, type: 'passkey', label: 'Laptop', status: 'active', created_at: '2026-11-01T00:00:00Z' }, recovery_codes: ['aaaaa-bbbbb'] } }));
  const f = await ctx.auth.registerPasskey('Laptop');
  assert.deepEqual(f, { id: KEY_ID, type: 'passkey', label: 'Laptop', status: 'active', createdAt: '2026-11-01T00:00:00Z', recoveryCodes: ['aaaaa-bbbbb'] });
  const opts = ctx.issuer.callsTo('POST /v1/factors/passkeys/options')[0];
  assert.ok(opts.headers.Authorization.startsWith('Bearer '));
  const created = credentials.seen[0].publicKey;
  assert.ok(created.challenge instanceof ArrayBuffer && created.user.id instanceof ArrayBuffer && created.excludeCredentials[0].id instanceof ArrayBuffer);
  const reg = ctx.issuer.callsTo('POST /v1/factors/passkeys')[0].body;
  assert.deepEqual(Object.keys(reg).sort(), ['challenge', 'credential', 'label']);
  assert.deepEqual(reg.credential.response.transports, ['internal']);
  assert.ok(typeof reg.credential.response.attestationObject === 'string');
  assertAbsent(ctx, ['aaaaa-bbbbb']);
});

test('stepUp(password): bearer plus refresh token, rotation replaces the session tokens, acr from the token', async () => {
  const ctx = setup();
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const sess = [...ctx.issuer.sessions.values()][0];
  const before = sess.current;
  ctx.issuer.on('POST /v1/reauthenticate', (body, call, issuer) => {
    assert.equal(body.refresh_token, before);
    sess.previous.add(sess.current);
    sess.current = issuer.newRefresh(sess.sid, ++sess.counter);
    sess.acr = 'aal1';
    sess.amr = ['pwd'];
    sess.authTime = Math.floor(ctx.clock.now() / 1000);
    return { body: issuer.tokens(sess) };
  });
  ctx.clock.set(ctx.clock.now() + 60 * 1000);
  const s = await ctx.auth.stepUp({ method: 'password', password: 'pw' });
  const call = ctx.issuer.callsTo('POST /v1/reauthenticate')[0];
  assert.deepEqual(Object.keys(call.body).sort(), ['method', 'password', 'refresh_token']);
  assert.ok(call.headers.Authorization.startsWith('Bearer '));
  assert.equal(s.authTime, Math.floor(ctx.clock.now() / 1000));
  // The rotated refresh token is the one used next.
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  await ctx.auth.refresh();
  assert.equal(ctx.issuer.callsTo('POST /v1/token/refresh')[0].body.refresh_token, ctx.issuer.issuedRefresh.at(-2));
  assert.equal(ctx.issuer.supersededPresented, 0);
});

test('stepUp(totp) finds the one active factor; two need factorId; a refusal keeps the session', async () => {
  const ctx = setup();
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const sess = [...ctx.issuer.sessions.values()][0];
  let factors = [{ id: TOTP_ID, type: 'totp', label: 'P', status: 'active', usable: true }, { id: KEY_ID, type: 'passkey', label: 'L', status: 'active', usable: true }];
  ctx.issuer.on('GET /v1/factors', () => ({ body: { factors, recovery_codes_remaining: 9 } }));
  ctx.issuer.on('POST /v1/reauthenticate', (body, call, issuer) => {
    if (body.code === '000000') return { status: 401, body: { error: { code: 'AXAUTH_STEP_UP_REQUIRED' } }, headers: { 'WWW-Authenticate': 'Bearer error="insufficient_user_authentication", error_description="step-up required", acr_values="phr"' } };
    sess.previous.add(sess.current);
    sess.current = issuer.newRefresh(sess.sid, ++sess.counter);
    sess.acr = 'aal2';
    sess.amr = ['mfa', 'pwd', 'totp'];
    return { body: issuer.tokens(sess) };
  });
  const s = await ctx.auth.stepUp({ method: 'totp', code: '123456', acr: 'aal2' });
  assert.equal(s.acr, 'aal2');
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/reauthenticate')[0].body.factor_id, TOTP_ID);
  assert.equal(ctx.issuer.callsTo('POST /v1/reauthenticate')[0].body.acr, 'aal2');
  const id = ctx.auth.session().id;
  await assert.rejects(ctx.auth.stepUp({ method: 'totp', code: '000000', factorId: TOTP_ID }), { code: 'step_up_required' });
  assert.equal(ctx.auth.session().status, 'authenticated');
  assert.equal(ctx.auth.session().id, id);
  factors = [...factors, { id: SMS_ID.replace('3', '4'), type: 'totp', label: 'Q', status: 'active', usable: true }];
  await assert.rejects(ctx.auth.stepUp({ method: 'totp', code: '123456' }), { code: 'invalid_request' });
  await assert.rejects(ctx.auth.stepUp({ method: 'email', code: '1' }), { code: 'invalid_request' });
  await assert.rejects(setup().auth.stepUp({ method: 'password', password: 'x' }), { code: 'invalid_token' });
});

test('stepUp and a concurrent refresh never present the same refresh token twice (shared storage, locks)', async () => {
  const clock = makeClock();
  const locks = makeLocks();
  const browser = makeBrowser({ locks });
  const storage = makeSharedAdapter();
  const ctx = setup({ browser, clock, storage });
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const sess = [...ctx.issuer.sessions.values()][0];
  ctx.issuer.on('POST /v1/reauthenticate', (body, call, issuer) => {
    if (sess.current !== body.refresh_token) return issuer.error(401, 'AXAUTH_INVALID_REFRESH');
    sess.previous.add(sess.current);
    sess.current = issuer.newRefresh(sess.sid, ++sess.counter);
    sess.lastRotated = clock.now();
    return { body: issuer.tokens(sess) };
  });
  clock.set(clock.now() + 800 * 1000);
  const [a, b, c] = await Promise.allSettled([ctx.auth.refresh(), ctx.auth.stepUp({ method: 'password', password: 'pw' }), ctx.auth.refresh()]);
  assert.equal(a.status, 'fulfilled');
  assert.equal(b.status, 'fulfilled');
  assert.equal(c.status, 'fulfilled');
  assert.equal(ctx.issuer.supersededPresented, 0);
  assert.equal(storage.map.get('axiom-auth:refresh:' + ISSUER).refreshToken, sess.current);
  assert.ok(locks.requests.length >= 2);
});

test('factors, recovery codes, phone and consents call the documented routes with a bearer', async () => {
  const ctx = setup();
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  ctx.issuer.on('GET /v1/factors', () => ({ body: { factors: [
    { id: TOTP_ID, type: 'totp', label: 'P', status: 'active', usable: true, reenroll_required: false, created_at: '2026-11-01T00:00:00Z', last_used_on: '2026-11-01' },
    { id: 'x', type: 'unknown', label: 'Z', status: 'active' },
  ], recovery_codes_remaining: 2, phone: { masked: '+44 ** **** 0123', verified_at: '2026-11-01T00:00:00Z' } } }));
  ctx.issuer.on(`DELETE /v1/factors/${TOTP_ID}`, () => ({ body: { removed: true } }));
  ctx.issuer.on('POST /v1/recovery-codes', () => ({ body: { recovery_codes: ['a1b2c-d3e4f'] } }));
  ctx.issuer.on('POST /v1/phone', () => ({ status: 202, body: { challenge_id: 'pc', expires_in: 300, resend_after: 60 } }));
  ctx.issuer.on('POST /v1/phone/verify', () => ({ body: { phone: { masked: 'm', verified_at: 'x' } } }));
  ctx.issuer.on('POST /v1/factors/sms', () => ({ status: 201, body: { factor: { id: SMS_ID, type: 'sms', label: 'SMS', status: 'active', created_at: 'c' } } }));
  ctx.issuer.on('GET /v1/consents', () => ({ body: { consents: [{ client_id: 'axcl_' + 'a'.repeat(22), name: 'Reports', scopes: ['openid'], granted_at: 'g' }] } }));
  ctx.issuer.on('DELETE /v1/consents/axcl_' + 'a'.repeat(22), () => ({ body: { revoked: true } }));
  assert.deepEqual(await ctx.auth.listFactors(), {
    factors: [{ id: TOTP_ID, type: 'totp', label: 'P', status: 'active', createdAt: '2026-11-01T00:00:00Z', lastUsedOn: '2026-11-01' }],
    recoveryCodesRemaining: 2,
    phone: { masked: '+44 ** **** 0123' },
  });
  await ctx.auth.removeFactor(TOTP_ID);
  await assert.rejects(ctx.auth.removeFactor('../x'), { code: 'invalid_request' });
  assert.deepEqual(await ctx.auth.regenerateRecoveryCodes(), ['a1b2c-d3e4f']);
  assert.deepEqual(await ctx.auth.addPhone('+441234560123'), { challengeId: 'pc' });
  await ctx.auth.verifyPhone('pc', '123456');
  assert.equal((await ctx.auth.enableSmsFactor()).id, SMS_ID);
  assert.deepEqual(await ctx.auth.listConsents(), [{ clientId: 'axcl_' + 'a'.repeat(22), name: 'Reports', scopes: ['openid'] }]);
  await ctx.auth.revokeConsent('axcl_' + 'a'.repeat(22));
  await assert.rejects(ctx.auth.revokeConsent('../../v1/logout'), { code: 'invalid_request' });
  for (const c of ctx.issuer.calls.filter((c) => !c.route.startsWith('POST /v1/sign-in'))) {
    assert.ok(c.headers.Authorization?.startsWith('Bearer '), c.route);
  }
  assert.deepEqual(ctx.issuer.violations, []);
  const removed = ctx.issuer.callsTo(`DELETE /v1/factors/${TOTP_ID}`)[0];
  assert.equal(removed.init.body, undefined);
});

test('step-up and factor errors keep their mechanical names', async () => {
  const ctx = setup();
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const names = { AXAUTH_FACTOR_LIMIT: 'factor_limit', AXAUTH_FACTOR_REQUIRED: 'factor_required', AXAUTH_PHONE_NOT_ALLOWED: 'phone_not_allowed',
    AXAUTH_FEATURE_DISABLED: 'feature_disabled', AXAUTH_HOOK_FAILED: 'hook_failed', AXAUTH_WEBAUTHN: 'webauthn', AXAUTH_STEP_UP_REQUIRED: 'step_up_required', AXAUTH_SOMETHING: 'unavailable' };
  for (const [code, name] of Object.entries(names)) {
    ctx.issuer.on('POST /v1/phone', (b, c, issuer) => issuer.error(400, code));
    await assert.rejects(ctx.auth.addPhone('+1'), { code: name });
  }
});

test('parseStepUpChallenge and runtimeAuthRefusal read RFC 9470 and the runtime body', () => {
  const r = (h) => new Response('', { status: 401, headers: h ? { 'WWW-Authenticate': h } : {} });
  assert.deepEqual(parseStepUpChallenge(r('Bearer error="insufficient_user_authentication", error_description="step-up required", acr_values="aal2", max_age=600')), { acr: 'aal2', maxAge: 600 });
  assert.deepEqual(parseStepUpChallenge(r('Bearer error="insufficient_user_authentication", acr_values="phr"')), { acr: 'phr' });
  assert.equal(parseStepUpChallenge(r('Bearer error="invalid_token", error_description="authorization_changed"')), null);
  assert.equal(parseStepUpChallenge(r(null)), null);
  assert.deepEqual(runtimeAuthRefusal({ error: { status: 401, code: 'step_up_required', path: 'authorization', message: 'step-up required: acr_values=aal2, max_age=600' } }), { code: 'step_up_required', acr: 'aal2', maxAge: 600 });
  assert.deepEqual(runtimeAuthRefusal('{"error":{"status":401,"code":"authorization_changed","path":"authentication","message":"changed"}}'), { code: 'authorization_changed' });
  assert.equal(runtimeAuthRefusal('not json'), null);
  assert.equal(runtimeAuthRefusal({ error: { code: 'forbidden' } }), null);
});

// B10: an app API behind the Acore runtime.
function appApi(ctx, behaviour) {
  const app = { calls: [] };
  const issuerFetch = ctx.issuer.fetch;
  const fetch = async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (url.startsWith(ISSUER)) return issuerFetch(url, init);
    const headers = new Headers(init.headers);
    const body = input instanceof Request ? await input.text() : init.body;
    app.calls.push({ url, authorization: headers.get('Authorization'), body });
    return behaviour(app.calls.length, headers.get('Authorization'), body);
  };
  return { app, fetch };
}

const API = 'https://api.example.com';

const changed = (exposed) => new Response(JSON.stringify({ error: { status: 401, code: 'authorization_changed', path: 'authentication', message: 'changed' } }), {
  status: 401, headers: exposed ? { 'WWW-Authenticate': 'Bearer error="invalid_token", error_description="authorization_changed"' } : {},
});

test('authorizedFetch: 401 authorization_changed refreshes once and retries once with the new token', async () => {
  const clock = makeClock();
  let api;
  const ctx = setup({ clock, fetch: (u, i) => api.fetch(u, i), apiOrigins: [API] });
  api = appApi(ctx, (n) => (n === 1 ? changed(false) : new Response('{"ok":true}', { status: 200 })));
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const res = await ctx.auth.authorizedFetch('https://api.example.com/orders', { method: 'POST', body: '{"n":1}', headers: { 'Content-Type': 'application/json' } });
  assert.equal(res.status, 200);
  assert.equal(api.app.calls.length, 2);
  assert.notEqual(api.app.calls[0].authorization, api.app.calls[1].authorization);
  assert.equal(api.app.calls[1].body, '{"n":1}');
  assert.equal(ctx.issuer.callsTo('POST /v1/token/refresh').length, 1);
});

test('authorizedFetch: a second authorization_changed is returned, never a loop; other 401s are not retried', async () => {
  let api;
  const ctx = setup({ fetch: (u, i) => api.fetch(u, i), apiOrigins: [API] });
  api = appApi(ctx, () => changed(true));
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const res = await ctx.auth.authorizedFetch('https://api.example.com/orders');
  assert.equal(res.status, 401);
  assert.equal(api.app.calls.length, 2);
  assert.equal(ctx.issuer.callsTo('POST /v1/token/refresh').length, 1);

  let api2;
  const ctx2 = setup({ fetch: (u, i) => api2.fetch(u, i), apiOrigins: [API] });
  api2 = appApi(ctx2, () => new Response(JSON.stringify({ error: { status: 401, code: 'step_up_required', path: 'authorization', message: 'step-up required: acr_values=aal2' } }), { status: 401 }));
  await ctx2.auth.signInWithPassword('jo@example.com', 'pw');
  const res2 = await ctx2.auth.authorizedFetch('https://api.example.com/admin');
  assert.equal(res2.status, 401);
  assert.deepEqual(runtimeAuthRefusal(await res2.text()), { code: 'step_up_required', acr: 'aal2' });
  assert.equal(api2.app.calls.length, 1);
  assert.equal(ctx2.issuer.callsTo('POST /v1/token/refresh').length, 0);
});

test('authorizedFetch: a streamed body is not replayed; a Request input is cloned for the retry; signed out sends no header', async () => {
  let api;
  const ctx = setup({ fetch: (u, i) => api.fetch(u, i), apiOrigins: [API] });
  api = appApi(ctx, (n) => (n === 1 ? changed(false) : new Response('ok')));
  const anon = await ctx.auth.authorizedFetch('https://api.example.com/public');
  assert.equal(api.app.calls[0].authorization, null);
  assert.equal(anon.status, 401, 'no token, no retry');
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  api.app.calls.length = 0;
  api = appApi(ctx, (n) => (n === 1 ? changed(false) : new Response('ok')));
  const stream = new ReadableStream({ start(c) { c.enqueue(new TextEncoder().encode('x')); c.close(); } });
  const res = await ctx.auth.authorizedFetch('https://api.example.com/upload', { method: 'POST', body: stream, duplex: 'half' });
  assert.equal(res.status, 401);
  assert.equal(api.app.calls.length, 1);
  api = appApi(ctx, (n) => (n === 1 ? changed(false) : new Response('ok')));
  const req = new Request('https://api.example.com/orders', { method: 'PUT', body: 'payload' });
  const res2 = await ctx.auth.authorizedFetch(req);
  assert.equal(res2.status, 200);
  assert.deepEqual(api.app.calls.map((c) => c.body), ['payload', 'payload']);
});

test('authorizedFetch: the bearer goes only to the page origin and apiOrigins entries (FR-A L-4)', async () => {
  let api;
  const ctx = setup({ fetch: (u, i) => api.fetch(u, i), apiOrigins: [API] });
  api = appApi(ctx, () => changed(false));
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  await ctx.auth.authorizedFetch('https://evil.example.net/steal', { headers: { 'X-Test': '1' } });
  await ctx.auth.authorizedFetch('https://api.example.com.evil.example.net/x');
  await ctx.auth.authorizedFetch('http://api.example.com/x');
  await ctx.auth.authorizedFetch(new Request('https://evil.example.net/r'));
  assert.deepEqual(api.app.calls.map((c) => c.authorization), [null, null, null, null], 'other origins: no bearer');
  assert.equal(ctx.issuer.callsTo('POST /v1/token/refresh').length, 0, 'other origins: no refresh-and-retry');
  api.app.calls.length = 0;
  api = appApi(ctx, () => new Response('ok'));
  await ctx.auth.authorizedFetch('/orders');
  await ctx.auth.authorizedFetch(ORIGIN + '/orders');
  await ctx.auth.authorizedFetch(new URL(API + '/orders'));
  assert.ok(api.app.calls.every((c) => c.authorization?.startsWith('Bearer ')), 'same origin and listed origins get the bearer');
  // Without apiOrigins another origin never gets it.
  let api2;
  const ctx2 = setup({ fetch: (u, i) => api2.fetch(u, i) });
  api2 = appApi(ctx2, () => new Response('ok'));
  await ctx2.auth.signInWithPassword('jo@example.com', 'pw');
  await ctx2.auth.authorizedFetch(API + '/orders');
  assert.equal(api2.app.calls[0].authorization, null);
  assert.throws(() => setup({ apiOrigins: ['https://api.example.com/path'] }), TypeError);
  assert.throws(() => setup({ apiOrigins: ['http://api.example.com'] }), TypeError);
});

test('the access token acr and auth_time reach the public session; W7 tokens without acr read as aal1', async () => {
  const ctx = setup();
  ctx.issuer.on('POST /v1/sign-in/password', (b, c, issuer) => withAssurance(issuer, 'phr', ['passkey']));
  const s = await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  assert.equal(s.acr, 'phr');
  const plain = setup();
  assert.equal((await plain.auth.signInWithPassword('jo@example.com', 'pw')).acr, 'aal1');
  assert.equal(ORIGIN, new URL(REDIRECT_URI).origin);
});
