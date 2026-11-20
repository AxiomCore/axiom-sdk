import 'dart:async';

import 'package:axiom_flutter/axiom_flutter.dart';

import 'client.dart';
import 'types.dart';

/// Wires an [AxiomAuth] into an [AxiomRuntime] so every Axiom call carries a
/// fresh access token: the `authorizedFetch` of axiom_flutter.
///
/// * Each new access token (sign-in, refresh, rotation, step-up) is pushed with
///   `setGlobalAuthToken`; sign-out clears it.
/// * `setAuthProvider` answers the runtime's refresh callback with
///   [AxiomAuth.accessToken], which refreshes first when the token is due.
/// * On sign-out (or session expiry) `resetSession` drops the runtime's
///   session-partitioned cache and in-flight calls ([resetSessionOnSignOut]).
///
/// Runtimes without the namespace-wide setters (they throw
/// `UnimplementedError` before axiom_flutter's parity release) fall back to
/// `setAuthToken` for every method listed in [authMethods]
/// (`{namespace: [methodName, ...]}`), e.g. the auth methods the generated
/// module declares.
class AxiomAuthBinding {
  AxiomAuthBinding._(this.auth, this.runtime, this.authMethods, this.resetSessionOnSignOut);

  final AxiomAuth auth;
  final AxiomRuntime runtime;
  final Map<String, List<String>> authMethods;
  final bool resetSessionOnSignOut;

  void Function()? _removeSink;
  void Function()? _unsubscribe;
  bool _wasSignedIn = false;
  bool _globalUnsupported = false;
  bool _providerSet = false;

  /// Attaches [auth] to [runtime] (default: the process runtime). The current
  /// token, if any, is pushed at once.
  static AxiomAuthBinding attach(
    AxiomAuth auth, {
    AxiomRuntime? runtime,
    Map<String, List<String>> authMethods = const {},
    bool resetSessionOnSignOut = true,
  }) {
    final b = AxiomAuthBinding._(auth, runtime ?? AxiomRuntime(), authMethods, resetSessionOnSignOut);
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
      runtime.setAuthProvider((namespace, methodName) => auth.accessToken());
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
    if (token != null) {
      if (!_globalUnsupported) {
        try {
          runtime.setGlobalAuthToken(token);
        } catch (_) {
          _globalUnsupported = true;
        }
      }
      if (_globalUnsupported || authMethods.isNotEmpty) {
        authMethods.forEach((ns, methods) {
          for (final m in methods) {
            try {
              runtime.setAuthToken(namespace: ns, methodName: m, token: token);
            } catch (_) {}
          }
        });
      }
    } else {
      if (!_globalUnsupported) {
        try {
          runtime.clearGlobalAuthToken();
        } catch (_) {
          _globalUnsupported = true;
        }
      }
      authMethods.forEach((ns, methods) {
        for (final m in methods) {
          try {
            runtime.clearAuthToken(namespace: ns, methodName: m);
          } catch (_) {}
        }
      });
    }
  }

  void _onSession(PublicSession s) {
    final signedIn = s.principal != null;
    final ended = _wasSignedIn && (s.status == AuthStatus.anonymous || s.status == AuthStatus.expired);
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
