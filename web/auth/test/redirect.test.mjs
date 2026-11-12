import test from 'node:test';
import assert from 'node:assert/strict';
import { FakeStorage, ISSUER, ORIGIN, REDIRECT_URI, flush, makeBrowser, makeClock, nextAssignment, setup, s256 } from './helpers.mjs';

async function startHosted(ctx, opts) {
  const before = ctx.browser.location.assigned.length;
  ctx.auth.signInHosted(opts);
  return nextAssignment(ctx.browser, before + 1);
}

function callbackUrl(params, base = REDIRECT_URI) {
  const u = new URL(base);
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, v);
  return u.href;
}

test('provider code redemption: one POST with the stored verifier, then authenticated', async () => {
  const ctx = setup();
  const start = await startHosted(ctx, { returnTo: '/orders?tab=open' });
  const { code, state } = ctx.issuer.grantFor(start);
  ctx.browser.location.href = callbackUrl({ code, state, iss: ISSUER });
  const result = await ctx.auth.handleRedirect();
  assert.deepEqual(result, { handled: true, returnTo: '/orders?tab=open' });
  const [redeem] = ctx.issuer.callsTo('POST /v1/token/authorization-code');
  assert.deepEqual(Object.keys(redeem.body), ['code', 'code_verifier', 'redirect_uri']);
  assert.equal(redeem.body.redirect_uri, REDIRECT_URI);
  assert.equal(s256(redeem.body.code_verifier), new URL(start).searchParams.get('code_challenge'));
  assert.equal(ctx.auth.session().status, 'authenticated');
  assert.equal(ctx.browser.location.href, REDIRECT_URI);
  assert.equal(ctx.browser.localStorage.length, 0, 'transaction deleted');
  assert.equal(ctx.tokens.length, 1);
});

test('audience is sent when configured', async () => {
  const ctx = setup({ audience: ISSUER + '/api' });
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  await ctx.auth.handleRedirect(callbackUrl({ code, state, iss: ISSUER }));
  assert.equal(ctx.issuer.callsTo('POST /v1/token/authorization-code')[0].body.audience, ISSUER + '/api');
});

test('replaceState strips code, state and iss synchronously, before the first fetch resolves', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  ctx.browser.location.href = callbackUrl({ code, state, iss: ISSUER, keep: '1' });
  const fetchCalls = [];
  const realFetch = ctx.issuer.fetch;
  const order = ctx.browser.events;
  const auth2 = setup({ browser: ctx.browser, clock: ctx.clock, issuer: ctx.issuer, fetch: async (url, init) => {
    order.push('fetch');
    fetchCalls.push(url);
    const r = await realFetch(url, init);
    order.push('fetch resolved');
    return r;
  } }).auth;
  const pending = auth2.restore();
  // Nothing has been awaited yet: this line is "app code" running right after the call.
  // The request may have been started, but the URL was cleaned first and nothing resolved.
  assert.deepEqual(order.filter((e) => e !== 'fetch'), ['replaceState']);
  assert.equal(order[0], 'replaceState');
  assert.equal(ctx.browser.location.href, REDIRECT_URI + '?keep=1');
  await pending;
  assert.deepEqual(order, ['replaceState', 'fetch', 'fetch resolved']);
  assert.equal(auth2.session().status, 'authenticated');
});

test('state is single use: a replayed callback is state_mismatch and posts nothing', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  const url = callbackUrl({ code, state, iss: ISSUER });
  await ctx.auth.handleRedirect(url);
  await assert.rejects(ctx.auth.handleRedirect(url), { name: 'AxiomAuthError', code: 'state_mismatch', status: 0 });
  assert.equal(ctx.issuer.callsTo('POST /v1/token/authorization-code').length, 1);
});

test('an expired transaction (15 minutes) is state_mismatch', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  ctx.clock.set(ctx.clock.now() + 15 * 60 * 1000);
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ code, state, iss: ISSUER })), { code: 'state_mismatch' });
  assert.equal(ctx.issuer.calls.length, 0);
});

test('an unknown state is state_mismatch and the URL is still stripped', async () => {
  const ctx = setup();
  await startHosted(ctx);
  ctx.browser.location.href = callbackUrl({ code: 'axc1_x', state: 'not-our-state-value-000000000000000000000000', iss: ISSUER });
  await assert.rejects(ctx.auth.handleRedirect(), { code: 'state_mismatch' });
  assert.equal(ctx.browser.location.href, REDIRECT_URI);
  assert.equal(ctx.issuer.calls.length, 0);
  assert.equal(ctx.browser.localStorage.length, 1, 'the real transaction is untouched');
});

