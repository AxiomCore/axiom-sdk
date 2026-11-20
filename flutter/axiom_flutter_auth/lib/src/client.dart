// Dart port of @axiomcore/auth-web (auth-surfaces/v1 "Web client",
// auth-core/v1 "Public protocol", auth-advanced/v1 17.1).
//
// Secrets live only in private fields of [AxiomAuth]: the access token (pushed
// out through token sinks), the refresh token (also written to the storage
// adapter), captured reset and invitation tokens, and the sealed MFA ticket.
// None of them appear in errors, the session, toString or toJson.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart' as browser;
import 'storage.dart';
import 'types.dart';

const _knownCodes = {
  'INVALID_REQUEST', 'WEAK_PASSWORD', 'INVALID_CREDENTIALS', 'INVALID_REFRESH', 'INVALID_TOKEN',
  'USER_DISABLED', 'SIGNUP_DISABLED', 'TENANT_DENIED', 'ORIGIN', 'NOT_FOUND', 'ACCOUNT_EXISTS',
  'REFRESH_TOO_SOON', 'RATE_LIMITED', 'QUOTA', 'RESERVE_EXHAUSTED', 'UNAVAILABLE', 'FORBIDDEN',
  'CONFLICT', 'LIMIT', 'KEY_LIMIT', 'TOO_MANY_PERMISSIONS', 'ISSUER_SCOPE',
  'INVALID_CODE', 'INVALID_GRANT', 'REDIRECT_URI', 'CAPTCHA', 'REAUTH_REQUIRED', 'EMAIL_UNVERIFIED',
  'METHOD_DISABLED', 'ACCOUNT_LINK_REQUIRED', 'IDENTITY_LINKED', 'LAST_METHOD', 'UPGRADE_PENDING',
  // auth-advanced/v1 13
  'MFA_REQUIRED', 'MFA_ENROLLMENT_REQUIRED', 'STEP_UP_REQUIRED', 'WEBAUTHN', 'FACTOR_LIMIT', 'FACTOR_REQUIRED',
  'PHONE_NOT_ALLOWED', 'FEATURE_DISABLED', 'HOOK_FAILED',
};

const _redirectOutcomes = {
  'invalid_request', 'access_denied', 'provider_error', 'temporarily_unavailable',
  'account_link_required', 'identity_linked', 'signup_disabled', 'user_disabled', 'quota', 'method_disabled',
  'mfa_required', 'mfa_enrollment_required',
};

const _factorTypes = {'totp', 'passkey', 'sms'};
const _ticketMax = 4096;
const _txMaxPending = 4;
const _txLifetimeMs = 15 * 60 * 1000;
const _expMarginMs = 60 * 1000;
const _rotationMarginMs = 120 * 1000;
const _jitterMaxMs = 10 * 1000;
const _defaultRetryMs = 30 * 1000;
const _callbackQuery = ['code', 'state', 'iss', 'error', 'error_code', 'mfa_ticket', 'enroll_ticket'];

/// Opens the authorization URL and completes with the callback URL the issuer
/// redirected to. Completes with null when the platform navigates away instead
/// (a full-page redirect on web; the app then calls [AxiomAuth.restore] or
/// [AxiomAuth.handleRedirect] on the next load).
abstract class AuthRedirectLauncher {
  Future<Uri?> authenticate(Uri url, {required String callbackUrlScheme});
}

/// WebAuthn on the device, JSON in and JSON out (the WebAuthn JSON forms:
/// `PublicKeyCredentialCreationOptionsJSON` / `RequestOptionsJSON` in,
/// `RegistrationResponseJSON` / `AuthenticationResponseJSON` out). Plug any
/// passkeys plugin in here; without one the passkey calls fail with `webauthn`.
abstract class AxiomPasskeys {
  Future<Map<String, Object?>> create(Map<String, Object?> options);
  Future<Map<String, Object?>> get(Map<String, Object?> options);
}

typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

class AxiomAuthOptions {
  const AxiomAuthOptions({
    required this.issuer,
    this.audience,
    this.redirectUri,
    this.logoutUri,
    this.storage,
    this.onTokens,
    this.httpClient,
    this.clock,
    this.apiOrigins = const [],
    this.launcher,
    this.passkeys,
    this.timerFactory,
  });

  /// `[auth.environments.<env>].issuer`.
  final String issuer;

  /// Sent only when set.
  final String? audience;

  /// The callback the issuer redirects to: an app link
  /// (`https://app.example.com/auth/callback`), a custom scheme
  /// (`com.example.app:/auth/callback`) or, on web, `<origin>/auth/callback`.
  /// Must be listed in the environment's `redirect_urls`.
  final String? redirectUri;

  /// Needed for `signOut(redirect: true)`.
  final String? logoutUri;

  /// Default [memoryStorage]; see [secureStorage], [sessionStorageAdapter], [platformStorage].
  final AuthStorageAdapter? storage;

  /// Transport sink: the raw access token, or null. Prefer [AxiomAuthBinding]
  /// for axiom_flutter.
  final void Function(String? accessToken)? onTokens;

  /// Test seam and custom transport. Default `http.Client()`.
  final http.Client? httpClient;

  /// Epoch milliseconds. Test seam.
  final int Function()? clock;

  /// Exact origins (https, or http on loopback) that [AxiomAuth.authorizedClient]
  /// sends the bearer to. On web the page's own origin is always included.
  final List<String> apiOrigins;

  /// Opens hosted sign-in and provider flows. Default: flutter_web_auth_2
  /// (see `FlutterWebAuth2Launcher`).
  final AuthRedirectLauncher? launcher;

  final AxiomPasskeys? passkeys;

  /// Test seam (default `Timer.new`).
  final TimerFactory? timerFactory;
}

class _Claims {
  _Claims(this.sub, this.aud, this.tenant, this.roles, this.permissions, this.iat, this.exp, this.acr, this.authTime);
  final String sub;
  final String? aud;
  final String? tenant;
  final List<String> roles;
  final List<String> permissions;
  final int iat;
  final int exp;
  final Acr acr;
  final int authTime;
}

class _Held {
  _Held({
    required this.accessToken,
    required this.claims,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.sessionId,
    required this.audience,
    required this.rotationAnchorMs,
    required this.rotationIntervalMs,
  });
  final String? accessToken;
  final _Claims? claims;
  final String refreshToken;
  final int refreshExpiresAt;
  final String sessionId;
  final String audience;
  final int rotationAnchorMs;
  final int rotationIntervalMs;

  _Held copyWith({int? rotationAnchorMs}) => _Held(
        accessToken: accessToken,
        claims: claims,
        refreshToken: refreshToken,
        refreshExpiresAt: refreshExpiresAt,
        sessionId: sessionId,
        audience: audience,
        rotationAnchorMs: rotationAnchorMs ?? this.rotationAnchorMs,
        rotationIntervalMs: rotationIntervalMs,
      );
}

class _Pending {
  _Pending(this.kind, this.ticket, this.verifier, this.expiresAt, this.challenge);
  final String kind; // mfa | enroll
  final String ticket;
  final String? verifier;
  final int expiresAt;
  final MfaChallenge challenge;
}

class _Tx {
  _Tx(this.state, this.verifier, this.kind, this.provider, this.redirectUri, this.returnTo, this.createdAt);
  final String state;
  final String verifier;
  final String kind; // provider | hosted | magic_link
  final String? provider;
  final String redirectUri;
  final String? returnTo;
  final int createdAt;
}

/// Error from [_call] carrying the private MFA body; never escapes the client.
class _ChallengeError extends AxiomAuthError {
  _ChallengeError(super.code, super.status, this.body);
  final Map body;
}

