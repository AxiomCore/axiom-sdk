// Public types of axiom_flutter_auth. Names follow @axiomcore/auth-web
// (auth-surfaces/v1 "Web client") so the two clients read the same.

/// Status of the client's session projection.
enum AuthStatus {
  unknown,
  loading,
  error,
  anonymous,
  authenticated,
  expired,
  refreshing,
}

/// Authentication assurance level of the access token (auth-advanced/v1 7.1).
enum Acr {
  aal1,
  aal2,
  phr;

  /// Rank used for comparisons: aal1 < aal2 < phr.
  int get rank => index + 1;

  static Acr? tryParse(Object? value) {
    for (final a in Acr.values) {
      if (a.name == value) return a;
    }
    return null;
  }
}

List<String> _frozen(List<String> list) => List<String>.unmodifiable(list);

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The signed-in principal, decoded from the access token for display only.
class PublicPrincipal {
  PublicPrincipal({
    required this.subject,
    required this.tenant,
    required List<String> roles,
    required List<String> permissions,
  })  : roles = _frozen(roles),
        permissions = _frozen(permissions);

  final String subject;
  final String? tenant;
  final List<String> roles;
  final List<String> permissions;

  bool sameAs(PublicPrincipal other) =>
      subject == other.subject &&
      tenant == other.tenant &&
      _sameList(roles, other.roles) &&
      _sameList(permissions, other.permissions);

  Map<String, Object?> toJson() => {
        'subject': subject,
        'tenant': tenant,
        'roles': roles,
        'permissions': permissions,
      };

  @override
  String toString() => 'PublicPrincipal($subject, tenant: $tenant)';
}

/// What app code sees of the session. Never holds a token.
///
/// The [principal] object is reused while its content is unchanged, so
/// `!identical(s.principal, last.principal)` detects a real change.
class PublicSession {
  const PublicSession({
    required this.id,
    required this.status,
    required this.principal,
    this.acr = Acr.aal1,
    this.authTime = 0,
  });

  static const PublicSession initial =
      PublicSession(id: '', status: AuthStatus.unknown, principal: null);

  final String id;
  final AuthStatus status;
  final PublicPrincipal? principal;

  /// `acr` of the access token; [Acr.aal1] while signed out.
  final Acr acr;

  /// `auth_time` of the access token (epoch seconds); 0 while signed out.
  final int authTime;

  bool get isAuthenticated => status == AuthStatus.authenticated ||
      (status == AuthStatus.refreshing && principal != null);

  bool sameAs(PublicSession o) =>
      id == o.id &&
      status == o.status &&
      identical(principal, o.principal) &&
      acr == o.acr &&
      authTime == o.authTime;

  Map<String, Object?> toJson() => {
        'id': id,
        'status': status.name,
        'principal': principal?.toJson(),
        'acr': acr.name,
        'authTime': authTime,
      };

  @override
  String toString() => 'PublicSession(${status.name}, id: $id, '
      'subject: ${principal?.subject}, acr: ${acr.name})';
}

/// A factor offered by an MFA challenge.
class MfaFactor {
  const MfaFactor({required this.id, required this.type, required this.label});
  final String id;

  /// `totp`, `passkey` or `sms`.
  final String type;
  final String label;
  @override
  String toString() => 'MfaFactor($type, $label)';
}

/// Set after `mfa_required` or `mfa_enrollment_required`; the ticket stays
/// private inside the client. Redirect completions carry no factor list
/// ([factors] is empty).
class MfaChallenge {
  const MfaChallenge({
    required this.factors,
    required this.recoveryCodes,
    this.enrollmentTypes,
  });
  final List<MfaFactor> factors;
  final bool recoveryCodes;

  /// Non-null for an enrollment-required sign-in: the factor types allowed.
  final List<String>? enrollmentTypes;
}

class Factor {
  const Factor({
    required this.id,
    required this.type,
    required this.label,
    required this.status,
    required this.createdAt,
    this.lastUsedOn,
    this.recoveryCodes,
  });
  final String id;
  final String type;
  final String label;

  /// `pending` or `active`.
  final String status;
  final String createdAt;
  final String? lastUsedOn;

  /// Only from [AxiomAuth.registerPasskey]; shown once, never kept.
  final List<String>? recoveryCodes;

  static const _types = {'totp', 'passkey', 'sms'};

  static Factor? tryParse(Object? v) {
    if (v is! Map ||
        v['id'] is! String ||
        !_types.contains(v['type']) ||
        v['label'] is! String ||
        (v['status'] != 'pending' && v['status'] != 'active')) {
      return null;
    }
    return Factor(
      id: v['id'] as String,
      type: v['type'] as String,
      label: v['label'] as String,
      status: v['status'] as String,
      createdAt: v['created_at'] is String ? v['created_at'] as String : '',
      lastUsedOn: v['last_used_on'] is String ? v['last_used_on'] as String : null,
    );
  }

