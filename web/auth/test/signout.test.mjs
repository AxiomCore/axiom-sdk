import test from 'node:test';
import assert from 'node:assert/strict';
import { sessionStorageAdapter } from '../dist/index.js';
import { FakeStorage, ISSUER, LOGOUT_URI, hostForwarder, setup } from './helpers.mjs';

const KEY = 'axiom-auth:refresh:' + ISSUER;

async function signedIn(opts = {}) {
  const ctx = setup(opts);
  await ctx.auth.signInWithPassword('jo@example.com', 'correct horse battery');
  return ctx;
}

test('signOut posts the refresh token once; a second call posts nothing', async () => {
  const storage = sessionStorageAdapter(new FakeStorage());
  const ctx = await signedIn({ storage });
  const refreshToken = ctx.issuer.issuedRefresh[0];
  const forwarded = hostForwarder(ctx.auth);
  const s = await ctx.auth.signOut();
  assert.deepEqual(s, { id: '', status: 'anonymous', principal: null });
  const posts = ctx.issuer.callsTo('POST /v1/logout');
  assert.equal(posts.length, 1);
  assert.deepEqual(posts[0].body, { refresh_token: refreshToken });
  assert.equal(ctx.tokens.at(-1), null);
  assert.equal(await storage.get(KEY), null);
  assert.equal(ctx.clock.pending().length, 0);
  assert.equal(forwarded.length, 1);
  assert.equal(forwarded[0].status, 'anonymous');

  const tokensBefore = ctx.tokens.length;
  await ctx.auth.signOut();
  assert.equal(ctx.issuer.calls.filter((c) => c.route.includes('logout')).length, 1);
  assert.equal(ctx.tokens.length, tokensBefore + 1, 'onTokens(null) is still called');
  assert.equal(ctx.tokens.at(-1), null);
  assert.equal(ctx.auth.session().status, 'anonymous');
});

test('two concurrent signOut calls post once', async () => {
  const ctx = await signedIn();
  await Promise.all([ctx.auth.signOut(), ctx.auth.signOut()]);
  assert.equal(ctx.issuer.callsTo('POST /v1/logout').length, 1);
});

test('signOut during an in-flight refresh posts the rotated token', async () => {
  const ctx = await signedIn();
  ctx.clock.set(ctx.clock.now() + 800 * 1000);
  const refreshing = ctx.auth.refresh();
  await ctx.auth.signOut();
  await refreshing;
  const [post] = ctx.issuer.callsTo('POST /v1/logout');
  assert.equal(post.body.refresh_token, ctx.issuer.issuedRefresh.at(-1));
  assert.equal(ctx.auth.session().status, 'anonymous');
});

test('signOut({everywhere}) posts to /v1/logout-all', async () => {
  const ctx = await signedIn();
  await ctx.auth.signOut({ everywhere: true });
  assert.equal(ctx.issuer.callsTo('POST /v1/logout-all').length, 1);
  assert.equal(ctx.issuer.callsTo('POST /v1/logout').length, 0);
});

test('signOut retries once on a network failure, never on an HTTP error, and always clears locally', async () => {
  const ctx = await signedIn();
  let n = 0;
  ctx.issuer.on('POST /v1/logout', () => { n++; throw new TypeError('Failed to fetch'); });
  const s = await ctx.auth.signOut();
  assert.equal(n, 2);
  assert.equal(s.status, 'anonymous');
  assert.equal(ctx.tokens.at(-1), null);

  const ctx2 = await signedIn();
  ctx2.issuer.on('POST /v1/logout', (_b, _c, iss) => iss.error(503, 'AXAUTH_UNAVAILABLE', { 'Retry-After': '1' }));
  assert.equal((await ctx2.auth.signOut()).status, 'anonymous');
  assert.equal(ctx2.issuer.callsTo('POST /v1/logout').length, 1);
});

test('signOut({redirect}) navigates to the logout redirect with logoutUri and a random state', async () => {
  const ctx = await signedIn();
  await ctx.auth.signOut({ redirect: true, returnTo: '/goodbye' });
  assert.equal(ctx.issuer.callsTo('POST /v1/logout').length, 1);
  const [nav] = ctx.browser.location.assigned;
  const u = new URL(nav);
  assert.equal(u.origin + u.pathname, ISSUER + '/v1/logout');
  assert.deepEqual(Array.from(u.searchParams.keys()), ['post_logout_redirect_uri', 'state']);
  assert.equal(u.searchParams.get('post_logout_redirect_uri'), LOGOUT_URI);
  assert.match(u.searchParams.get('state'), /^[A-Za-z0-9_-]{43}$/);
  assert.equal(ctx.browser.sessionStorage.getItem('axiom-auth:return'), '/goodbye');
});

test('signOut({redirect}) without logoutUri does not navigate', async () => {
  const ctx = await signedIn({ logoutUri: undefined });
  await ctx.auth.signOut({ redirect: true });
  assert.equal(ctx.browser.location.assigned.length, 0);
});

test('signOut with no session posts nothing', async () => {
  const ctx = setup();
  await ctx.auth.restore();
  await ctx.auth.signOut();
  assert.equal(ctx.issuer.calls.length, 0);
  assert.deepEqual(ctx.tokens, [null]);
});
