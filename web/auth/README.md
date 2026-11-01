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

## Two-step verification, passkeys and step-up (auth-advanced/v1 17.1, 0.2.0)

- A first-factor call (password, email code, magic link, sign-up verification, invitation,
  redirect completion) that needs a second factor rejects with `mfa_required` (or
  `mfa_enrollment_required`). `mfaChallenge()` then lists the usable factors; the sealed
  ticket stays inside the client and is never in an error, the session, storage or JSON.
  Complete with `verifyMfa(factorId, code)`, `verifyRecoveryCode(code)`,
  `sendSmsCode(factorId)` then `verifyMfa`, or `verifyMfaWithPasskey()`. The ticket expires
  after 300 seconds; a new sign-in attempt or `signOut()` drops it.
- Redirect completions (`error=mfa_required&mfa_ticket=...`) are stripped from the URL before
  app code runs and bound to the PKCE verifier of the flow. The URL carries no factor list,
  so `mfaChallenge().factors` is empty there: offer the passkey and the recovery code.
- Under `mfa_policy = required` a user without a factor enrolls before any session:
  `enrollTotp(label)` and `confirmTotp(id, code)` (or `registerPasskey(label)`) use the
  enroll ticket and finish the sign-in.
- `signInWithPasskey()` and `registerPasskey()` run WebAuthn on the application origin
  (`webauthn_origins`, RP ID `webauthn_rp_id`). Failures are `webauthn`.
- `stepUp({ method, password | code, acr?, factorId? })` reauthenticates the current session
  (`POST /v1/reauthenticate`) and rotates its tokens; it never runs beside a refresh.
- Sensitive values: TOTP secrets, `otpauth://` URIs and recovery codes are returned to the
  caller once and never kept. Show them only in trusted UI memory (a QR code or a reveal),
  never in logs, analytics, storage or URLs.

## Runtime refusals (branches-v1 B10)

`authorizedFetch(input, init)` adds the bearer only to URLs on the page's own origin or an
exact origin listed in `apiOrigins` (for example `apiOrigins: ['https://api.example.com']`);
any other URL is fetched as is, without the token and without a retry. When an Acore runtime answers
`401 authorization_changed` (the environment's authorization generation moved past the
token), it refreshes once and retries once with the new token. Streamed bodies are not
replayed. `401 step_up_required` is returned as is: `runtimeAuthRefusal(await res.text())`
gives `{code, acr, maxAge}` (works cross-origin), `parseStepUpChallenge(res)` reads the
RFC 9470 header where it is exposed; then call `stepUp`.

Build and test (Node 24 or later; `stripTypeScriptTypes` from `node:module`):

```sh
npm run build    # dist/index.js and dist/index.d.ts, deterministic
npm run check    # fails if dist/ is stale
npm test         # node --test
```
