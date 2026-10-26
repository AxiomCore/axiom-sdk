import test from 'node:test';
import assert from 'node:assert/strict';
import { ISSUER, REDIRECT_URI, flush, makeBrowser, makeClock, setup, s256 } from './helpers.mjs';

// RFC 7636 Appendix B: the 32 octets behind the example verifier.
const RFC_OCTETS = [116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186,
  22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121];
const RFC_VERIFIER = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
const RFC_CHALLENGE = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';

const B64URL43 = /^[A-Za-z0-9_-]{43}$/;

function txEntries(browser) {
  return browser.localStorage.keys().filter((k) => k.startsWith('axiom-auth:tx:')).map((k) => [k, JSON.parse(browser.localStorage.getItem(k))]);
}

test('PKCE S256 matches the RFC 7636 Appendix B vector', async () => {
  const browser = makeBrowser();
  let call = 0;
  browser.crypto = {
    subtle: globalThis.crypto.subtle,
    getRandomValues(array) {
      call++;
      if (array instanceof Uint8Array && array.length === 32) {
        if (call === 2) array.set(RFC_OCTETS); // state first, verifier second
        else array.fill(call);
        return array;
      }
      return globalThis.crypto.getRandomValues(array);
    },
  };
  const { auth } = setup({ browser });
  auth.signInHosted();
  await flush();
  const [[, tx]] = txEntries(browser);
  assert.equal(tx.verifier, RFC_VERIFIER);
  const start = new URL(browser.location.assigned[0]);
  assert.equal(start.searchParams.get('code_challenge'), RFC_CHALLENGE);
  assert.equal(start.searchParams.get('code_challenge_method'), 'S256');
  assert.equal(s256(RFC_VERIFIER), RFC_CHALLENGE);
});

test('state and verifier are 32 random bytes (43 base64url characters) and the start URLs are frozen', async () => {
  const { auth, browser, clock } = setup();
  auth.signInWithProvider('google', { returnTo: '/orders' });
  await flush();
  auth.signInHosted();
  await flush();
  const [provider, hosted] = browser.location.assigned.map((u) => new URL(u));
  assert.equal(provider.origin + provider.pathname, ISSUER + '/v1/providers/google/start');
  assert.equal(hosted.origin + hosted.pathname, ISSUER + '/sign-in');
  for (const u of [provider, hosted]) {
    assert.deepEqual(Array.from(u.searchParams.keys()), ['redirect_uri', 'state', 'code_challenge', 'code_challenge_method']);
    assert.equal(u.searchParams.get('redirect_uri'), REDIRECT_URI);
    assert.match(u.searchParams.get('state'), B64URL43);
    assert.match(u.searchParams.get('code_challenge'), B64URL43);
  }
  const entries = txEntries(browser);
  assert.equal(entries.length, 2);
  const tx = entries.map(([, t]) => t).find((t) => t.kind === 'provider');
  assert.deepEqual(Object.keys(tx), ['v', 'state', 'verifier', 'kind', 'provider', 'issuer', 'audience', 'redirectUri', 'returnTo', 'createdAt']);
  assert.equal(tx.v, 1);
  assert.equal(tx.provider, 'google');
  assert.equal(tx.issuer, ISSUER);
  assert.equal(tx.redirectUri, REDIRECT_URI);
  assert.equal(tx.returnTo, '/orders');
  assert.equal(tx.createdAt, clock.now());
  assert.match(tx.state, B64URL43);
  assert.match(tx.verifier, B64URL43);
  assert.notEqual(tx.state, tx.verifier);
  assert.equal(s256(tx.verifier), provider.searchParams.get('code_challenge'));
  for (const [key, t] of entries) assert.equal(key, 'axiom-auth:tx:' + t.state);
});

test('at most 4 pending transactions; the oldest is dropped', async () => {
  const { auth, browser, clock } = setup();
  for (let i = 0; i < 6; i++) {
    auth.signInHosted();
    await flush();
    clock.set(clock.now() + 1000);
  }
  const entries = txEntries(browser);
  assert.equal(entries.length, 4);
  const states = browser.location.assigned.map((u) => new URL(u).searchParams.get('state'));
  assert.deepEqual(entries.map(([, t]) => t.state).sort(), states.slice(2).sort());
});

test('expired transactions are purged at start and at every restore()', async () => {
  const clock = makeClock();
  const browser = makeBrowser();
  const first = setup({ browser, clock });
  first.auth.signInHosted();
  await flush();
  browser.localStorage.setItem('axiom-auth:tx:garbage', '{not json');
  assert.equal(browser.localStorage.length, 2);

  clock.set(clock.now() + 15 * 60 * 1000);
  setup({ browser, clock }); // start of a new client
  assert.equal(browser.localStorage.length, 0);

  first.auth.signInHosted();
  await flush();
  assert.equal(browser.localStorage.length, 1);
  clock.set(clock.now() + 15 * 60 * 1000 + 1);
  await first.auth.restore();
  assert.equal(browser.localStorage.length, 0);
});

test('a redirect flow without redirectUri is refused before any navigation', async () => {
  const { auth, browser, issuer } = setup({ redirectUri: undefined });
  await assert.rejects(auth.signInHosted(), { name: 'AxiomAuthError', code: 'redirect_uri' });
  await assert.rejects(auth.requestMagicLink('jo@example.com'), { code: 'redirect_uri' });
  assert.equal(browser.location.assigned.length, 0);
  assert.equal(issuer.calls.length, 0);
});
