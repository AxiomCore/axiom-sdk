// @axiomcore/auth-web public declarations (auth-surfaces/v1 "Web client").
// The contract's API block, plus the additive optional members marked "Additive".

export type AuthStatus = 'unknown'|'loading'|'error'|'anonymous'|'authenticated'|'expired'|'refreshing';
export type Acr = 'aal1'|'aal2'|'phr';                     // auth-advanced/v1 7.1
export interface PublicPrincipal { subject: string; tenant: string|null; roles: string[]; permissions: string[] }
/** auth-advanced/v1 17.1: `acr` and `authTime` (epoch seconds) from the access token; `aal1` and 0 while signed out. */
export interface PublicSession { id: string; status: AuthStatus; principal: PublicPrincipal|null; acr: Acr; authTime: number }
/** Set after `mfa_required` or `mfa_enrollment_required`; the ticket stays private. Redirect completions carry no factor list (`factors` is empty). */
export interface MfaChallenge { factors: { id: string; type: 'totp'|'passkey'|'sms'; label: string }[]; recoveryCodes: boolean; enrollment?: { types: string[] } }
export interface Factor { id: string; type: 'totp'|'passkey'|'sms'; label: string; status: 'pending'|'active'; createdAt: string; lastUsedOn?: string }
/** Trusted UI memory only: show the secret or QR code once, never store or log it. */
export interface TotpEnrollment { factorId: string; secret: string; otpauthUri: string }
export type StepUpMethod = 'password'|'totp'|'sms'|'recovery'|'passkey';
export interface AuthUser { id: string; kind: 'password'|'external'; email?: string; emailVerified: boolean; hasPassword: boolean; providers: string[] }
export type AuthErrorCode = string;                      // the mechanical names; never free text
export class AxiomAuthError extends Error {              // message is the code
  readonly code: AuthErrorCode; readonly status: number; readonly retryAfterSeconds?: number;
  /** Additive: `status` is the HTTP status, 0 for client-side and network outcomes. */
  constructor(code: AuthErrorCode, status?: number, retryAfterSeconds?: number);
}
export interface RefreshRecord { refreshToken: string; refreshExpiresAt: string; issuer: string; audience: string; sessionId: string }
export interface AuthStorageAdapter {                    // holds only the refresh record
  get(key: string): Promise<RefreshRecord|null>;
  set(key: string, value: RefreshRecord): Promise<void>;
  remove(key: string): Promise<void>;
  readonly shared: boolean;                              // visible to other tabs: cross-tab lock required
}

/** Additive: the subset of the Web Storage API the client uses. */
export interface StorageLike {
  readonly length: number;
  key(index: number): string | null;
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

/**
 * Additive: the browser objects the client reads. Every member defaults to the one on
 * `globalThis`; tests inject fakes. The client never writes a property to this object.
 */
export interface AuthGlobals {
  location?: { readonly href: string; readonly origin: string; assign(url: string): void };
  history?: { readonly state: unknown; replaceState(state: unknown, unused: string, url?: string): void };
  localStorage?: StorageLike;
  sessionStorage?: StorageLike;
  navigator?: {
    readonly locks?: { request<T>(name: string, callback: () => Promise<T>): Promise<T> };
    /** WebAuthn on the application origin (passkeys). */
    readonly credentials?: { create(options: { publicKey: unknown }): Promise<unknown>; get(options: { publicKey: unknown; mediation?: string }): Promise<unknown> };
  };
  document?: { readonly visibilityState?: string; addEventListener?(type: string, listener: () => void): void };
  crypto?: { getRandomValues<T extends ArrayBufferView>(array: T): T; readonly subtle: { digest(algorithm: string, data: ArrayBufferView): Promise<ArrayBuffer> } };
}

export const memoryStorage: () => AuthStorageAdapter;            // default
/** Opt-in, per tab, survives reload. Additive: `target` defaults to `globalThis.sessionStorage`. */
/** Additive: `captchaToken` is sent as `captcha_token` where Turnstile gates a flow. A shared adapter requires `navigator.locks`. */
export const sessionStorageAdapter: (target?: StorageLike) => AuthStorageAdapter;

export interface AxiomAuthOptions {
  issuer: string; audience?: string; redirectUri?: string;       // redirectOrigin + callbackPath
  storage?: AuthStorageAdapter;
  onTokens?: (accessToken: string|null) => void;                 // transport sink only
  fetch?: typeof fetch; clock?: () => number;                    // clock: epoch milliseconds
  /** Additive: `[auth.environments.<env>].logoutUri`; required for `signOut({ redirect: true })` to navigate. */
  logoutUri?: string;
  /** Additive test seam: browser objects (default `globalThis`). */
  globalObject?: AuthGlobals;
  /** Additive: exact origins (https, or http on loopback) besides the page's own that `authorizedFetch` sends the bearer to; any other URL is fetched without it. */
  apiOrigins?: string[];
  /** Additive test seam: timer functions (default `globalThis.setTimeout` and `clearTimeout`). */
  setTimeout?: (callback: () => void, ms: number) => unknown;
  clearTimeout?: (handle: unknown) => void;
}
export interface AxiomAuth {
  session(): PublicSession; user(): Promise<AuthUser|null>;
  subscribe(listener: (s: PublicSession) => void): () => void;
  /**
   * Purges expired PKCE transactions; on the callback URL (origin and path of
   * `redirectUri` with `code`, `error`, `#axiom_link` or `#axiom_reset`) runs
   * `handleRedirect()` first and rejects with its error; otherwise loads the adapter
   * record and refreshes. Resolves with the session (`authenticated`, `anonymous`,
   * `expired`, or `error` with a retry scheduled).
   */
  restore(): Promise<PublicSession>;
  signUp(email: string, password: string, opts?: { captchaToken?: string }): Promise<{ status: 'signed_in'|'verification_sent'; challenge?: string; resendAfterSeconds?: number }>;
  verifySignUp(challenge: string, code: string): Promise<PublicSession>;
  signInWithPassword(email: string, password: string, opts?: { tenant?: string; captchaToken?: string }): Promise<PublicSession>;
  requestEmailCode(email: string, opts?: { captchaToken?: string }): Promise<{ challenge: string; resendAfterSeconds: number }>;
  verifyEmailCode(challenge: string, code: string): Promise<PublicSession>;
  requestMagicLink(email: string, opts?: { returnTo?: string; captchaToken?: string }): Promise<{ sent: true }>;
  signInWithProvider(provider: string, opts?: { returnTo?: string }): Promise<never>;
  signInHosted(opts?: { returnTo?: string; screen?: 'sign_in' | 'sign_up' }): Promise<never>;
  /**
   * `handled: false` when `url` (default `location.href`) is not a callback. Strips the
   * callback parameters with `history.replaceState` synchronously, before returning.
   * Does not navigate: `returnTo` is the validated path to route to, absent when the
   * app's signed_in route applies. Rejects with `AxiomAuthError` (`state_mismatch`,
   * `invalid_grant`, a redirect outcome name, or a mapped server code).
   */
  handleRedirect(url?: string): Promise<{ handled: boolean; returnTo?: string; invitation?: boolean }>;
  refresh(opts?: { tenant?: string }): Promise<PublicSession>;
  signOut(opts?: { everywhere?: boolean; redirect?: boolean; returnTo?: string }): Promise<PublicSession>;
  changePassword(current: string, next: string): Promise<void>;
  requestPasswordReset(email: string, opts?: { captchaToken?: string }): Promise<{ sent: true }>;
  confirmPasswordReset(password: string): Promise<void>;        // uses the captured #axiom_reset token
  /** Additive: accepts the invitation captured from `#axiom_invitation` (POST /v1/invitations/accept). */
  acceptInvitation(opts?: { password?: string; tenant?: string }): Promise<PublicSession>;
  selectTenant(tenant: string|null): Promise<PublicSession>;
  authorizationHeader(): Promise<string|null>;                  // non-Acore fetch; refreshes if due
  /**
   * Additive (branches-v1 B10): `fetch` with the bearer. On `401 authorization_changed` from an
   * Acore runtime (`WWW-Authenticate` or the body code) refreshes once and retries once with the
   * new token. Bodies that cannot be replayed (streams) are not retried. Other responses,
   * including `401 step_up_required`, are returned as they are: read them with
   * `runtimeAuthRefusal` or `parseStepUpChallenge` and call `stepUp`.
   */
  authorizedFetch(input: string|URL|Request, init?: RequestInit): Promise<Response>;
  /** Additive: what `JSON.stringify(auth)` shows; never a token. */
  toJSON(): { issuer: string; session: PublicSession };

