import test from 'node:test';
import assert from 'node:assert/strict';
import { ISSUER, ORIGIN, REDIRECT_URI, flush, setup } from './helpers.mjs';

// Runs a full hosted sign-in with `returnTo` and reports what the transaction stored and
// what handleRedirect returned.
async function roundTrip(returnTo) {
  const ctx = setup();
  ctx.auth.signInHosted({ returnTo });
  await flush();
  const start = ctx.browser.location.assigned[0];
  const { code, state } = ctx.issuer.grantFor(start);
  const stored = JSON.parse(ctx.browser.localStorage.getItem('axiom-auth:tx:' + state)).returnTo;
  const u = new URL(REDIRECT_URI);
  u.searchParams.set('code', code);
  u.searchParams.set('state', state);
  u.searchParams.set('iss', ISSUER);
  const result = await ctx.auth.handleRedirect(u.href);
  return { stored, result };
}

const NEGATIVE = [
  ['protocol-relative', '//evil.example'],
  ['backslash after slash', '/\\evil.example'],
  ['absolute URL', 'https://evil.example'],
  ['javascript: scheme', 'javascript:alert(1)'],
  ['tab character', '/orders\tx'],
  ['tab used to hide a second slash', '/\t/evil.example'],
  ['newline', '/orders\nx'],
  ['DEL', '/orders\u007f'],
  ['NUL', '/orders\u0000'],
  ['backslash later', '/orders\\..\\x'],
  ['relative path', 'orders'],
  ['empty', ''],
  ['triple slash', '///evil.example'],
];

for (const [name, value] of NEGATIVE) {
  test(`returnTo refused: ${name}`, async () => {
    const { stored, result } = await roundTrip(value);
    assert.equal(stored, null);
    assert.deepEqual(result, { handled: true }, 'no returnTo: the app uses its signed_in route');
  });
}

test('returnTo /%2F%2Fevil.example resolves on-origin, so it is kept as a same-origin path', async () => {
  const value = '/%2F%2Fevil.example';
  assert.equal(new URL(value, ORIGIN).origin, ORIGIN);
  const { stored, result } = await roundTrip(value);
  assert.equal(stored, value);
  assert.equal(result.returnTo, value);
  assert.equal(new URL(result.returnTo, ORIGIN).origin, ORIGIN);
});

test('returnTo accepted: a same-origin path with query and fragment', async () => {
  const { result } = await roundTrip('/orders/42?tab=open#top');
  assert.equal(result.returnTo, '/orders/42?tab=open#top');
});

test('returnTo is validated again at completion (a tampered transaction is refused)', async () => {
  const ctx = setup();
  ctx.auth.signInHosted({ returnTo: '/fine' });
  await flush();
  const { code, state } = ctx.issuer.grantFor(ctx.browser.location.assigned[0]);
  const key = 'axiom-auth:tx:' + state;
  const tx = JSON.parse(ctx.browser.localStorage.getItem(key));
  ctx.browser.localStorage.setItem(key, JSON.stringify({ ...tx, returnTo: '//evil.example' }));
  const u = new URL(REDIRECT_URI);
  u.searchParams.set('code', code);
  u.searchParams.set('state', state);
  u.searchParams.set('iss', ISSUER);
  assert.deepEqual(await ctx.auth.handleRedirect(u.href), { handled: true });
});

test('signOut redirect keeps only a valid returnTo in sessionStorage', async () => {
  for (const [value, expected] of [['/bye', '/bye'], ['//evil.example', null], ['javascript:alert(1)', null], ['/a\tb', null]]) {
    const ctx = setup();
    await ctx.auth.signOut({ redirect: true, returnTo: value });
    assert.equal(ctx.browser.sessionStorage.getItem('axiom-auth:return'), expected);
  }
});