  Factor withRecoveryCodes(List<String>? codes) => Factor(
        id: id,
        type: type,
        label: label,
        status: status,
        createdAt: createdAt,
        lastUsedOn: lastUsedOn,
        recoveryCodes: codes,
      );
}

/// Trusted UI memory only: show the secret or QR code once, never store or log it.
class TotpEnrollment {
  const TotpEnrollment({required this.factorId, required this.secret, required this.otpauthUri});
  final String factorId;
  final String secret;
  final String otpauthUri;
  @override
  String toString() => 'TotpEnrollment($factorId)';
}

enum StepUpMethod { password, totp, sms, recovery, passkey }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.kind,
    this.email,
    required this.emailVerified,
    required this.hasPassword,
    required this.providers,
  });
  final String id;

  /// `password` or `external`.
  final String kind;
  final String? email;
  final bool emailVerified;
  final bool hasPassword;
  final List<String> providers;
}

/// Error of every client call. [code] is the mechanical name (`AXAUTH_FOO_BAR`
/// becomes `foo_bar`; unknown codes and network failures become `unavailable`).
class AxiomAuthError implements Exception {
  AxiomAuthError(this.code, [this.status = 0, this.retryAfterSeconds]);

  final String code;

  /// HTTP status, or 0 for client-side and network outcomes.
  final int status;
  final int? retryAfterSeconds;

  String get message => code;

  @override
  String toString() => 'AxiomAuthError($code'
      '${status != 0 ? ', status: $status' : ''}'
      '${retryAfterSeconds != null ? ', retryAfter: ${retryAfterSeconds}s' : ''})';
}

/// What the storage adapter holds: only the refresh record, never the access token.
class RefreshRecord {
  const RefreshRecord({
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.issuer,
    required this.audience,
    required this.sessionId,
  });
  final String refreshToken;

  /// ISO 8601.
  final String refreshExpiresAt;
  final String issuer;
  final String audience;
  final String sessionId;

  Map<String, String> toJson() => {
        'refreshToken': refreshToken,
        'refreshExpiresAt': refreshExpiresAt,
        'issuer': issuer,
        'audience': audience,
        'sessionId': sessionId,
      };

  static RefreshRecord? tryParse(Object? v) {
    if (v is! Map) return null;
    final r = v['refreshToken'], e = v['refreshExpiresAt'], i = v['issuer'], a = v['audience'], s = v['sessionId'];
    if (r is! String || e is! String || i is! String || a is! String || s is! String) return null;
    return RefreshRecord(refreshToken: r, refreshExpiresAt: e, issuer: i, audience: a, sessionId: s);
  }

  @override
  String toString() => 'RefreshRecord(session: $sessionId)';
}

/// Result of [AxiomAuth.handleRedirect].
class RedirectResult {
  const RedirectResult({required this.handled, this.returnTo, this.invitation = false});
  final bool handled;

  /// Validated same-app path to route to; null when the signed-in route applies.
  final String? returnTo;
  final bool invitation;
  @override
  String toString() => 'RedirectResult(handled: $handled, returnTo: $returnTo)';
}

/// Result of [AxiomAuth.signUp].
class SignUpResult {
  const SignUpResult({required this.status, this.challenge, this.resendAfterSeconds});

  /// `signed_in` or `verification_sent`.
  final String status;
  final String? challenge;
  final int? resendAfterSeconds;
}

class EmailCodeChallenge {
  const EmailCodeChallenge({required this.challenge, required this.resendAfterSeconds});
  final String challenge;
  final int resendAfterSeconds;
}

class FactorList {
  const FactorList({required this.factors, required this.recoveryCodesRemaining, this.maskedPhone});
  final List<Factor> factors;
  final int recoveryCodesRemaining;
  final String? maskedPhone;
}

class Consent {
  const Consent({required this.clientId, required this.name, required this.scopes});
  final String clientId;
  final String name;
  final List<String> scopes;
}

/// RFC 9470 step-up challenge or the runtime's refusal body.
class StepUpChallenge {
  const StepUpChallenge({this.acr, this.maxAge});
  final Acr? acr;
  final int? maxAge;
}

/// The Acore runtime's refusal (`authorization_changed`, `step_up_required`).
class RuntimeAuthRefusal {
  const RuntimeAuthRefusal(this.code, {this.acr, this.maxAge});

  /// `authorization_changed` or `step_up_required`.
  final String code;
  final Acr? acr;
  final int? maxAge;
}
