import 'dart:async';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../axiom_generated/axiom_sdk.dart';

/// Base URL of the fixture backend. Android emulator: http://10.0.2.2:8791.
const String fixtureBaseUrl = String.fromEnvironment(
  'FIXTURE_BASE_URL',
  defaultValue: 'http://127.0.0.1:8791',
);

/// Base URL of a second fixture instance started with `FIXTURE_CORS=0`
/// (CLI 0.156.0 refuses WebSocket upgrades when a global cors() is set).
/// Empty: WebSocket checks use [fixtureBaseUrl].
const String fixtureWsBaseUrl = String.fromEnvironment('FIXTURE_WS_BASE_URL');

/// Fixed HS256 token minted by `fixtures/backend/tool/jwt.py token`.
const String fixtureBearerToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2ZpeHR1cmUuYXhpb21jb3JlLmxvY2FsIiwiYXVkIjoiYXhpb20tZml4dHVyZSIsInN1YiI6ImZpeHR1cmUtdXNlciIsImV4cCI6NDEwMjQ0NDgwMCwiaWF0IjoxNzYzNjQwMDAwfQ.jwRiGU7TnZJe5u9JMFc25Crv5r6OscJkitUjMXAEwyU';
const String fixtureApiKey = 'fixture-api-key';

class Ctx {
  Ctx(this.sdk);
  final AxiomSdk sdk;
  FixtureModule get api => sdk.fixture;
  String get baseUrl => fixtureBaseUrl;

  FixtureModule? _ws;

  /// The fixture module for WebSocket checks: namespace `fixture_ws` bound to
  /// [fixtureWsBaseUrl] (falls back to [api] when that is not set).
  Future<FixtureModule> wsApi() async {
    if (fixtureWsBaseUrl.isEmpty) return api;
    if (_ws != null) return _ws!;
    final bytes = (await rootBundle.load('assets/axiom/fixture.axiom')).buffer.asUint8List();
    final r = sdk.runtime.tryLoadContract(
      namespace: 'fixture_ws',
      baseUrl: fixtureWsBaseUrl,
      contractBytes: bytes,
    );
    if (!r.ok) throw CheckFailure('loading fixture_ws failed: $r');
    return _ws = FixtureModule(sdk.runtime, 'fixture_ws');
  }
}

/// Namespaces the checks load, and the auth method names they use.
const _authNamespaces = ['fixture', 'fixture_ws', 'fixg_vendor', 'g_authmeta'];
const _authMethodNames = [
  'Authorization', 'x-api-key', 'api_key', 'authBearer', 'sse', 'wsEcho', //
];

/// Clears every token and the auth provider the checks may set: per-method
/// tokens, namespace tokens, the global token and the provider. Each check
/// that sets one restores state in a `finally`; the runner also calls this
/// between check groups so a failing check cannot leak into the next group.
void resetAuthState(Ctx c) {
  final rt = c.sdk.runtime;
  void quiet(void Function() f) {
    try {
      f();
    } catch (_) {
      // Runtime without this setter, or namespace not loaded: nothing set.
    }
  }

  quiet(() => rt.setAuthProvider(null));
  quiet(rt.clearGlobalAuthToken);
  for (final ns in _authNamespaces) {
    quiet(() => rt.clearNamespaceAuthToken(namespace: ns));
    for (final m in _authMethodNames) {
      quiet(() => rt.clearAuthToken(namespace: ns, methodName: m));
    }
  }
  for (final m in _authMethodNames) {
    quiet(() => c.api.axiom.clearAuthToken(m));
  }
}

typedef Check = Future<void> Function(Ctx ctx);

class CheckDef {
  const CheckDef(this.name, this.feature, this.run);
  final String name;
  final String feature;
  final Check run;
}

class CheckFailure implements Exception {
  CheckFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class CheckSkipped implements Exception {
  CheckSkipped(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Marks a check as not runnable yet, e.g. `skip('pending: f3')`.
Never skip(String reason) => throw CheckSkipped(reason);

void expectThat(bool condition, String message) {
  if (!condition) throw CheckFailure(message);
}

void expectEq(Object? actual, Object? expected, String what) {
  if (actual != expected) {
    throw CheckFailure('$what: expected <$expected>, got <$actual>');
  }
}

/// Waits for the first settled state (data or error) of [query].
Future<AxiomState<T>> settle<T>(
  AxiomQuery<T> query, {
  Duration timeout = const Duration(seconds: 10),
}) {
  return query.stream
      .firstWhere((s) => s.status == AxiomStatus.success || s.status == AxiomStatus.error)
      .timeout(timeout, onTimeout: () => throw CheckFailure('timed out after $timeout'));
}

/// Waits for data and fails with the SDK error otherwise.
Future<T> data<T>(AxiomQuery<T> query, {Duration timeout = const Duration(seconds: 10)}) async {
  final s = await settle(query, timeout: timeout);
  if (s.status == AxiomStatus.error || s.data == null) {
    throw CheckFailure('expected data, got error ${s.error}');
  }
  return s.data as T;
}

/// Waits for an error and returns it.
Future<AxiomError> failure<T>(AxiomQuery<T> query) async {
  final s = await settle(query);
  if (s.status != AxiomStatus.error || s.error == null) {
    throw CheckFailure('expected an error, got data ${s.data}');
  }
  return s.error!;
}

int httpStatusOf(AxiomError e) {
  final code = e.code;
  return code is HttpStatus ? code.code : -1;
}