test('issuer mix-up: iss differing from the configured issuer is refused and burns the transaction', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  const other = 'https://auth.axiomcore.dev/11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333';
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ code, state, iss: other })), { code: 'invalid_grant' });
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ code, state })), { code: 'state_mismatch' });
  assert.equal(ctx.issuer.calls.length, 0);
  assert.equal(ctx.auth.session().status, 'unknown');
});

test('issuer mix-up: missing iss is refused', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ code, state })), { code: 'invalid_grant' });
  assert.equal(ctx.issuer.calls.length, 0);
});

test('a transaction written for another issuer or redirect URI is not used', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const { code, state } = ctx.issuer.grantFor(start);
  const key = 'axiom-auth:tx:' + state;
  const tx = JSON.parse(ctx.browser.localStorage.getItem(key));
  ctx.browser.localStorage.setItem(key, JSON.stringify({ ...tx, issuer: ISSUER + 'x' }));
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ code, state, iss: ISSUER })), { code: 'state_mismatch' });

  const start2 = await startHosted(ctx);
  const g2 = ctx.issuer.grantFor(start2);
  const key2 = 'axiom-auth:tx:' + g2.state;
  const tx2 = JSON.parse(ctx.browser.localStorage.getItem(key2));
  ctx.browser.localStorage.setItem(key2, JSON.stringify({ ...tx2, redirectUri: ORIGIN + '/other' }));
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ code: g2.code, state: g2.state, iss: ISSUER })), { code: 'state_mismatch' });
  assert.equal(ctx.issuer.calls.length, 0);
});

test('redirect error outcomes surface as AxiomAuthError with the outcome name', async () => {
  for (const outcome of ['access_denied', 'provider_error', 'temporarily_unavailable', 'account_link_required', 'signup_disabled', 'user_disabled', 'quota', 'method_disabled', 'invalid_request']) {
    const ctx = setup();
    const start = await startHosted(ctx);
    const state = new URL(start).searchParams.get('state');
    const url = callbackUrl({ error: outcome, error_code: 'AXAUTH_' + outcome.toUpperCase(), state, iss: ISSUER });
    const err = await ctx.auth.handleRedirect(url).catch((e) => e);
    assert.equal(err.name, 'AxiomAuthError');
    assert.equal(err.code, outcome);
    assert.equal(err.message, outcome);
    assert.equal(ctx.issuer.calls.length, 0);
  }
  const ctx = setup();
  const start = await startHosted(ctx);
  const state = new URL(start).searchParams.get('state');
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ error: 'Something <b>free text</b>', state, iss: ISSUER })), { code: 'unavailable' });
  await assert.rejects(ctx.auth.handleRedirect(callbackUrl({ error: 'access_denied', state: 'forged', iss: ISSUER })), { code: 'state_mismatch' });
});

test('non-callback URLs are not handled', async () => {
  const ctx = setup();
  assert.deepEqual(await ctx.auth.handleRedirect(ORIGIN + '/orders?code=1&state=2'), { handled: false });
  assert.deepEqual(await ctx.auth.handleRedirect(REDIRECT_URI), { handled: false });
  assert.deepEqual(await ctx.auth.handleRedirect('https://evil.example/auth/callback?code=1&state=2'), { handled: false });
  assert.equal(ctx.browser.history.calls.length, 0);
});

