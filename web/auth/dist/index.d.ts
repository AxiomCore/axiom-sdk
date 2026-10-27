// @axiomcore/auth-web public declarations (auth-surfaces/v1 "Web client").
// The contract's API block, plus the additive optional members marked "Additive".

export type AuthStatus = 'unknown'|'loading'|'error'|'anonymous'|'authenticated'|'expired'|'refreshing';
export interface PublicPrincipal { subject: string; tenant: string|null; roles: string[]; permissions: string[] }
export interface PublicSession { id: string; status: AuthStatus; principal: PublicPrincipal|null }
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
  navigator?: { readonly locks?: { request<T>(name: string, callback: () => Promise<T>): Promise<T> } };
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
  /** Additive: what `JSON.stringify(auth)` shows; never a token. */
  toJSON(): { issuer: string; session: PublicSession };
}
export function createAxiomAuth(options: AxiomAuthOptions): AxiomAuth;
