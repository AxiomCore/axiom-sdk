# @axiomcore/auth-web

Browser client for Axiom project authentication (`auth-surfaces/v1`, "Web client"). No
dependencies; WebCrypto and `fetch`. The Acore web host vendors `dist/index.js` as
`web/acore-auth.js` and pins its SHA-256.

```js
import { createAxiomAuth, sessionStorageAdapter } from '@axiomcore/auth-web';

const auth = createAxiomAuth({
  issuer,                       // [auth.environments.<env>].issuer
  audience,                     // optional; sent only when set
  redirectUri,                  // redirectOrigin + callbackPath
  logoutUri,                    // optional; needed for signOut({ redirect: true })
  storage,                      // default memoryStorage(); or sessionStorageAdapter()
  onTokens: (token) => { /* raw access token, or null: set or clear it in the WASM store */ },
});

let landing;
try {
  landing = await auth.handleRedirect();   // { handled, returnTo? }; strips the URL synchronously
} catch (e) {
  // AxiomAuthError: state_mismatch, invalid_grant, a redirect outcome (access_denied, ...)
}
const session = await auth.restore();      // authenticated | anonymous | expired | error
if (landing?.handled) route(landing.returnTo ?? signedInRoute);
```

- `handleRedirect()` returns `{handled: false}` unless the URL has the origin and path of
  `redirectUri` and carries `code`, `error`, `#axiom_link` or `#axiom_reset`. It never
  navigates; `returnTo` is present only when it passed the same-origin rule.
- `restore()` also runs `handleRedirect()` on the callback URL (rejecting with its error;
  a second `restore()` then loads the stored session). It purges expired PKCE
  transactions and never rejects otherwise.
- Errors are `AxiomAuthError` with `code` (`AXAUTH_FOO_BAR` becomes `foo_bar`; unknown
  codes and network failures become `unavailable`), `status` (HTTP, or 0 for client-side
  and network outcomes) and `retryAfterSeconds`. The message is the code.
- `subscribe` notifies on every status change, including `refreshing`; the principal
  object is reused while its content is unchanged, so `s.principal !== last.principal`
  detects a real change.

Build and test (Node 24 or later; `stripTypeScriptTypes` from `node:module`):

```sh
npm run build    # dist/index.js and dist/index.d.ts, deterministic
npm run check    # fails if dist/ is stale
npm test         # node --test
```
