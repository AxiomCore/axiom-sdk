import test from 'node:test';
import assert from 'node:assert/strict';
import { sessionStorageAdapter } from '../dist/index.js';
import { FakeIssuer, FakeStorage, ISSUER, flush, hostForwarder, makeBrowser, makeClock, makeLocks, makeSharedAdapter, setup } from './helpers.mjs';

const REFRESH = 'POST /v1/token/refresh';
const KEY = 'axiom-auth:refresh:' + ISSUER;

async function signedIn(opts = {}) {
  const ctx = setup(opts);
  await ctx.auth.signInWithPassword('jo@example.com', 'correct horse battery');
  return ctx;
}

test('20 concurrent callers make one refresh POST', async () => {
  const ctx = await signedIn();
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  const results = await Promise.all(Array.from({ length: 20 }, () => ctx.auth.refresh()));
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 1);
  assert.equal(ctx.issuer.rotations, 1);
  for (const s of results) assert.equal(s, results[0]);
  assert.equal(results[0].status, 'authenticated');
  // authorizationHeader() and user() join the same flight when due.
  ctx.clock.set(ctx.clock.now() + 850 * 1000);
  await Promise.all([ctx.auth.authorizationHeader(), ctx.auth.authorizationHeader(), ctx.auth.refresh(), ctx.auth.user()]);
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 2);
});

test('one proactive refresh rotates and forwards no session id or principal change', async () => {
  const ctx = await signedIn();
  const before = ctx.auth.session();
  const forwarded = hostForwarder(ctx.auth);
  const seen = [];
  ctx.auth.subscribe((s) => seen.push(s.status));
  const [at] = ctx.clock.pending();
  const delay = at - ctx.clock.now();
  assert.ok(delay >= 780 * 1000 && delay <= 790 * 1000, `timer at iat + rotation interval + jitter, got ${delay}`);
  await ctx.clock.advance(791 * 1000);
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 1);
  assert.equal(ctx.issuer.rotations, 1);
  const after = ctx.auth.session();
  assert.equal(after.status, 'authenticated');
  assert.equal(after.id, before.id);
  assert.equal(after.principal, before.principal);
  assert.deepEqual(forwarded, []);
  assert.deepEqual(seen, ['refreshing', 'authenticated']);
  assert.equal(ctx.tokens.length, 2);
  assert.notEqual(ctx.tokens[1], ctx.tokens[0]);
  assert.equal(ctx.tokens[1], ctx.issuer.issuedAccess.at(-1), 'raw token, nothing added');
  assert.equal(ctx.clock.pending().length, 1, 'next timer armed');
});

test('a capped exp shortens the rotation interval (access TTL = exp - iat)', async () => {
  const ctx = setup();
  ctx.issuer.on('POST /v1/sign-in/password', (_b, _c, iss) => {
    const s = iss.createSession();
    s.accessExp = ctx.clock.now() + 200 * 1000; // capped by an assignment's valid_until
    return { body: iss.tokens(s) };
  });
  await ctx.auth.signInWithPassword('jo@example.com', 'pw');
  const delay = ctx.clock.pending()[0] - ctx.clock.now();
  // TTL 200 s, rotation interval 80 s: min(exp - 60 s = 140 s, iat + 80 s) = 80 s, plus jitter.
  assert.ok(delay >= 80 * 1000 && delay <= 90 * 1000, `got ${delay}`);
});

test('no proactive refresh while hidden; on visible, refresh only when within 60 s of exp', async () => {
  const ctx = await signedIn();
  ctx.browser.document.setVisibility('hidden');
  assert.equal(ctx.clock.pending().length, 0);
  await ctx.clock.advance(820 * 1000);
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 0);
  ctx.browser.document.setVisibility('visible');
  await flush();
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 0, 'not yet within 60 s of exp: rescheduled');
  assert.equal(ctx.clock.pending().length, 1);

  ctx.browser.document.setVisibility('hidden');
  ctx.clock.set(ctx.clock.now() + 50 * 1000); // 870 s: within 60 s of exp (900 s)
  ctx.browser.document.setVisibility('visible');
  await flush();
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 1);
  assert.equal(ctx.auth.session().status, 'authenticated');
});

test('early refresh (same refresh token) is accepted silently and keeps the rotation clock', async () => {
  const ctx = await signedIn({ storage: sessionStorageAdapter(new FakeStorage()) });
  const firstRefresh = ctx.issuer.issuedRefresh[0];
  ctx.clock.set(ctx.clock.now() + 100 * 1000);
  const s = await ctx.auth.refresh();
  assert.equal(s.status, 'authenticated');
  assert.equal(ctx.issuer.earlyRefreshes, 1);
  assert.equal(ctx.issuer.rotations, 0);
  assert.equal(ctx.tokens.length, 2);
  const delay = ctx.clock.pending()[0] - ctx.clock.now();
  assert.ok(delay >= 680 * 1000 && delay <= 690 * 1000, `still anchored at the sign-in, got ${delay}`);
  await ctx.clock.advance(691 * 1000);
  assert.equal(ctx.issuer.rotations, 1);
  assert.equal(ctx.issuer.supersededPresented, 0);
  assert.notEqual(ctx.issuer.callsTo(REFRESH)[1].body.refresh_token, undefined);
  assert.equal(ctx.issuer.callsTo(REFRESH)[1].body.refresh_token, firstRefresh);
});