test('a magic link opened in a new tab of the same browser completes', async () => {
  const clock = makeClock();
  const sharedLocal = new FakeStorage();
  const tab1 = setup({ clock, browser: makeBrowser({ href: ORIGIN + '/login', localStorage: sharedLocal }) });
  assert.deepEqual(await tab1.auth.requestMagicLink('jo@example.com', { returnTo: '/orders' }), { sent: true });
  const [sent] = tab1.issuer.linkRequests;
  assert.deepEqual(Object.keys(tab1.issuer.callsTo('POST /v1/email/link')[0].body), ['email', 'redirect_uri', 'state', 'code_challenge', 'code_challenge_method']);
  assert.equal(sent.redirect_uri, REDIRECT_URI);
  assert.equal(sent.code_challenge_method, 'S256');

  // The mail links to <redirect_uri>#axiom_link=<token>&state=<state>; opened in a new tab.
  const href = `${REDIRECT_URI}#axiom_link=${sent.token}&state=${sent.state}`;
  const tab2Browser = makeBrowser({ href, localStorage: sharedLocal });
  const tab2 = setup({ clock, issuer: tab1.issuer, browser: tab2Browser });
  const pending = tab2.auth.restore();
  assert.equal(tab2Browser.location.href, REDIRECT_URI, 'fragment stripped before any await');
  const session = await pending;
  assert.equal(session.status, 'authenticated');
  const [verify] = tab1.issuer.callsTo('POST /v1/email/link/verify');
  assert.deepEqual(Object.keys(verify.body), ['token', 'code_verifier']);
  assert.equal(s256(verify.body.code_verifier), sent.code_challenge);
  assert.equal(sharedLocal.length, 0);
  assert.equal(tab1.auth.session().status, 'unknown', 'the first tab is unaffected');

  // handleRedirect called directly reports returnTo.
  await tab1.auth.requestMagicLink('jo@example.com', { returnTo: '/orders' });
  const second = tab1.issuer.linkRequests[1];
  const tab3 = setup({ clock, issuer: tab1.issuer, browser: makeBrowser({ localStorage: sharedLocal }) });
  assert.deepEqual(await tab3.auth.handleRedirect(`${REDIRECT_URI}#axiom_link=${second.token}&state=${second.state}`), { handled: true, returnTo: '/orders' });
});

test('a magic link with a provider state (kind mismatch) is refused', async () => {
  const ctx = setup();
  const start = await startHosted(ctx);
  const state = new URL(start).searchParams.get('state');
  await assert.rejects(ctx.auth.handleRedirect(`${REDIRECT_URI}#axiom_link=axl1_x&state=${state}`), { code: 'state_mismatch' });
  assert.equal(ctx.issuer.calls.length, 0);
});

test('restore() on the callback path rejects with the redirect error; a second restore() continues', async () => {
  const ctx = setup();
  ctx.browser.location.href = callbackUrl({ code: 'axc1_x', state: 'nope', iss: ISSUER });
  await assert.rejects(ctx.auth.restore(), { code: 'state_mismatch' });
  const s = await ctx.auth.restore();
  assert.equal(s.status, 'anonymous');
});

test('password reset: the #axiom_reset token stays in memory for confirmPasswordReset', async () => {
  const ctx = setup();
  ctx.browser.location.href = REDIRECT_URI + '#axiom_reset=axp1_reset';
  const pending = ctx.auth.handleRedirect();
  assert.equal(ctx.browser.location.href, REDIRECT_URI);
  assert.deepEqual(await pending, { handled: true });
  assert.equal(ctx.browser.localStorage.length + ctx.browser.sessionStorage.length, 0);
  assert.ok(!JSON.stringify(ctx.auth).includes('axp1_reset'));
  await ctx.auth.confirmPasswordReset('a long new password');
  const [confirm] = ctx.issuer.callsTo('POST /v1/password/reset/confirm');
  assert.deepEqual(confirm.body, { token: 'axp1_reset', new_password: 'a long new password' });
  await assert.rejects(ctx.auth.confirmPasswordReset('again'), { code: 'invalid_code', status: 0 });
  assert.equal(ctx.issuer.callsTo('POST /v1/password/reset/confirm').length, 1);
});

test('password reset: weak_password keeps the token for a retry, invalid_code drops it', async () => {
  const ctx = setup();
  let n = 0;
  ctx.issuer.on('POST /v1/password/reset/confirm', () => (++n === 1 ? ctx.issuer.error(400, 'AXAUTH_WEAK_PASSWORD') : ctx.issuer.error(400, 'AXAUTH_INVALID_CODE')));
  await ctx.auth.handleRedirect(REDIRECT_URI + '#axiom_reset=axp1_reset');
  await assert.rejects(ctx.auth.confirmPasswordReset('short'), { code: 'weak_password', status: 400 });
  await assert.rejects(ctx.auth.confirmPasswordReset('longer password'), { code: 'invalid_code', status: 400 });
  await assert.rejects(ctx.auth.confirmPasswordReset('longer password'), { code: 'invalid_code', status: 0 });
  assert.equal(n, 2);
});

test('requestPasswordReset sends the configured redirect_uri', async () => {
  const ctx = setup();
  assert.deepEqual(await ctx.auth.requestPasswordReset('jo@example.com'), { sent: true });
  assert.deepEqual(ctx.issuer.callsTo('POST /v1/password/reset')[0].body, { email: 'jo@example.com', redirect_uri: REDIRECT_URI });
});