Map<String, Object?>? _rec(Object? v) => v is Map ? v.cast<String, Object?>() : null;
List<String>? _strings(Object? v) =>
    v is List && v.every((x) => x is String) ? v.cast<String>().toList() : null;

String _mapErrorCode(Object? raw) {
  if (raw is String && raw.startsWith('AXAUTH_')) {
    final name = raw.substring(7);
    if (_knownCodes.contains(name)) return name.toLowerCase();
  }
  return 'unavailable';
}

String _b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
List<int> _decodeB64u(String text) => base64Url.decode(base64Url.normalize(text));

_Claims? _decodeClaims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  Object? payload;
  try {
    payload = jsonDecode(utf8.decode(_decodeB64u(parts[1])));
  } catch (_) {
    return null;
  }
  final p = _rec(payload);
  if (p == null) return null;
  final sub = p['sub'], iat = p['iat'], exp = p['exp'];
  if (sub is! String || iat is! num || exp is! num) return null;
  List<String> strs(Object? v) => v is List ? v.whereType<String>().toList() : <String>[];
  return _Claims(
    sub,
    p['aud'] is String ? p['aud'] as String : null,
    p['tenant'] is String ? p['tenant'] as String : null,
    strs(p['roles']),
    strs(p['permissions']),
    iat.toInt(),
    exp.toInt(),
    p['acr'] == 'aal2' ? Acr.aal2 : p['acr'] == 'phr' ? Acr.phr : Acr.aal1,
    p['auth_time'] is num ? (p['auth_time'] as num).toInt() : iat.toInt(),
  );
}