test('refresh_too_soon keeps the token and backs off to the next interval', async () => {
  const ctx = await signedIn();
  ctx.issuer.on(REFRESH, (_b, _c, iss) => iss.error(429, 'AXAUTH_REFRESH_TOO_SOON', { 'Retry-After': '5' }));
  const tokensBefore = ctx.tokens.length;
  await assert.rejects(ctx.auth.refresh(), { code: 'refresh_too_soon', status: 429 });
  assert.equal(ctx.auth.session().status, 'authenticated');
  assert.equal(ctx.tokens.length, tokensBefore);
  assert.ok(await ctx.auth.authorizationHeader());
  const delay = ctx.clock.pending()[0] - ctx.clock.now();
  assert.ok(delay >= 720 * 1000 && delay <= 790 * 1000, `next interval, got ${delay}`);
});

for (const [code, status] of [['AXAUTH_UNAVAILABLE', 503], ['AXAUTH_RATE_LIMITED', 429]]) {
  test(`${code} keeps the token and retries after Retry-After`, async () => {
    const ctx = await signedIn();
    const forwarded = hostForwarder(ctx.auth);
    let fail = true;
    ctx.issuer.on(REFRESH, (_b, _c, iss) => (fail ? iss.error(status, code, { 'Retry-After': '30' }) : undefined));
    ctx.clock.set(ctx.clock.now() + 790 * 1000);
    const err = await ctx.auth.refresh().catch((e) => e);
    assert.equal(err.code, code.slice(7).toLowerCase());
    assert.equal(err.status, status);
    assert.equal(err.retryAfterSeconds, 30);
    assert.equal(ctx.auth.session().status, 'authenticated');
    // Inside the window the issuer is not called again.
    await assert.rejects(ctx.auth.refresh(), (e) => e.code === err.code && e.retryAfterSeconds === 30);
    assert.equal(ctx.issuer.callsTo(REFRESH).length, 1);
    fail = false;
    await ctx.clock.advance(29 * 1000);
    assert.equal(ctx.issuer.callsTo(REFRESH).length, 1);
    await ctx.clock.advance(1000);
    assert.equal(ctx.issuer.callsTo(REFRESH).length, 2);
    assert.equal(ctx.issuer.rotations, 1);
    assert.equal(ctx.auth.session().status, 'authenticated');
    assert.deepEqual(forwarded, []);
  });
}

test('network failure during refresh is unavailable with the default retry delay', async () => {
  const ctx = await signedIn();
  ctx.issuer.on(REFRESH, () => { throw new TypeError('Failed to fetch'); });
  await assert.rejects(ctx.auth.refresh(), (e) => e.code === 'unavailable' && e.status === 0 && e.retryAfterSeconds === undefined);
  assert.equal(ctx.auth.session().status, 'authenticated');
  assert.equal(ctx.clock.pending()[0] - ctx.clock.now(), 30 * 1000);
});

test('invalid_refresh clears tokens and the adapter and sets expired', async () => {
  const storage = sessionStorageAdapter(new FakeStorage());
  const ctx = await signedIn({ storage });
  assert.ok(await storage.get(KEY));
  const forwarded = hostForwarder(ctx.auth);
  ctx.issuer.on(REFRESH, (_b, _c, iss) => iss.error(401, 'AXAUTH_INVALID_REFRESH'));
  await assert.rejects(ctx.auth.refresh(), { code: 'invalid_refresh', status: 401 });
  assert.equal(await storage.get(KEY), null);
  assert.deepEqual(ctx.auth.session(), { id: '', status: 'expired', principal: null });
  assert.equal(ctx.tokens.at(-1), null);
  assert.equal(await ctx.auth.authorizationHeader(), null);
  assert.equal(ctx.clock.pending().length, 0);
  assert.equal(forwarded.length, 1);
  assert.equal(forwarded[0].status, 'expired');
  await assert.rejects(ctx.auth.refresh(), { code: 'invalid_refresh' });
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 1);
});

test('past refresh_expires_at: expired without calling the issuer', async () => {
  const storage = sessionStorageAdapter(new FakeStorage());
  const ctx = await signedIn({ storage, refreshLifetime: 600 });
  ctx.clock.set(ctx.clock.now() + 601 * 1000);
  await assert.rejects(ctx.auth.refresh(), { code: 'invalid_refresh', status: 0 });
  assert.equal(ctx.auth.session().status, 'expired');
  assert.equal(ctx.issuer.callsTo(REFRESH).length, 0);
  assert.equal(await storage.get(KEY), null);
});

