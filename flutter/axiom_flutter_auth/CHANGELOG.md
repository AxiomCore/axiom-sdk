## Unreleased

- `flutter_secure_storage` ^10 (was ^9.2.2): apps using this package now build with
  `flutter build web --wasm`. Android apps need `minSdk 23` and `compileSdk 36`.
  The deprecated `encryptedSharedPreferences` option is no longer passed.

## 0.1.0 (2026-11-20)

- First release: Dart port of @axiomcore/auth-web (auth-surfaces/v1): password, email code, magic link, provider and hosted PKCE sign-in, refresh with rotation, sign-out with revocation, MFA, step-up, factors, storage adapters (memory, secure storage, web session storage), axiom_flutter binding, widgets.
