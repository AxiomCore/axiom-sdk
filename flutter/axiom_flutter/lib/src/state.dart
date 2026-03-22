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
// FILE: lib/src/state.dart (Partial Replacement)

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

  /// NEW: The Magic Zero-Dart Validation Parser
  /// Extracts field-specific errors from the Rust rod-rs schema validator.
  String? getFieldError(String fieldName) {
    if (code is! ValidationError || details == null) return null;

    // Rust rod-rs formats errors as: "path.to.field: Error message\nanother.field: Error message"
    final lines = details!.split('\n');
    for (final line in lines) {
      if (line.startsWith('$fieldName:')) {
        return line.substring(fieldName.length + 1).trim();
      }
    }
    return null;
  }

  @override
  String toString() => '[$stage::$category] $message (Code: $code)';
}

enum AxiomStatus { idle, loading, success, error } // Added 'idle'

enum AxiomSource { none, cache, network }

class AxiomState<T> {
  final AxiomStatus status;
  final T? data;
  final AxiomError? error;
  final AxiomSource source;
  final bool isFetching;
  final bool isMutating; // NEW: Differentiates Forms from Background Syncs

  const AxiomState({
    required this.status,
    this.data,
    this.error,
    this.source = AxiomSource.none,
    this.isFetching = false,
    this.isMutating = false,
  });

  AxiomState<R> map<R>(R Function(T data) mapper) {
    return AxiomState<R>(
      status: status,
      data: data != null ? mapper(data!) : null,
      error: error,
      source: source,
      isFetching: isFetching,
      isMutating: isMutating,
    );
  }

  factory AxiomState.idle() => const AxiomState(status: AxiomStatus.idle);

  factory AxiomState.loading() =>
      const AxiomState(status: AxiomStatus.loading, isFetching: true);

  factory AxiomState.mutating() =>
      const AxiomState(status: AxiomStatus.loading, isMutating: true);

  factory AxiomState.success(
    T data,
    AxiomSource source, {
    bool isFetching = false,
  }) => AxiomState(
    status: AxiomStatus.success,
    data: data,
    source: source,
    isFetching: isFetching,
  );

  factory AxiomState.error(
    AxiomError error, {
    T? previousData,
    AxiomSource? previousSource,
  }) => AxiomState(
    status: AxiomStatus.error,
    error: error,
    data: previousData,
    source: previousSource ?? AxiomSource.none,
  );

  bool get isIdle => status == AxiomStatus.idle;
  bool get isLoading => status == AxiomStatus.loading;
  bool get hasError => status == AxiomStatus.error;
  bool get hasData => data != null;
}