/// auth-surfaces/v1 "returnTo" (security S-9): a same-app absolute path.
bool validReturnTo(Object? value) {
  if (value is! String || value.isEmpty) return false;
  if (value[0] != '/' || (value.length > 1 && (value[1] == '/' || value[1] == r'\'))) return false;
  if (value.contains(r'\')) return false;
  if (RegExp(r'[\u0000-\u001f\u007f]').hasMatch(value)) return false;
  return Uri.tryParse(value) != null;
}

int? _parseRetryAfter(String? header, int now) {
  if (header == null) return null;
  final text = header.trim();
  if (RegExp(r'^\d+$').hasMatch(text)) return int.parse(text);
  final at = DateTime.tryParse(text);
  if (at == null) return null;
  return max(0, ((at.millisecondsSinceEpoch - now) / 1000).ceil());
}

/// RFC 9470: `WWW-Authenticate: Bearer error="insufficient_user_authentication", acr_values="aal2", max_age=600`.
StepUpChallenge? parseStepUpChallenge(http.BaseResponse response) {
  final header = response.headers['www-authenticate'];
  if (header == null || !RegExp(r'^\s*Bearer\b', caseSensitive: false).hasMatch(header)) return null;
  final params = <String, String>{};
  for (final m in RegExp(r'([A-Za-z_]+)\s*=\s*(?:"([^"]*)"|([^\s,]+))').allMatches(header)) {
    params[m.group(1)!.toLowerCase()] = m.group(2) ?? m.group(3)!;
  }
  if (params['error'] != 'insufficient_user_authentication') return null;
  Acr? acr;
  for (final v in (params['acr_values'] ?? '').split(' ')) {
    acr ??= Acr.tryParse(v);
  }
  final ma = params['max_age'];
  return StepUpChallenge(
    acr: acr,
    maxAge: ma != null && RegExp(r'^\d{1,9}$').hasMatch(ma) ? int.parse(ma) : null,
  );
}

/// The Acore runtime's refusal body:
/// `{"error":{"code":"authorization_changed"|"step_up_required","message":...}}`.
/// Accepts the decoded JSON or its text.
RuntimeAuthRefusal? runtimeAuthRefusal(Object? body) {
  var value = body;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
  final error = _rec(_rec(value)?['error']);
  if (error == null) return null;
  final code = error['code'];
  if (code == 'authorization_changed') return const RuntimeAuthRefusal('authorization_changed');
  if (code != 'step_up_required') return null;
  final message = error['message'];
  final m = message is String
      ? RegExp(r'acr_values=(aal1|aal2|phr)(?:, max_age=(\d{1,9}))?$').firstMatch(message)
      : null;
  return RuntimeAuthRefusal('step_up_required',
      acr: m == null ? null : Acr.tryParse(m.group(1)),
      maxAge: m?.group(2) == null ? null : int.parse(m!.group(2)!));
}

/// The managed-auth client. Create one per issuer with [AxiomAuth.new].
class AxiomAuth {
  AxiomAuth(AxiomAuthOptions options)
      : _o = options,
        issuer = options.issuer,
        _storage = options.storage ?? memoryStorage(),
        _http = options.httpClient ?? http.Client(),
        _clock = options.clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _timer = options.timerFactory ?? Timer.new {
    final u = Uri.tryParse(issuer);
    if (u == null || !u.hasScheme || u.host.isEmpty) throw ArgumentError.value(issuer, 'issuer', 'malformed');
    if (options.redirectUri != null) _redirect = Uri.parse(options.redirectUri!);
    for (final o in options.apiOrigins) {
      final p = Uri.tryParse(o);
      final loop = p != null && (p.host == 'localhost' || p.host == '127.0.0.1' || p.host == '[::1]' || p.host == '::1');
      if (p == null || !p.hasScheme || p.origin != o || (p.scheme != 'https' && !loop)) {
        throw ArgumentError.value(o, 'apiOrigins', 'entries must be https origins without a path');
      }
      _apiOrigins.add(o);
    }
    if (options.onTokens != null) _tokenSinks.add(options.onTokens!);
    _storageKey = 'axiom-auth:refresh:$issuer';
  }

  final AxiomAuthOptions _o;
  final String issuer;
  final AuthStorageAdapter _storage;
  final http.Client _http;
  final int Function() _clock;
  final TimerFactory _timer;
  Uri? _redirect;
  final Set<String> _apiOrigins = {};
  late final String _storageKey;
  final Random _rng = Random.secure();

  _Held? _held;
  int _generation = 0;
  PublicSession _current = PublicSession.initial;
  final List<void Function(PublicSession)> _listeners = [];
  final List<void Function(String?)> _tokenSinks = [];
  Future<PublicSession>? _inflight;
  Timer? _scheduled;
  int _retryNotBefore = 0;
  String _retryCode = 'unavailable';
  String? _resetToken;
  String? _invitationToken;
  _Pending? _pending;
  bool _foreground = true;
  final Map<String, _Tx> _transactions = {};

  // ---------------------------------------------------------------------------
  // Session projection
  // ---------------------------------------------------------------------------

  /// The current session (never a token).
  PublicSession session() => _current;

  /// Notified on every status change, including `refreshing`. Returns the
  /// unsubscribe function.
  void Function() subscribe(void Function(PublicSession) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Adds a transport sink that receives the access token (or null), as
  /// [AxiomAuthOptions.onTokens]. The current token is pushed immediately.
  /// Returns the remove function.
  void Function() addTokenSink(void Function(String?) sink) {
    _tokenSinks.add(sink);
    final h = _held;
    try {
      sink(h != null && h.accessToken != null && h.claims != null ? h.accessToken : null);
    } catch (_) {}
    return () => _tokenSinks.remove(sink);
  }

  void _emit(PublicSession next) {
    if (next.sameAs(_current)) return;
    _current = next;
    for (final l in List.of(_listeners)) {
      try {
        l(_current);
      } catch (_) {
        // A listener failure never breaks the client.
      }
    }
  }

  PublicPrincipal _principalOf(_Claims c) {
    final prev = _current.principal;
    final next = PublicPrincipal(subject: c.sub, tenant: c.tenant, roles: c.roles, permissions: c.permissions);
    return prev != null && prev.sameAs(next) ? prev : next;
  }

  void _publishHeld() {
    final h = _held;
    if (h != null && h.claims != null) {
      _emit(PublicSession(
          id: h.sessionId,
          status: AuthStatus.authenticated,
          principal: _principalOf(h.claims!),
          acr: h.claims!.acr,
          authTime: h.claims!.authTime));
    }
  }

  void _publishStatus(AuthStatus status) {
    if (status == AuthStatus.anonymous || status == AuthStatus.expired || status == AuthStatus.unknown) {
      _emit(PublicSession(id: '', status: status, principal: null));
    } else {
      _emit(PublicSession(
          id: _current.id, status: status, principal: _current.principal, acr: _current.acr, authTime: _current.authTime));
    }
  }

  void _pushToken(String? token) {
    for (final s in List.of(_tokenSinks)) {
      try {
        s(token);
      } catch (_) {
        // The sink is the host's; its failure is not ours to report.
      }
    }
  }

  void _dropCredentials(AuthStatus status) {
    _held = null;
    _generation++;
    _cancelTimer();
    _retryNotBefore = 0;
    _pushToken(null);
    _publishStatus(status);
  }

  Future<void> _removeRecord() async {
    try {
      await _storage.remove(_storageKey);
    } catch (_) {
      // Best effort; the record can no longer rotate once the session is ended.
    }
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  Future<Object?> _call(String method, String path, [Map<String, Object?>? body, String? bearer]) async {
    final req = http.Request(method, Uri.parse(issuer + path));
    req.followRedirects = false;
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (bearer != null) req.headers['Authorization'] = 'Bearer $bearer';
    http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(req));
    } catch (_) {
      throw AxiomAuthError('unavailable', 0);
    }
    final text = response.body;
    Object? data;
    var parsed = true;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        parsed = false;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (!parsed) throw AxiomAuthError('unavailable', response.statusCode);
      return data;
    }
    final err = parsed ? _rec(_rec(data)?['error']) : null;
    final code = err != null ? _mapErrorCode(err['code']) : 'unavailable';
    if ((code == 'mfa_required' || code == 'mfa_enrollment_required') && err != null) {
      throw _ChallengeError(code, response.statusCode, err);
    }
    throw AxiomAuthError(code, response.statusCode, _parseRetryAfter(response.headers['retry-after'], _clock()));
  }

  // auth-advanced/v1 8.2: keeps the ticket private and rethrows a plain error.
  Never _capture(Object err, StackTrace st, String? verifier) {
    if (err is _ChallengeError) {
      final body = err.body;
      final now = _clock();
      final mfa = _rec(body['mfa']);
      final enr = _rec(body['mfa_enrollment']);
      if (err.code == 'mfa_required' && mfa != null && mfa['ticket'] is String && (mfa['ticket'] as String).length <= _ticketMax) {
        final factors = <MfaFactor>[];
        if (mfa['factors'] is List) {
          for (final f in mfa['factors'] as List) {
            final r = _rec(f);
            if (r != null && r['id'] is String && _factorTypes.contains(r['type']) && r['label'] is String && r['usable'] != false) {
              factors.add(MfaFactor(id: r['id'] as String, type: r['type'] as String, label: r['label'] as String));
            }
          }
        }
        final e = mfa['expires_in'];
        final ttl = e is num && e > 0 ? min(e.toInt(), 300) : 300;
        _pending = _Pending('mfa', mfa['ticket'] as String, verifier, now + ttl * 1000,
            MfaChallenge(factors: List.unmodifiable(factors), recoveryCodes: mfa['recovery_codes'] == true));
      } else if (err.code == 'mfa_enrollment_required' && enr != null && enr['ticket'] is String && (enr['ticket'] as String).length <= _ticketMax) {
        final types = (_strings(enr['types']) ?? []).where(_factorTypes.contains).toList();
        _pending = _Pending('enroll', enr['ticket'] as String, verifier, now + 300 * 1000,
            MfaChallenge(factors: const [], recoveryCodes: false, enrollmentTypes: List.unmodifiable(types)));
      }
      throw AxiomAuthError(err.code, err.status);
    }
    Error.throwWithStackTrace(err, st);
  }

  Future<Object?> _firstFactor(String path, Map<String, Object?> body, [String? verifier]) async {
    _pending = null;
    try {
      return await _call('POST', path, body);
    } catch (e, st) {
      _capture(e, st, verifier);
    }
  }

  // Any other call: an MFA body there is a plain error (no ticket captured).
  Future<Object?> _plain(String method, String path, [Map<String, Object?>? body, String? bearer]) async {
    try {
      return await _call(method, path, body, bearer);
    } on _ChallengeError catch (e) {
      throw AxiomAuthError(e.code, e.status);
    }
  }

  _Pending? _livePending(String? kind) {
    if (_pending != null && _clock() >= _pending!.expiresAt) _pending = null;
    if (_pending == null || (kind != null && _pending!.kind != kind)) return null;
    return _pending;
  }

  Map<String, Object?> _ticketBody(_Pending p, Map<String, Object?> body, bool verifier) {
    body['ticket'] = p.ticket;
    if (verifier && p.verifier != null) body['code_verifier'] = p.verifier;
    return body;
  }

  Map<String, Object?> _captcha(Map<String, Object?> body, String? captchaToken) {
    if (captchaToken != null) {
      if (captchaToken.isEmpty || captchaToken.length > 4096) throw AxiomAuthError('invalid_request', 0);
      body['captcha_token'] = captchaToken;
    }
    return body;
  }

  Map<String, Object?> _withAudience(Map<String, Object?> body) {
    if (_o.audience != null) body['audience'] = _o.audience;
    return body;
  }

  _Held _heldFrom(Object? data, _Held? previous) {
    final d = _rec(data);
    final session = _rec(d?['session']);
    if (d == null || d['access_token'] is! String || d['refresh_token'] is! String ||
        d['refresh_expires_at'] is! String || session == null || session['id'] is! String) {
      throw AxiomAuthError('unavailable', 0);
    }
    final claims = _decodeClaims(d['access_token'] as String);
    final rexp = DateTime.tryParse(d['refresh_expires_at'] as String);
    if (claims == null || rexp == null) throw AxiomAuthError('unavailable', 0);
    final now = _clock();
    var anchor = claims.iat * 1000;
    var interval = (claims.exp - claims.iat) * 1000 - _rotationMarginMs;
    if (previous != null && previous.refreshToken == d['refresh_token'] && previous.rotationIntervalMs > 0) {
      // Early refresh: same refresh token, the rotation clock did not move.
      interval = previous.rotationIntervalMs;
      anchor = previous.rotationAnchorMs + interval <= now ? now : previous.rotationAnchorMs;
    }
    return _Held(
      accessToken: d['access_token'] as String,
      claims: claims,
      refreshToken: d['refresh_token'] as String,
      refreshExpiresAt: rexp.millisecondsSinceEpoch,
      sessionId: session['id'] as String,
      audience: claims.aud ?? _o.audience ?? '$issuer/api',
      rotationAnchorMs: anchor,
      rotationIntervalMs: interval,
    );
  }

  Future<void> _persist(_Held h) => _storage.set(
      _storageKey,
      RefreshRecord(
        refreshToken: h.refreshToken,
        refreshExpiresAt: DateTime.fromMillisecondsSinceEpoch(h.refreshExpiresAt, isUtc: true).toIso8601String(),
        issuer: issuer,
        audience: h.audience,
        sessionId: h.sessionId,
      ));

  Future<PublicSession> _establish(Object? data) async {
    final next = _heldFrom(data, null);
    _pending = null;
    _generation++;
    _held = next;
    _retryNotBefore = 0;
    _pushToken(next.accessToken);
    try {
      await _persist(next);
    } catch (_) {
      // The session works in memory; it only will not survive a restart.
    }
    if (identical(_held, next)) {
      _scheduleProactive();
      _publishHeld();
    }
    return _current;
  }

  // ---------------------------------------------------------------------------
  // Timers and app lifecycle
  // ---------------------------------------------------------------------------

  void _cancelTimer() {
    _scheduled?.cancel();
    _scheduled = null;
  }

  void _scheduleAt(int at) {
    _cancelTimer();
    if (_held == null || !_foreground) return;
    final delay = max(0, at - _clock());
    _scheduled = _timer(Duration(milliseconds: delay), () {
      _scheduled = null;
      if (!_foreground) return;
      refresh().catchError((_) => _current);
    });
  }

  void _scheduleProactive() {
    final h = _held;
    if (h == null || h.claims == null) return;
    final exp = h.claims!.exp * 1000;
    final at = h.rotationIntervalMs > 0
        ? min(exp - _expMarginMs, h.rotationAnchorMs + h.rotationIntervalMs)
        : exp - _expMarginMs;
    _scheduleAt(at + _rng.nextInt(_jitterMaxMs + 1));
  }

  /// App lifecycle, the equivalent of auth-web's `visibilitychange`: in the
  /// background no refresh timer runs; on return to the foreground a due
  /// refresh runs at once. `AxiomAuthLifecycle` (widgets) calls this for you.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _cancelTimer();
      return;
    }
    final h = _held;
    if (h == null) return;
    final now = _clock();
    if (_retryNotBefore > now) {
      _scheduleAt(_retryNotBefore);
    } else if (h.claims == null || now >= h.claims!.exp * 1000 - _expMarginMs) {
      refresh().catchError((_) => _current);
    } else {
      _scheduleProactive();
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  /// Rotates the refresh token and gets a new access token. Concurrent calls
  /// share one request. [tenant] switches the organization.
  Future<PublicSession> refresh({String? tenant}) {
    final inflight = _inflight;
    if (inflight != null) {
      if (tenant == null) return inflight;
      return inflight.then((_) => null, onError: (_) => null).then((_) => refresh(tenant: tenant));
    }
    late Future<PublicSession> p;
    p = _rotate((presented) {
      final body = <String, Object?>{'refresh_token': presented.refreshToken};
      if (tenant != null) body['tenant'] = tenant;
      return _plain('POST', '/v1/token/refresh', _withAudience(body));
    }, false)
        .whenComplete(() {
      if (identical(_inflight, p)) _inflight = null;
    });
    _inflight = p;
    return p;
  }

  Future<void> _awaitInflight() async {
    while (_inflight != null) {
      try {
        await _inflight;
      } catch (_) {}
    }
  }

  // auth-advanced/v1 8.6: reauthentication rotates the refresh token, so it runs
  // as the one in-flight rotation, never beside a refresh.
  Future<PublicSession> _reauthenticate(Future<Object?> Function(_Held presented, String bearer) request) async {
    await _awaitInflight();
    final bearer = await accessToken();
    if (bearer == null) throw AxiomAuthError('invalid_token', 0);
    await _awaitInflight();
    final p = _rotate((presented) => request(presented, bearer), true);
    // Refresh callers that coalesce onto a step-up get the session, not its failure.
    late Future<PublicSession> shared;
    shared = p.catchError((_) => _current).whenComplete(() {
      if (identical(_inflight, shared)) _inflight = null;
    });
    _inflight = shared;
    return p;
  }

  Future<PublicSession> _rotate(Future<Object?> Function(_Held presented) request, bool reauth) async {
    final h0 = _held;
    if (h0 == null) throw AxiomAuthError('invalid_refresh', 0);
    final now = _clock();
    if (now >= h0.refreshExpiresAt) {
      _dropCredentials(AuthStatus.expired);
      await _removeRecord();
      throw AxiomAuthError('invalid_refresh', 0);
    }
    if (!reauth && _retryNotBefore > now) {
      throw AxiomAuthError(_retryCode, 0, ((_retryNotBefore - now) / 1000).ceil());
    }
    final gen = _generation;
    _cancelTimer();
    _publishStatus(h0.claims != null ? AuthStatus.refreshing : AuthStatus.loading);

    try {
      if (_held == null || _generation != gen) throw AxiomAuthError('invalid_refresh', 0);
      final presented = _held!;
      final data = await request(presented);
      if (_generation == gen && identical(_held, presented)) {
        final next = _heldFrom(data, reauth ? null : presented);
        if (next.sessionId != presented.sessionId) throw AxiomAuthError('unavailable', 0);
        _held = next;
        _retryNotBefore = 0;
        _pushToken(next.accessToken);
        try {
          await _persist(next);
        } catch (_) {}
      }
    } catch (err) {
      final e = err is AxiomAuthError ? err : AxiomAuthError('unavailable', 0);
      if (_generation != gen) throw e;
      if (e.code == 'invalid_refresh') {
        if (_held != null) _dropCredentials(AuthStatus.expired);
        await _removeRecord();
        throw e;
      }
      final h = _held;
      if (h == null) throw e;
      if (reauth) {
        // A refused step-up changes nothing.
        _scheduleProactive();
        if (h.claims != null) {
          _publishHeld();
        } else {
          _publishStatus(AuthStatus.error);
        }
        throw e;
      }
      if (e.code == 'unavailable' || e.code == 'rate_limited') {
        _retryCode = e.code;
        _retryNotBefore = _clock() + (e.retryAfterSeconds != null ? e.retryAfterSeconds! * 1000 : _defaultRetryMs);
        _scheduleAt(_retryNotBefore);
      } else if (e.code == 'refresh_too_soon') {
        _held = h.copyWith(rotationAnchorMs: _clock());
        _scheduleProactive();
      } else {
        _scheduleProactive();
      }
      if (h.claims != null) {
        _publishHeld();
      } else {
        _publishStatus(AuthStatus.error);
      }
      throw e;
    }
    if (_generation == gen && _held != null) {
      _scheduleProactive();
      _publishHeld();
    }
    return _current;
  }

  /// A valid access token, refreshing first when it is due; null while
  /// signed out. Additive to auth-web (which exposes `authorizationHeader`).
  Future<String?> accessToken() async {
    var h = _held;
    if (h == null) return null;
    if (h.accessToken == null || h.claims == null || _clock() >= h.claims!.exp * 1000 - _expMarginMs) {
      try {
        await refresh();
      } catch (_) {
        // Fall through: an unexpired token is still usable.
      }
    }
    h = _held;
    if (h == null || h.accessToken == null || h.claims == null || _clock() >= h.claims!.exp * 1000) return null;
    return h.accessToken;
  }

  /// `Bearer <token>` for non-Axiom HTTP calls, or null.
  Future<String?> authorizationHeader() async {
    final t = await accessToken();
    return t == null ? null : 'Bearer $t';
  }

  // ---------------------------------------------------------------------------
  // PKCE transactions (process memory)
  // ---------------------------------------------------------------------------

  String _randomToken() => _b64u(List<int>.generate(32, (_) => _rng.nextInt(256)));
  String _s256(String verifier) => _b64u(crypto.sha256.convert(ascii.encode(verifier)).bytes);

  bool _txLive(_Tx tx, int now) => now - tx.createdAt < _txLifetimeMs && tx.createdAt - now < _txLifetimeMs;

  void _purgeTransactions() {
    final now = _clock();
    _transactions.removeWhere((_, tx) => !_txLive(tx, now));
  }

  ({_Tx tx, String challenge}) _beginTransaction(String kind, String? provider, String? returnTo) {
    final redirectUri = _o.redirectUri;
    if (redirectUri == null) throw AxiomAuthError('redirect_uri', 0);
    _purgeTransactions();
    final tx = _Tx(_randomToken(), _randomToken(), kind, provider, redirectUri,
        validReturnTo(returnTo) ? returnTo : null, _clock());
    final pending = _transactions.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    while (pending.length >= _txMaxPending) {
      _transactions.remove(pending.removeAt(0).state);
    }
    _transactions[tx.state] = tx;
    return (tx: tx, challenge: _s256(tx.verifier));
  }

  _Tx? _takeTransaction(String? state) {
    if (state == null || state.isEmpty) return null;
    final tx = _transactions.remove(state);
    if (tx == null || tx.state != state || !_txLive(tx, _clock())) return null;
    return tx;
  }

  Uri _startUrl(String path, _Tx tx, String challenge, [Map<String, String> extra = const {}]) {
    final u = Uri.parse(issuer + path);
    return u.replace(queryParameters: {
      ...u.queryParameters,
      'redirect_uri': tx.redirectUri,
      'state': tx.state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      ...extra,
    });
  }

  AuthRedirectLauncher _launcher() {
    final l = _o.launcher ?? defaultLauncher;
    if (l == null) throw AxiomAuthError('unavailable', 0);
    return l;
  }

  /// Set by `redirect.dart` (flutter_web_auth_2); null in pure-Dart use.
  static AuthRedirectLauncher? defaultLauncher;

  Future<PublicSession> _runRedirect(Uri url, _Tx tx) async {
    final scheme = Uri.parse(tx.redirectUri).scheme;
    Uri? callback;
    try {
      callback = await _launcher().authenticate(url, callbackUrlScheme: scheme);
    } on AxiomAuthError {
      _transactions.remove(tx.state);
      rethrow;
    } catch (_) {
      // The user closed the browser, or the platform refused.
      _transactions.remove(tx.state);
      throw AxiomAuthError('access_denied', 0);
    }
    if (callback == null) return _current; // full-page navigation (web)
    final r = await handleRedirect(callback);
    if (!r.handled) throw AxiomAuthError('state_mismatch', 0);
    return _current;
  }

  // ---------------------------------------------------------------------------
  // Redirect completion
  // ---------------------------------------------------------------------------

  bool _isCallback(Uri u) {
    final r = _redirect;
    if (r == null) return false;
    return u.scheme == r.scheme && u.host == r.host && u.port == r.port && u.path == r.path;
  }

  /// Completes a redirect flow from the callback [url] (default: the page URL
  /// on web). `handled: false` when [url] is not the `redirectUri` with
  /// `code`, `error`, `#axiom_link`, `#axiom_reset` or `#axiom_invitation`.
  /// On web the callback parameters are stripped from the address bar first.
  Future<RedirectResult> handleRedirect([Uri? url]) async {
    Uri parsed;
    try {
      parsed = url ?? Uri.parse(browser.currentUrl() ?? '');
    } catch (_) {
      return const RedirectResult(handled: false);
    }
    if (!_isCallback(parsed)) return const RedirectResult(handled: false);
    final query = parsed.queryParameters;
    Map<String, String> fragment;
    try {
      fragment = parsed.fragment.isEmpty ? const {} : Uri.splitQueryString(parsed.fragment);
    } catch (_) {
      fragment = const {};
    }
    final viaQuery = query.containsKey('code') || query.containsKey('error');
    final link = fragment['axiom_link'];
    final reset = fragment['axiom_reset'];
    final invitation = fragment['axiom_invitation'];
    if (!viaQuery && link == null && reset == null && invitation == null) return const RedirectResult(handled: false);

    if (url == null || url.toString() == browser.currentUrl()) {
      final q = Map.of(query)..removeWhere((k, _) => _callbackQuery.contains(k));
      final clearHash = fragment.keys.any((k) => k.startsWith('axiom_') || k == 'state');
      final clean = parsed.replace(queryParameters: q.isEmpty ? null : q, fragment: clearHash ? '' : parsed.fragment);
      var s = clean.path + (clean.hasQuery && clean.query.isNotEmpty ? '?${clean.query}' : '');
      if (!clearHash && parsed.fragment.isNotEmpty) s += '#${parsed.fragment}';
      browser.replaceUrl(s);
    }

    if (!viaQuery && link == null && invitation != null) {
      _invitationToken = invitation;
      return const RedirectResult(handled: true, invitation: true);
    }
    if (!viaQuery && link == null) {
      _resetToken = reset;
      return const RedirectResult(handled: true);
    }

    final tx = _takeTransaction(viaQuery ? query['state'] : fragment['state']);
    if (tx == null || tx.redirectUri != _o.redirectUri) throw AxiomAuthError('state_mismatch', 0);
    final returnTo = validReturnTo(tx.returnTo) ? tx.returnTo : null;

    String path;
    Map<String, Object?> body;
    if (viaQuery) {
      if (tx.kind == 'magic_link') throw AxiomAuthError('state_mismatch', 0);
      if (query['iss'] != issuer) throw AxiomAuthError('invalid_grant', 0);
      final outcome = query['error'];
      if (outcome != null) {
        final ticket = outcome == 'mfa_required'
            ? query['mfa_ticket']
            : outcome == 'mfa_enrollment_required'
                ? query['enroll_ticket']
                : null;
        if (ticket != null && ticket.isNotEmpty && ticket.length <= _ticketMax) {
          _pending = outcome == 'mfa_required'
              ? _Pending('mfa', ticket, tx.verifier, _clock() + 300 * 1000,
                  const MfaChallenge(factors: [], recoveryCodes: true))
              : _Pending('enroll', ticket, tx.verifier, _clock() + 300 * 1000,
                  const MfaChallenge(factors: [], recoveryCodes: false, enrollmentTypes: []));
        }
        throw AxiomAuthError(_redirectOutcomes.contains(outcome) ? outcome : 'unavailable', 0);
      }
      final code = query['code'];
      if (code == null || code.isEmpty) throw AxiomAuthError('invalid_grant', 0);
      path = '/v1/token/authorization-code';
      body = _withAudience({'code': code, 'code_verifier': tx.verifier, 'redirect_uri': tx.redirectUri});
    } else {
      if (tx.kind != 'magic_link') throw AxiomAuthError('state_mismatch', 0);
      path = '/v1/email/link/verify';
      body = _withAudience({'token': link, 'code_verifier': tx.verifier});
    }
    final data = await _firstFactor(path, body, tx.verifier);
    await _establish(data);
    return RedirectResult(handled: true, returnTo: returnTo);
  }

  Future<PublicSession> _restoreStored() async {
    if (_held != null) return _current;
    _publishStatus(AuthStatus.loading);
    RefreshRecord? record;
    try {
      record = await _storage.get(_storageKey);
    } catch (_) {
      record = null;
    }
    if (_held != null) return _current;
    if (record == null || record.issuer != issuer || (_o.audience != null && record.audience != _o.audience)) {
      _publishStatus(AuthStatus.anonymous);
      return _current;
    }
    final expiresAt = DateTime.tryParse(record.refreshExpiresAt)?.millisecondsSinceEpoch;
    if (expiresAt == null || _clock() >= expiresAt) {
      await _removeRecord();
      _dropCredentials(AuthStatus.expired);
      return _current;
    }
    _generation++;
    _held = _Held(
      accessToken: null,
      claims: null,
      refreshToken: record.refreshToken,
      refreshExpiresAt: expiresAt,
      sessionId: record.sessionId,
      audience: record.audience,
      rotationAnchorMs: 0,
      rotationIntervalMs: 0,
    );
    try {
      await refresh();
    } catch (_) {
      // The status says what happened: expired, or error with a retry scheduled.
    }
    return _current;
  }

  /// Loads the stored record and refreshes. On web, on the callback URL, runs
  /// [handleRedirect] first (rejecting with its error). Resolves with the
  /// session (`authenticated`, `anonymous`, `expired`, or `error` with a retry
  /// scheduled).
  Future<PublicSession> restore() async {
    _purgeTransactions();
    final here = browser.currentUrl();
    if (here != null) {
      final u = Uri.tryParse(here);
      if (u != null && _isCallback(u)) {
        await handleRedirect();
      }
    }
    return _restoreStored();
  }

  // ---------------------------------------------------------------------------
  // Passkeys
  // ---------------------------------------------------------------------------

  AxiomPasskeys _passkeys() {
    final p = _o.passkeys;
    if (p == null) throw AxiomAuthError('webauthn', 0);
    return p;
  }

  Future<Map<String, Object?>> _assertion(Object? options) async {
    final o = _rec(options);
    if (o == null) throw AxiomAuthError('webauthn', 0);
    try {
      return await _passkeys().get(o);
    } on AxiomAuthError {
      rethrow;
    } catch (_) {
      throw AxiomAuthError('webauthn', 0);
    }
  }

  Future<Map<String, Object?>> _attestation(Object? options) async {
    final o = _rec(options);
    if (o == null) throw AxiomAuthError('webauthn', 0);
    try {
      return await _passkeys().create(o);
    } on AxiomAuthError {
      rethrow;
    } catch (_) {
      throw AxiomAuthError('webauthn', 0);
    }
  }

  ({String challenge, Object? options}) _ceremony(Object? data) {
    final d = _rec(data);
    if (d == null || d['challenge'] is! String || _rec(d['options']) == null) throw AxiomAuthError('unavailable', 0);
    return (challenge: d['challenge'] as String, options: d['options']);
  }

  Future<String> _bearer() async {
    final t = await accessToken();
    if (t == null) throw AxiomAuthError('invalid_token', 0);
    return t;
  }

  Future<({String? token, _Pending? ticket})> _enrollActor() async {
    final p = _livePending('enroll');
    if (_held == null && p != null) return (token: null, ticket: p);
    return (token: await _bearer(), ticket: null);
  }

  Future<({Factor? factor, List<String>? recoveryCodes})> _confirmation(Object? data) async {
    final d = _rec(data);
    if (d == null) throw AxiomAuthError('unavailable', 0);
    final factor = Factor.tryParse(d['factor']);
    final codes = _strings(d['recovery_codes']);
    if (_rec(d['tokens']) != null) await _establish(d['tokens']);
    return (factor: factor, recoveryCodes: codes);
  }

  // ---------------------------------------------------------------------------
  // Public API (auth-surfaces/v1)
  // ---------------------------------------------------------------------------

  Future<AuthUser?> user() async {
    final token = await accessToken();
    if (token == null) return null;
    final d = _rec(await _plain('GET', '/v1/user', null, token));
    if (d == null || d['id'] is! String || (d['kind'] != 'password' && d['kind'] != 'external')) {
      throw AxiomAuthError('unavailable', 0);
    }
    final providers = <String>[];
    if (d['identities'] is List) {
      for (final i in d['identities'] as List) {
        final p = _rec(i)?['provider'];
        if (p is String && !providers.contains(p)) providers.add(p);
      }
    }
    return AuthUser(
      id: d['id'] as String,
      kind: d['kind'] as String,
      email: d['email'] is String ? d['email'] as String : null,
      emailVerified: d['email_verified'] == true,
      hasPassword: d['has_password'] == true,
      providers: providers,
    );
  }

  Future<SignUpResult> signUp(String email, String password, {String? captchaToken}) async {
    final d = _rec(await _firstFactor('/v1/signup', _withAudience(_captcha({'email': email, 'password': password}, captchaToken))));
    if (d != null && d['access_token'] is String) {
      await _establish(d);
      return const SignUpResult(status: 'signed_in');
    }
    if (d == null || d['challenge_id'] is! String) throw AxiomAuthError('unavailable', 0);
    return SignUpResult(
      status: 'verification_sent',
      challenge: d['challenge_id'] as String,
      resendAfterSeconds: d['resend_after'] is num ? (d['resend_after'] as num).toInt() : null,
    );
  }

  Future<PublicSession> verifySignUp(String challenge, String code) async =>
      _establish(await _firstFactor('/v1/signup/verify', _withAudience({'challenge_id': challenge, 'code': code})));

  Future<PublicSession> signInWithPassword(String email, String password, {String? tenant, String? captchaToken}) async {
    final body = _captcha({'email': email, 'password': password}, captchaToken);
    if (tenant != null) body['tenant'] = tenant;
    return _establish(await _firstFactor('/v1/sign-in/password', _withAudience(body)));
  }

  Future<EmailCodeChallenge> requestEmailCode(String email, {String? captchaToken}) async {
    final d = _rec(await _plain('POST', '/v1/email/code', _captcha({'email': email}, captchaToken)));
    if (d == null || d['challenge_id'] is! String) throw AxiomAuthError('unavailable', 0);
    return EmailCodeChallenge(
      challenge: d['challenge_id'] as String,
      resendAfterSeconds: d['resend_after'] is num ? (d['resend_after'] as num).toInt() : 60,
    );
  }

  Future<PublicSession> verifyEmailCode(String challenge, String code) async =>
      _establish(await _firstFactor('/v1/email/code/verify', _withAudience({'challenge_id': challenge, 'code': code})));

  /// Sends a magic link to [email]. The link lands on `redirectUri`
  /// (`#axiom_link`); complete it with [handleRedirect] from the app link
  /// handler (mobile) or [restore] (web). The PKCE verifier stays in process
  /// memory, so the link must be opened before the app is killed.
  Future<void> requestMagicLink(String email, {String? returnTo, String? captchaToken}) async {
    final t = _beginTransaction('magic_link', null, returnTo);
    try {
      await _plain('POST', '/v1/email/link', _captcha({
        'email': email,
        'redirect_uri': t.tx.redirectUri,
        'state': t.tx.state,
        'code_challenge': t.challenge,
        'code_challenge_method': 'S256',
      }, captchaToken));
    } catch (_) {
      _transactions.remove(t.tx.state);
      rethrow;
    }
  }

  /// Provider sign-in (Google, GitHub, OIDC; `local` on the emulator) with
  /// PKCE. Unlike auth-web (which navigates away and never resolves) this
  /// opens the system browser through the launcher and completes with the
  /// session. [loginHint] is passed to the provider (additive).
  Future<PublicSession> signInWithProvider(String provider, {String? returnTo, String? loginHint}) async {
    if (provider.isEmpty) throw AxiomAuthError('invalid_request', 0);
    final t = _beginTransaction('provider', provider, returnTo);
    return _runRedirect(
        _startUrl('/v1/providers/${Uri.encodeComponent(provider)}/start', t.tx, t.challenge,
            {if (loginHint != null) 'login_hint': loginHint}),
        t.tx);
  }

  /// Hosted sign-in page (`/sign-in`) with PKCE, through the launcher.
  /// [screen] is `sign_in` or `sign_up`.
  Future<PublicSession> signInHosted({String? returnTo, String? screen}) async {
    if (screen != null && screen != 'sign_in' && screen != 'sign_up') throw AxiomAuthError('invalid_request', 0);
    final t = _beginTransaction('hosted', null, returnTo);
    return _runRedirect(_startUrl('/sign-in', t.tx, t.challenge, {if (screen != null) 'screen': screen}), t.tx);
  }

  /// Ends the session: drops credentials and the stored record at once, then
  /// revokes the refresh token on the issuer (`/v1/logout`, or
  /// `/v1/logout-all` with [everywhere]). With [redirect] and a `logoutUri`
  /// the issuer's logout page is opened afterwards.
  Future<PublicSession> signOut({bool everywhere = false, bool redirect = false, String? returnTo}) async {
    await _awaitInflight();
    var refreshToken = _held?.refreshToken;
    if (refreshToken == null) {
      // A stored record not yet restored is revoked, not merely forgotten.
      try {
        final stored = await _storage.get(_storageKey);
        if (stored != null && stored.issuer == issuer) refreshToken = stored.refreshToken;
      } catch (_) {}
    }
    _pending = null;
    _dropCredentials(AuthStatus.anonymous);
    await _removeRecord();
    if (refreshToken != null) {
      final path = everywhere ? '/v1/logout-all' : '/v1/logout';
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await _plain('POST', path, {'refresh_token': refreshToken});
          break;
        } catch (e) {
          if (e is! AxiomAuthError || e.status != 0) break;
        }
      }
    }
    final logoutUri = _o.logoutUri;
    if (redirect && logoutUri != null) {
      final u = Uri.parse('$issuer/v1/logout').replace(queryParameters: {
        'post_logout_redirect_uri': logoutUri,
        'state': _randomToken(),
      });
      if (browser.isWeb) {
        browser.assignUrl(u.toString());
      } else {
        try {
          await _launcher().authenticate(u, callbackUrlScheme: Uri.parse(logoutUri).scheme);
        } catch (_) {
          // The local session is already gone.
        }
      }
    }
    return _current;
  }

  Future<void> changePassword(String current, String next) async {
    final token = await accessToken();
    if (token == null) throw AxiomAuthError('invalid_token', 0);
    await _plain('POST', '/v1/password', {'current_password': current, 'new_password': next}, token);
  }

  Future<void> requestPasswordReset(String email, {String? captchaToken}) async {
    final body = _captcha({'email': email}, captchaToken);
    if (_o.redirectUri != null) body['redirect_uri'] = _o.redirectUri;
    await _plain('POST', '/v1/password/reset', body);
  }

  /// Uses the token captured from `#axiom_reset` by [handleRedirect].
  Future<void> confirmPasswordReset(String password) async {
    final token = _resetToken;
    if (token == null) throw AxiomAuthError('invalid_code', 0);
    try {
      await _plain('POST', '/v1/password/reset/confirm', {'token': token, 'new_password': password});
    } catch (e) {
      if (e is! AxiomAuthError || e.code != 'weak_password') _resetToken = null;
      rethrow;
    }
    _resetToken = null;
  }

  /// Accepts the invitation captured from `#axiom_invitation`.
  Future<PublicSession> acceptInvitation({String? password, String? tenant}) async {
    final token = _invitationToken;
    if (token == null) throw AxiomAuthError('invalid_code', 0);
    final body = <String, Object?>{'token': token};
    if (password != null) body['password'] = password;
    if (tenant != null) body['tenant'] = tenant;
    Object? data;
    try {
      data = await _firstFactor('/v1/invitations/accept', _withAudience(body));
    } catch (e) {
      if (e is! AxiomAuthError || e.code != 'weak_password') _invitationToken = null;
      rethrow;
    }
    _invitationToken = null;
    return _establish(data);
  }

  Future<PublicSession> selectTenant(String? tenant) => refresh(tenant: tenant);

  bool _tokenOrigin(Uri url) {
    if (!url.hasScheme) return browser.isWeb; // relative URL on web: the page origin
    String origin;
    try {
      origin = url.origin;
    } catch (_) {
      return false;
    }
    return origin == browser.pageOrigin() || _apiOrigins.contains(origin);
  }

  /// `authorizedFetch` for package:http: sends [request] with the bearer when
  /// its origin is an [AxiomAuthOptions.apiOrigins] entry (or the page origin
  /// on web). On `401 authorization_changed` refreshes once and retries once
  /// (bodies of `StreamedRequest` are not replayed). Other responses, including
  /// `401 step_up_required`, are returned as they are.
  Future<http.StreamedResponse> authorizedSend(http.BaseRequest request, {http.Client? inner}) async {
    final client = inner ?? _http;
    if (!_tokenOrigin(request.url)) return client.send(request);
    final replayable = request is http.Request;
    final first = await accessToken();
    http.BaseRequest build(String? token, bool copy) {
      final r = copy && request is http.Request ? _copy(request) : request;
      if (token != null) {
        r.headers['Authorization'] = 'Bearer $token';
      } else {
        r.headers.remove('Authorization');
      }
      return r;
    }

    final response = await client.send(build(first, replayable));
    if (response.statusCode != 401 || first == null || !replayable) return response;
    final buffered = await http.Response.fromStream(response);
    final changed = RegExp(r'error_description="authorization_changed"').hasMatch(buffered.headers['www-authenticate'] ?? '') ||
        runtimeAuthRefusal(buffered.body)?.code == 'authorization_changed';
    http.StreamedResponse replay() => http.StreamedResponse(Stream.value(buffered.bodyBytes), buffered.statusCode,
        headers: buffered.headers, reasonPhrase: buffered.reasonPhrase, request: buffered.request);
    if (!changed) return replay();
    try {
      await refresh();
    } catch (_) {
      return replay();
    }
    final h = _held;
    final second = h != null && h.accessToken != null && h.claims != null && _clock() < h.claims!.exp * 1000 ? h.accessToken : null;
    if (second == null || second == first) return replay();
    return client.send(build(second, true));
  }

  static http.Request _copy(http.Request r) {
    final c = http.Request(r.method, r.url)
      ..followRedirects = r.followRedirects
      ..maxRedirects = r.maxRedirects
      ..persistentConnection = r.persistentConnection
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return c;
  }

  /// An `http.Client` that runs every request through [authorizedSend].
  http.Client authorizedClient([http.Client? inner]) => _AuthorizedClient(this, inner ?? http.Client());

  /// What `jsonEncode(auth)` shows; never a token.
  Map<String, Object?> toJson() => {'issuer': issuer, 'session': _current.toJson()};

  @override
  String toString() => 'AxiomAuth($issuer, ${_current.status.name})';

  // ---------------------------------------------------------------------------
  // auth-advanced/v1 17.1: MFA, passkeys, step-up
  // ---------------------------------------------------------------------------

  /// Null when none or after 300 s.
  MfaChallenge? mfaChallenge() => _livePending(null)?.challenge;

  Future<PublicSession> verifyMfa(String factorId, String code) async {
    final p = _livePending('mfa');
    if (p == null) throw AxiomAuthError('mfa_required', 0);
    return _establish(await _plain('POST', '/v1/mfa/verify', _ticketBody(p, {'factor_id': factorId, 'code': code}, true)));
  }

  Future<PublicSession> verifyRecoveryCode(String code) async {
    final p = _livePending('mfa');
    if (p == null) throw AxiomAuthError('mfa_required', 0);
    return _establish(await _plain('POST', '/v1/mfa/verify', _ticketBody(p, {'recovery_code': code}, true)));
  }

  Future<int> sendSmsCode(String factorId) async {
    final p = _livePending('mfa');
    if (p == null) throw AxiomAuthError('mfa_required', 0);
    final d = _rec(await _plain('POST', '/v1/mfa/sms/send', _ticketBody(p, {'factor_id': factorId}, false)));
    return d != null && d['resend_after'] is num ? (d['resend_after'] as num).toInt() : 60;
  }

  Future<PublicSession> verifyMfaWithPasskey() async {
    final p = _livePending('mfa');
    if (p == null) throw AxiomAuthError('mfa_required', 0);
    final c = _ceremony(await _plain('POST', '/v1/mfa/webauthn/options', _ticketBody(p, {}, false)));
    final credential = await _assertion(c.options);
    return _establish(await _plain('POST', '/v1/mfa/webauthn/verify', _ticketBody(p, {'challenge': c.challenge, 'credential': credential}, true)));
  }

  Future<PublicSession> signInWithPasskey({String? tenant}) async {
    _pending = null;
    final c = _ceremony(await _plain('POST', '/v1/passkeys/options', {}));
    final credential = await _assertion(c.options);
    final body = <String, Object?>{'challenge': c.challenge, 'credential': credential};
    if (tenant != null) body['tenant'] = tenant;
    return _establish(await _plain('POST', '/v1/sign-in/passkey', _withAudience(body)));
  }

  /// Reauthenticates the current session (`POST /v1/reauthenticate`) and
  /// rotates its tokens; never runs beside a refresh. [factorId] selects a TOTP
  /// or SMS factor; without it the user's one active factor of that type is used.
  Future<PublicSession> stepUp({required StepUpMethod method, Acr? acr, String? password, String? code, String? factorId}) {
    if (_held == null) return Future.error(AxiomAuthError('invalid_token', 0));
    return _reauthenticate((presented, token) async {
      final body = <String, Object?>{'refresh_token': presented.refreshToken, 'method': method.name};
      if (acr != null) body['acr'] = acr.name;
      switch (method) {
        case StepUpMethod.password:
          if (password == null) throw AxiomAuthError('invalid_request', 0);
          body['password'] = password;
        case StepUpMethod.recovery:
          if (code == null) throw AxiomAuthError('invalid_request', 0);
          body['recovery_code'] = code;
        case StepUpMethod.passkey:
          final c = _ceremony(await _plain('POST', '/v1/reauthenticate/webauthn/options', {}, token));
          body['challenge'] = c.challenge;
          body['credential'] = await _assertion(c.options);
        case StepUpMethod.totp:
        case StepUpMethod.sms:
          if (code == null) throw AxiomAuthError('invalid_request', 0);
          var fid = factorId;
          if (fid == null) {
            final d = _rec(await _plain('GET', '/v1/factors', null, token));
            final list = d != null && d['factors'] is List ? d['factors'] as List : const [];
            final matches = list.map(_rec).where((f) =>
                f != null && f['type'] == method.name && f['status'] == 'active' && f['usable'] != false && f['id'] is String).toList();
            if (matches.length != 1) throw AxiomAuthError('invalid_request', 0);
            fid = matches.first!['id'] as String;
          }
          body['factor_id'] = fid;
          body['code'] = code;
      }
      if (_o.audience != null) body['audience'] = _o.audience;
      return _plain('POST', '/v1/reauthenticate', body, token);
    });
  }

  Future<FactorList> listFactors() async {
    final d = _rec(await _plain('GET', '/v1/factors', null, await _bearer()));
    if (d == null || d['factors'] is! List) throw AxiomAuthError('unavailable', 0);
    return FactorList(
      factors: (d['factors'] as List).map(Factor.tryParse).whereType<Factor>().toList(),
      recoveryCodesRemaining: d['recovery_codes_remaining'] is num ? (d['recovery_codes_remaining'] as num).toInt() : 0,
      maskedPhone: _rec(d['phone'])?['masked'] is String ? _rec(d['phone'])!['masked'] as String : null,
    );
  }

  /// With a session, or the enroll ticket of an enrollment-required sign-in.
  Future<TotpEnrollment> enrollTotp(String label) async {
    final a = await _enrollActor();
    final body = a.ticket != null ? _ticketBody(a.ticket!, {'label': label}, false) : <String, Object?>{'label': label};
    final d = _rec(await _plain('POST', '/v1/factors/totp', body, a.token));
    if (d == null || d['factor_id'] is! String || d['secret'] is! String || d['otpauth_uri'] is! String) {
      throw AxiomAuthError('unavailable', 0);
    }
    return TotpEnrollment(factorId: d['factor_id'] as String, secret: d['secret'] as String, otpauthUri: d['otpauth_uri'] as String);
  }

  static final _uuid = RegExp(r'^[0-9a-f-]{36}$');

  /// Completes an enrollment-required sign-in when the server returns tokens.
  /// Recovery codes are returned once and never cached.
  Future<List<String>?> confirmTotp(String factorId, String code) async {
    if (!_uuid.hasMatch(factorId)) throw AxiomAuthError('invalid_request', 0);
    final a = await _enrollActor();
    final body = a.ticket != null ? _ticketBody(a.ticket!, {'code': code}, false) : <String, Object?>{'code': code};
    final out = await _confirmation(await _plain('POST', '/v1/factors/totp/${Uri.encodeComponent(factorId)}/confirm', body, a.token));
    return out.recoveryCodes;
  }

  Future<Factor> registerPasskey(String label) async {
    final a = await _enrollActor();
    final ob = a.ticket != null ? _ticketBody(a.ticket!, {'label': label}, false) : <String, Object?>{'label': label};
    final c = _ceremony(await _plain('POST', '/v1/factors/passkeys/options', ob, a.token));
    final credential = await _attestation(c.options);
    final body = <String, Object?>{'challenge': c.challenge, 'label': label, 'credential': credential};
    if (a.ticket != null) _ticketBody(a.ticket!, body, false);
    final out = await _confirmation(await _plain('POST', '/v1/factors/passkeys', body, a.token));
    if (out.factor == null) throw AxiomAuthError('unavailable', 0);
    return out.factor!.withRecoveryCodes(out.recoveryCodes);
  }

  Future<void> removeFactor(String factorId) async {
    if (!_uuid.hasMatch(factorId)) throw AxiomAuthError('invalid_request', 0);
    await _plain('DELETE', '/v1/factors/${Uri.encodeComponent(factorId)}', null, await _bearer());
  }

  Future<List<String>> regenerateRecoveryCodes() async {
    final codes = _strings(_rec(await _plain('POST', '/v1/recovery-codes', {}, await _bearer()))?['recovery_codes']);
    if (codes == null) throw AxiomAuthError('unavailable', 0);
    return codes;
  }

  Future<String> addPhone(String phone, {String? captchaToken}) async {
    final d = _rec(await _plain('POST', '/v1/phone', _captcha({'phone': phone}, captchaToken), await _bearer()));
    if (d == null || d['challenge_id'] is! String) throw AxiomAuthError('unavailable', 0);
    return d['challenge_id'] as String;
  }

  Future<void> verifyPhone(String challengeId, String code) async {
    await _plain('POST', '/v1/phone/verify', {'challenge_id': challengeId, 'code': code}, await _bearer());
  }

  Future<Factor> enableSmsFactor() async {
    final f = Factor.tryParse(_rec(await _plain('POST', '/v1/factors/sms', {}, await _bearer()))?['factor']);
    if (f == null) throw AxiomAuthError('unavailable', 0);
    return f;
  }

  Future<List<Consent>> listConsents() async {
    final d = _rec(await _plain('GET', '/v1/consents', null, await _bearer()));
    if (d == null || d['consents'] is! List) throw AxiomAuthError('unavailable', 0);
    final out = <Consent>[];
    for (final c in d['consents'] as List) {
      final r = _rec(c);
      if (r != null && r['client_id'] is String && r['name'] is String) {
        out.add(Consent(clientId: r['client_id'] as String, name: r['name'] as String, scopes: _strings(r['scopes']) ?? []));
      }
    }
    return out;
  }

  Future<void> revokeConsent(String clientId) async {
    if (!RegExp(r'^axcl_[A-Za-z0-9_-]{22}$').hasMatch(clientId)) throw AxiomAuthError('invalid_request', 0);
    await _plain('DELETE', '/v1/consents/$clientId', null, await _bearer());
  }

  /// Cancels timers and drops listeners. The stored record is kept.
  void dispose() {
    _cancelTimer();
    _listeners.clear();
    _tokenSinks.clear();
  }
}

class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._auth, this._inner);
  final AxiomAuth _auth;
  final http.Client _inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _auth.authorizedSend(request, inner: _inner);
  @override
  void close() => _inner.close();
}
