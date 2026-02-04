/// Mirrors Rust's ErrorStage
enum ErrorStage {
  configuration,
  contractLoad,
  requestBuild,
  validationRequest,
  cacheRead,
  networkSend,
  networkReceive,
  validationResponse,
  deserialize,
  cacheWrite,
  runtime,
  ffiBoundary;

  static ErrorStage fromString(String val) => ErrorStage.values.firstWhere(
    (e) => e.name.toLowerCase() == val.toLowerCase(),
    orElse: () => ErrorStage.runtime,
  );
}

/// Mirrors Rust's ErrorCategory
enum ErrorCategory {
  contract,
  validation,
  network,
  timeout,
  serialization,
  cache,
  auth,
  server,
  runtime,
  unknown;

  static ErrorCategory fromString(String val) =>
      ErrorCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == val.toLowerCase(),
        orElse: () => ErrorCategory.unknown,
      );
}

/// Typed Error Codes using Dart 3 Sealed Classes
sealed class AxiomErrorCode {
  const AxiomErrorCode();

  factory AxiomErrorCode.fromJson(dynamic json) {
    if (json is String) {
      return switch (json) {
        'ContractMissing' => const ContractMissing(),
        'ContractInvalid' => const ContractInvalid(),
        'EndpointNotFound' => const EndpointNotFound(),
        'ValidationError' => const ValidationError(),
        'NetworkTimeout' => const NetworkTimeout(),
        'NetworkConnectionFailed' => const NetworkConnectionFailed(),
        'JsonParseError' => const JsonParseError(),
        'CodecError' => const CodecError(),
        'AuthTokenExpired' => const AuthTokenExpired(),
        'NotInitialized' => const NotInitialized(),
        _ => UnknownCode(json),
      };
    } else if (json is Map && json.containsKey('HttpStatus')) {
      return HttpStatus(json['HttpStatus'] as int);
    }
    return UnknownCode(json.toString());
  }
}

class ContractMissing extends AxiomErrorCode {
  const ContractMissing();
}

class ContractInvalid extends AxiomErrorCode {
  const ContractInvalid();
}

class EndpointNotFound extends AxiomErrorCode {
  const EndpointNotFound();
}

class ValidationError extends AxiomErrorCode {
  const ValidationError();
}

class NetworkTimeout extends AxiomErrorCode {
  const NetworkTimeout();
}

class NetworkConnectionFailed extends AxiomErrorCode {
  const NetworkConnectionFailed();
}

class JsonParseError extends AxiomErrorCode {
  const JsonParseError();
}

class CodecError extends AxiomErrorCode {
  const CodecError();
}

class AuthTokenExpired extends AxiomErrorCode {
  const AuthTokenExpired();
}

class NotInitialized extends AxiomErrorCode {
  const NotInitialized();
}

class HttpStatus extends AxiomErrorCode {
  final int code;
  const HttpStatus(this.code);
}

class UnknownCode extends AxiomErrorCode {
  final String raw;
  const UnknownCode(this.raw);
}

/// The main rich error object that is deserialized from Rust.
class AxiomError {
  final ErrorStage stage;
  final ErrorCategory category;
  final AxiomErrorCode code;
  final String message;
  final bool retryable;
  final String? details;

  AxiomError({
    required this.stage,
    required this.category,
    required this.code,
    required this.message,
    required this.retryable,
    this.details,
  });

  factory AxiomError.fromJson(Map<String, dynamic> json) {
    return AxiomError(
      stage: ErrorStage.fromString(json['stage']),
      category: ErrorCategory.fromString(json['category']),
      code: AxiomErrorCode.fromJson(json['code']),
      message: json['message'],
      retryable: json['retryable'] ?? false,
      details: json['details'],
    );
  }

  @override
  String toString() {
    return '[$stage::$category] $message (Code: $code)';
  }
}

// --- Main State Class ---

enum AxiomStatus { loading, success, error }

enum AxiomSource { none, cache, network }

class AxiomState<T> {
  final AxiomStatus status;
  final T? data;
  final AxiomError? error; // UPDATED: Changed from Object? to AxiomError?
  final AxiomSource source;
  final bool isFetching;

  const AxiomState._({
    required this.status,
    this.data,
    this.error,
    this.source = AxiomSource.none,
    this.isFetching = false,
  });

  AxiomState<R> map<R>(R Function(T data) mapper) {
    return AxiomState._(
      status: status,
      data: data != null ? mapper(data!) : null,
      error: error,
      source: source,
      isFetching: isFetching,
    );
  }

  /// Initial loading state
  factory AxiomState.loading() =>
      const AxiomState._(status: AxiomStatus.loading, isFetching: true);

  /// Success state (from cache or network)
  factory AxiomState.success(
    T data,
    AxiomSource source, {
    bool isFetching = false,
  }) => AxiomState._(
    status: AxiomStatus.success,
    data: data,
    source: source,
    isFetching: isFetching,
  );

  /// Error state
  // UPDATED: Factory now requires a typed AxiomError
  factory AxiomState.error(
    AxiomError error, {
    T? previousData,
    AxiomSource? previousSource,
  }) => AxiomState._(
    status: AxiomStatus.error,
    error: error,
    data: previousData, // Keep showing old data if available
    source: previousSource ?? AxiomSource.none,
    isFetching: false,
  );

  bool get isLoading => status == AxiomStatus.loading;
  bool get hasError => status == AxiomStatus.error;
  bool get hasData => data != null;

  @override
  String toString() {
    return 'AxiomState<$T>(status: ${status.name}, source: ${source.name}, isFetching: $isFetching, hasData: ${data != null}, hasError: ${error != null})';
  }
}
