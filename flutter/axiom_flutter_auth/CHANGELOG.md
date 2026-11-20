## Unreleased

- **Breaking (security):** `AxiomAuthBinding.attach` takes a required
  `namespaces` list. The access token goes only to those namespaces
  (`setNamespaceAuthToken`, provider answers `null` elsewhere); the binding
  no longer sets a global token, which reached every loaded contract,
  third-party hosts included.

- `flutter_secure_storage` ^10 (was ^9.2.2): apps using this package now build with
  `flutter build web --wasm`. Android apps need `minSdk 23` and `compileSdk 36`.
  The deprecated `encryptedSharedPreferences` option is no longer passed.
- macOS: `secureStorage()` now uses the legacy login keychain by default (no entitlement, works in
  unsigned and ad-hoc builds). Opt in to the data-protection keychain with
  `secureStorage(macOsDataProtectionKeychain: true)` (team-signed app with Keychain Sharing).
  `platformStorage()` takes the same option.
- `secureStorage()` returns `SecureStorageAdapter`. If the platform store fails it prints one warning
  and keeps the session in memory (`usingMemoryFallback`) instead of throwing;
  `fallbackToMemory: false` restores the error.

## 0.1.0 (2026-11-20)

- First release: Dart port of @axiomcore/auth-web (auth-surfaces/v1): password, email code, magic link, provider and hosted PKCE sign-in, refresh with rotation, sign-out with revocation, MFA, step-up, factors, storage adapters (memory, secure storage, web session storage), axiom_flutter binding, widgets.
