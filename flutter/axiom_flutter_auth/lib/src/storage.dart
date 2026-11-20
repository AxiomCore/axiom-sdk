import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart' as web_store;
import 'types.dart';

/// Holds only the refresh record (never the access token).
///
/// [shared] is true when another process or tab can rotate the same record;
/// Flutter apps run one client per process, so every built-in adapter is
/// unshared.
abstract class AuthStorageAdapter {
  Future<RefreshRecord?> get(String key);
  Future<void> set(String key, RefreshRecord value);
  Future<void> remove(String key);
  bool get shared => false;
}

/// Default: the session lives as long as the process. Nothing survives a
/// restart, and nothing is written to disk.
AuthStorageAdapter memoryStorage() => _MemoryStorage();

class _MemoryStorage extends AuthStorageAdapter {
  final Map<String, RefreshRecord> _slots = {};
  @override
  Future<RefreshRecord?> get(String key) async => _slots[key];
  @override
  Future<void> set(String key, RefreshRecord value) async => _slots[key] = value;
  @override
  Future<void> remove(String key) async => _slots.remove(key);
}

/// Mobile and desktop: the record in the platform keystore through
/// `flutter_secure_storage` (iOS/macOS Keychain, Android Keystore-backed
/// encrypted preferences, libsecret on Linux, DPAPI on Windows).
///
/// On web `flutter_secure_storage` stores into `localStorage` encrypted with
/// a key that is itself in `localStorage`, which protects nothing against
/// script on the page; use [sessionStorageAdapter] there, or [platformStorage].
AuthStorageAdapter secureStorage({FlutterSecureStorage? storage}) =>
    _SecureStorage(storage ??
        const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
        ));

class _SecureStorage extends AuthStorageAdapter {
  _SecureStorage(this._s);
  final FlutterSecureStorage _s;

  // Keychain and Keystore keys must be plain; the issuer URL is hashed into a
  // stable short name.
  String _k(String key) => 'axiom_auth.${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}';

  @override
  Future<RefreshRecord?> get(String key) async {
    final raw = await _s.read(key: _k(key));
    if (raw == null) return null;
    try {
      return RefreshRecord.tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set(String key, RefreshRecord value) =>
      _s.write(key: _k(key), value: jsonEncode(value.toJson()));

  @override
  Future<void> remove(String key) => _s.delete(key: _k(key));
}

/// Web only: the record in `window.sessionStorage` (per tab, survives a
/// reload, gone when the tab closes). Same trade-off as auth-web's
/// `sessionStorageAdapter`: any script running on the page (an XSS) can read
/// the refresh token, so use it only with a strict Content-Security-Policy;
/// [memoryStorage] keeps it out of reach of other scripts but signs the user
/// out on reload. Throws `AxiomAuthError('unavailable')` off the web.
AuthStorageAdapter sessionStorageAdapter() => _SessionStorage();

class _SessionStorage extends AuthStorageAdapter {
  @override
  Future<RefreshRecord?> get(String key) async {
    final raw = web_store.read(key);
    if (raw == null) return null;
    try {
      return RefreshRecord.tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set(String key, RefreshRecord value) async =>
      web_store.write(key, jsonEncode(value.toJson()));

  @override
  Future<void> remove(String key) async => web_store.delete(key);
}

/// [sessionStorageAdapter] on web, [secureStorage] everywhere else.
AuthStorageAdapter platformStorage() =>
    web_store.isWeb ? sessionStorageAdapter() : secureStorage();
