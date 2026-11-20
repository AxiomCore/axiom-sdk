import 'dart:async';

import 'package:axiom_flutter/axiom_flutter.dart';

import 'client.dart';
import 'types.dart';

/// Wires an [AxiomAuth] into an [AxiomRuntime] so calls to the namespaces you
/// name carry a fresh access token: the `authorizedFetch` of axiom_flutter.
///
/// The binding is **scoped**: it authorizes exactly the namespaces passed to
/// [attach] (`namespaces`, required, no implicit "all"). Other loaded
/// contracts (a vendor CMS on another host, a public API) never see the
/// user's token.
///
/// * Each new access token (sign-in, refresh, rotation, step-up) is pushed
///   with `setNamespaceAuthToken` for each bound namespace; sign-out clears
///   exactly those namespaces. The binding never calls `setGlobalAuthToken`.
/// * `setAuthProvider` answers the runtime's refresh callback with
///   [AxiomAuth.accessToken] for the bound namespaces, and `null` for any
///   other namespace (the runtime then falls back to tokens the app set
///   itself).
/// * On sign-out (or session expiry) `resetSession` drops the runtime's
///   session-partitioned cache and in-flight calls ([resetSessionOnSignOut]).
///
/// Runtimes without the namespace-wide setters (they throw
/// `UnimplementedError` before axiom_flutter's parity release) fall back to
/// `setAuthToken` for every method listed in [authMethods]
/// (`{namespace: [methodName, ...]}`); its keys must be bound namespaces.
class AxiomAuthBinding {
  AxiomAuthBinding._(
    this.auth,
    this.runtime,
    this.namespaces,
    this.authMethods,
    this.resetSessionOnSignOut,
  );

  final AxiomAuth auth;
  final AxiomRuntime runtime;

  /// The namespaces this binding authorizes (and only these).
  final Set<String> namespaces;
  final Map<String, List<String>> authMethods;
  final bool resetSessionOnSignOut;

  void Function()? _removeSink;
  void Function()? _unsubscribe;
  bool _wasSignedIn = false;
  bool _namespaceUnsupported = false;
  bool _providerSet = false;

  /// Attaches [auth] to [runtime] (default: the process runtime) for the
  /// given [namespaces]. The current token, if any, is pushed at once.
  ///
  /// Throws [ArgumentError] when [namespaces] is empty, or when [authMethods]
  /// names a namespace that is not in [namespaces].
  static AxiomAuthBinding attach(
    AxiomAuth auth, {
    required Iterable<String> namespaces,
    AxiomRuntime? runtime,
    Map<String, List<String>> authMethods = const {},
    bool resetSessionOnSignOut = true,
  }) {
    final scoped = namespaces.where((n) => n.isNotEmpty).toSet();
    if (scoped.isEmpty) {
      throw ArgumentError.value(
        namespaces,
        'namespaces',
        'name at least one namespace the access token is meant for',
      );
    }
    final stray = authMethods.keys.where((ns) => !scoped.contains(ns));
    if (stray.isNotEmpty) {
      throw ArgumentError.value(
        authMethods,
        'authMethods',
        'namespaces ${stray.join(', ')} are not in `namespaces`',
      );
    }
    final b = AxiomAuthBinding._(
      auth,
      runtime ?? AxiomRuntime(),
      Set.unmodifiable(scoped),
      authMethods,
      resetSessionOnSignOut,
    );
    b._wasSignedIn = auth.session().principal != null;
    b._registerProvider();
    b._removeSink = auth.addTokenSink(b._onToken);
    b._unsubscribe = auth.subscribe(b._onSession);
    return b;
  }

  /// The token most recently pushed into the runtime (test seam).
  String? get lastPushedToken => _last;
  String? _last;

  void _registerProvider() {
    try {
      runtime.setAuthProvider(
        (namespace, methodName) => namespaces.contains(namespace)
            ? auth.accessToken()
            : Future.value(null),
      );
      _providerSet = true;
    } catch (_) {
      // Runtimes before the parity release have no provider hook; pushed
      // tokens alone keep calls authorized.
      _providerSet = false;
    }
  }

  bool get providerRegistered => _providerSet;

  void _onToken(String? token) {
    if (token == _last) return;
    _last = token;
    for (final ns in namespaces) {
      if (_namespaceUnsupported) break;
      try {
        if (token != null) {
          runtime.setNamespaceAuthToken(namespace: ns, token: token);
        } else {
          runtime.clearNamespaceAuthToken(namespace: ns);
        }
      } on UnimplementedError {
        _namespaceUnsupported = true;
      } on NoSuchMethodError {
        _namespaceUnsupported = true;
      }
    }
    authMethods.forEach((ns, methods) {
      for (final m in methods) {
        try {
          if (token != null) {
            runtime.setAuthToken(namespace: ns, methodName: m, token: token);
          } else {
            runtime.clearAuthToken(namespace: ns, methodName: m);
          }
        } catch (_) {}
      }
    });
  }

  void _onSession(PublicSession s) {
    final signedIn = s.principal != null;
    final ended =
        _wasSignedIn &&
        (s.status == AuthStatus.anonymous || s.status == AuthStatus.expired);
    if (s.status == AuthStatus.authenticated || ended) _wasSignedIn = signedIn;
    if (ended && resetSessionOnSignOut) {
      unawaited(_reset());
    }
  }

  Future<void> _reset() async {
    try {
      await runtime.resetSession();
    } catch (_) {
      // Before the parity release: tokens are already cleared above.
    }
    // resetSession drops the provider; keep answering for the next sign-in.
    _registerProvider();
  }

  /// Stops pushing tokens and removes the provider. Tokens already pushed stay.
  void detach() {
    _removeSink?.call();
    _unsubscribe?.call();
    _removeSink = null;
    _unsubscribe = null;
    if (_providerSet) {
      try {
        runtime.setAuthProvider(null);
      } catch (_) {}
      _providerSet = false;
    }
  }
}