  // auth-advanced/v1 17.1
  mfaChallenge(): MfaChallenge|null;                            // null when none or after 300 s
  verifyMfa(factorId: string, code: string): Promise<PublicSession>;
  verifyRecoveryCode(code: string): Promise<PublicSession>;
  sendSmsCode(factorId: string): Promise<{ resendAfterSeconds: number }>;
  verifyMfaWithPasskey(): Promise<PublicSession>;               // navigator.credentials.get on the app origin
  signInWithPasskey(opts?: { tenant?: string }): Promise<PublicSession>;
  /** Additive: `factorId` selects a TOTP or SMS factor; without it the user's one active factor of that type is used. */
  stepUp(opts: { acr?: Acr; method: StepUpMethod; password?: string; code?: string; factorId?: string }): Promise<PublicSession>;
  listFactors(): Promise<{ factors: Factor[]; recoveryCodesRemaining: number; phone?: { masked: string } }>;
  /** With a session (fresh reauthentication) or the enroll ticket of an enrollment-required sign-in. */
  enrollTotp(label: string): Promise<TotpEnrollment>;
  /** Completes an enrollment-required sign-in when the server returns tokens. Recovery codes are returned once and never cached. */
  confirmTotp(factorId: string, code: string): Promise<{ recoveryCodes?: string[] }>;
  registerPasskey(label: string): Promise<Factor & { recoveryCodes?: string[] }>;
  removeFactor(factorId: string): Promise<void>;
  regenerateRecoveryCodes(): Promise<string[]>;
  /** Additive: `captchaToken` where Turnstile gates phone verification. */
  addPhone(phone: string, opts?: { captchaToken?: string }): Promise<{ challengeId: string }>;
  verifyPhone(challengeId: string, code: string): Promise<void>;
  enableSmsFactor(): Promise<Factor>;
  listConsents(): Promise<{ clientId: string; name: string; scopes: string[] }[]>;
  revokeConsent(clientId: string): Promise<void>;
}
export function createAxiomAuth(options: AxiomAuthOptions): AxiomAuth;
/** RFC 9470 challenge of a `WWW-Authenticate` header (same-origin, or when the header is exposed). */
export function parseStepUpChallenge(response: Response): { acr?: Acr; maxAge?: number }|null;
/** Additive: the Acore runtime's refusal body (`authorization_changed`, `step_up_required`); works cross-origin. */
export function runtimeAuthRefusal(body: unknown): { code: 'authorization_changed' }|{ code: 'step_up_required'; acr?: Acr; maxAge?: number }|null;
