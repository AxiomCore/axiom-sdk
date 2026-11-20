import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart'
    as web_store;
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
  Future<void> set(String key, RefreshRecord value) async =>
      _slots[key] = value;
  @override
  Future<void> remove(String key) async => _slots.remove(key);
}

/// Mobile and desktop: the record in the platform keystore through
/// `flutter_secure_storage` (iOS/macOS Keychain, Android Keystore-backed
/// ciphers, libsecret on Linux, DPAPI on Windows).
///
/// macOS: by default the record goes to the legacy (file-based) login
/// keychain, which needs no entitlement, so unsigned and ad-hoc signed builds
/// work. Set [macOsDataProtectionKeychain] to true to use the data-protection
/// keychain instead; that requires the Keychain Sharing capability
/// (`keychain-access-groups` entitlement) and a development team. An
/// unsigned or ad-hoc app that carries that entitlement is killed by macOS at
/// launch, so only opt in for team-signed apps.
///
/// When the platform store is unavailable (no keychain, missing plugin,
/// entitlement error) and [fallbackToMemory] is true (the default), the
/// adapter logs one warning and keeps the session in memory for the rest of
/// the process instead of throwing. Check [SecureStorageAdapter.usingMemoryFallback].
///
/// On web `flutter_secure_storage` stores into `localStorage` encrypted with
/// a key that is itself in `localStorage`, which protects nothing against
/// script on the page; use [sessionStorageAdapter] there, or [platformStorage].
SecureStorageAdapter secureStorage({
  FlutterSecureStorage? storage,
  bool macOsDataProtectionKeychain = false,
  bool fallbackToMemory = true,
}) => SecureStorageAdapter._(
  storage ??
      FlutterSecureStorage(
        aOptions: const AndroidOptions(),
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          usesDataProtectionKeychain: macOsDataProtectionKeychain,
        ),
      ),
  fallbackToMemory,
);

/// [secureStorage]'s adapter.
class SecureStorageAdapter extends AuthStorageAdapter {
  SecureStorageAdapter._(this._s, this._fallbackToMemory);
  final FlutterSecureStorage _s;
  final bool _fallbackToMemory;
  _MemoryStorage? _memory;

  /// The underlying store (options inspection in tests).
  @visibleForTesting
  FlutterSecureStorage get platformStore => _s;

  /// True once the platform store failed and the session lives in memory.
  bool get usingMemoryFallback => _memory != null;

  // Keychain and Keystore keys must be plain; the issuer URL is hashed into a
  // stable short name.
  String _k(String key) =>
      'axiom_auth.${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}';

  /// Runs [op] against the platform store; on failure switches to memory once.
  Future<T> _guard<T>(
    Future<T> Function() op,
    Future<T> Function(_MemoryStorage m) fallback,
  ) async {
    final m = _memory;
    if (m != null) return fallback(m);
    try {
      return await op();
    } catch (e) {
      if (!_fallbackToMemory) rethrow;
      final mem = _memory = _MemoryStorage();
      _warnOnce(e);
      return fallback(mem);
    }
  }

  static bool _warned = false;
  static void _warnOnce(Object e) {
    if (_warned) return;
    _warned = true;
    debugPrint(
      'axiom_flutter_auth: the platform secure store is unavailable ($e); '
      'keeping the session in memory for this run (it will not survive a restart). '
      'macOS: the default legacy keychain needs no entitlement; with '
      'secureStorage(macOsDataProtectionKeychain: true) the app must be team-signed '
      'with Keychain Sharing.',
    );
  }

  @override
  Future<RefreshRecord?> get(String key) => _guard(() async {
    final raw = await _s.read(key: _k(key));
    if (raw == null) return null;
    try {
      return RefreshRecord.tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }, (m) => m.get(key));

  @override
  Future<void> set(String key, RefreshRecord value) => _guard(
    () => _s.write(key: _k(key), value: jsonEncode(value.toJson())),
    (m) => m.set(key, value),
  );

  @override
  Future<void> remove(String key) =>
      _guard(() => _s.delete(key: _k(key)), (m) => m.remove(key));
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

/// [sessionStorageAdapter] on web, [secureStorage] everywhere else
/// (legacy keychain on macOS unless [macOsDataProtectionKeychain] is true).
AuthStorageAdapter platformStorage({
  bool macOsDataProtectionKeychain = false,
}) => web_store.isWeb
    ? sessionStorageAdapter()
    : secureStorage(macOsDataProtectionKeychain: macOsDataProtectionKeychain);