test('restore(): adapter record refreshed; expired record not presented; memory default anonymous', async () => {
  const clock = makeClock();
  const browser = makeBrowser();
  const issuer = new FakeIssuer({ clock });
  const first = await signedIn({ clock, browser, issuer, storage: sessionStorageAdapter(browser.sessionStorage) });
  // A reload: a new client over the same tab storage.
  const reloaded = setup({ clock, browser, issuer, storage: sessionStorageAdapter(browser.sessionStorage) });
  const statuses = [];
  reloaded.auth.subscribe((s) => statuses.push(s.status));
  const s = await reloaded.auth.restore();
  assert.equal(s.status, 'authenticated');
  assert.equal(s.id, first.auth.session().id);
  assert.deepEqual(statuses, ['loading', 'authenticated']);
  assert.equal(issuer.callsTo(REFRESH).length, 1);

  clock.set(clock.now() + 8 * 24 * 3600 * 1000);
  const late = setup({ clock, browser, issuer, storage: sessionStorageAdapter(browser.sessionStorage) });
  assert.equal((await late.auth.restore()).status, 'expired');
  assert.equal(issuer.callsTo(REFRESH).length, 1);
  assert.equal(browser.sessionStorage.length, 0);

  const fresh = setup({ clock, issuer });
  assert.equal((await fresh.auth.restore()).status, 'anonymous');
  assert.equal(issuer.callsTo(REFRESH).length, 1);
});

test('restore() with the issuer unavailable reports error and retries after Retry-After', async () => {
  const clock = makeClock();
  const browser = makeBrowser();
  const issuer = new FakeIssuer({ clock });
  await signedIn({ clock, browser, issuer, storage: sessionStorageAdapter(browser.sessionStorage) });
  let fail = true;
  issuer.on(REFRESH, (_b, _c, iss) => (fail ? iss.error(503, 'AXAUTH_UNAVAILABLE', { 'Retry-After': '10' }) : undefined));
  const reloaded = setup({ clock, browser, issuer, storage: sessionStorageAdapter(browser.sessionStorage) });
  assert.equal((await reloaded.auth.restore()).status, 'error');
  fail = false;
  await reloaded.clock.advance(10 * 1000);
  assert.equal(reloaded.auth.session().status, 'authenticated');
});

test('Web Lock adoption never presents a superseded token (two tabs, shared adapter)', async () => {
  const clock = makeClock();
  const issuer = new FakeIssuer({ clock });
  const storage = makeSharedAdapter();
  const locks = makeLocks();
  const tabA = await signedIn({ clock, issuer, storage, browser: makeBrowser({ locks }) });
  const tabB = setup({ clock, issuer, storage, browser: makeBrowser({ locks }) });
  await tabB.auth.restore();
  assert.equal(tabB.auth.session().status, 'authenticated');

  // Sequential: A rotates, then B (holding the superseded token) refreshes.
  clock.set(clock.now() + 781 * 1000);
  await tabA.auth.refresh();
  assert.equal(issuer.rotations, 1);
  await tabB.auth.refresh();
  assert.equal(issuer.supersededPresented, 0);
  assert.equal(tabB.auth.session().status, 'authenticated');
  assert.equal(issuer.callsTo(REFRESH).at(-1).body.refresh_token, storage.map.get(KEY).refreshToken);

  // Concurrent: both proactive timers fire around the same time.
  await clock.advance(800 * 1000);
  assert.equal(issuer.supersededPresented, 0);
  assert.ok(issuer.rotations >= 2);
  assert.equal(tabA.auth.session().status, 'authenticated');
  assert.equal(tabB.auth.session().status, 'authenticated');
  for (const call of issuer.callsTo(REFRESH)) {
    const s = issuer.findByRefresh(call.body.refresh_token);
    assert.equal(s.ended, false);
  }
  assert.ok(locks.requests.every((n) => n === 'axiom-auth:' + ISSUER));
  assert.ok(locks.requests.length >= 4);
});

test('a shared record removed by another tab ends this tab without a POST', async () => {
  const clock = makeClock();
  const issuer = new FakeIssuer({ clock });
  const storage = makeSharedAdapter();
  const locks = makeLocks();
  const tabA = await signedIn({ clock, issuer, storage, browser: makeBrowser({ locks }) });
  const tabB = setup({ clock, issuer, storage, browser: makeBrowser({ locks }) });
  await tabB.auth.restore();
  const posts = issuer.callsTo(REFRESH).length;
  await tabA.auth.signOut();
  await assert.rejects(tabB.auth.refresh(), { code: 'invalid_refresh' });
  assert.equal(tabB.auth.session().status, 'expired');
  assert.equal(issuer.callsTo(REFRESH).length, posts);
});

test('selectTenant refreshes with tenant and the principal changes', async () => {
  const ctx = await signedIn();
  const forwarded = hostForwarder(ctx.auth);
  const s = await ctx.auth.selectTenant('org-1');
  assert.equal(ctx.issuer.callsTo(REFRESH)[0].body.tenant, 'org-1');
  assert.equal(s.principal.tenant, 'org-1');
  assert.equal(forwarded.length, 1);
  await ctx.auth.selectTenant(null);
  assert.equal('tenant' in ctx.issuer.callsTo(REFRESH)[1].body, false);
});
