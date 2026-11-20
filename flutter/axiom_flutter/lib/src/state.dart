import 'errors.dart';

/// Where in the request pipeline an error happened.
enum ErrorStage {
  /// Runtime configuration.
  configuration,

  /// Loading the contract.
  contractLoad,

  /// Building the request.
  requestBuild,

  /// Validating the request against the contract.
  validationRequest,

  /// Reading the cache.
  cacheRead,

  /// Sending the request.
  networkSend,

  /// Receiving the response.
  networkReceive,

  /// Validating the response against the contract.
  validationResponse,

  /// Decoding the response.
  deserialize,

  /// Writing the cache.
  cacheWrite,

  /// Inside the runtime.
  runtime,

  /// Crossing the FFI or wasm boundary.
  ffiBoundary;

  /// Parses a stage name; unknown names map to [runtime].
  static ErrorStage fromString(String val) => ErrorStage.values.firstWhere(
    (e) => e.name.toLowerCase() == val.toLowerCase(),
    orElse: () => ErrorStage.runtime,
  );
}

/// What kind of problem caused an error.
enum ErrorCategory {
  /// Contract problem.
  contract,

  /// Validation failed.
  validation,

  /// Network problem.
  network,

  /// Timeout.
  timeout,

  /// Encoding or decoding failed.
  serialization,

  /// Cache problem.
  cache,

  /// Authentication or authorization failed.
  auth,

  /// The server returned an error.
  server,

  /// Runtime problem.
  runtime,

  /// Not classified.
  unknown;

  /// Parses a category name; unknown names map to [unknown].
  static ErrorCategory fromString(String val) =>
      ErrorCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == val.toLowerCase(),
        orElse: () => ErrorCategory.unknown,
      );
}

/// Machine-readable error code of an [AxiomError]. Switch over the
/// subclasses to handle specific cases.
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
        'Cancelled' => const Cancelled(),
        _ => UnknownCode(json),
      };
    } else if (json is Map && json.containsKey('HttpStatus')) {
      return HttpStatus(json['HttpStatus'] as int);
    }
    return UnknownCode(json.toString());
  }
}

/// No contract is loaded for the namespace.
class ContractMissing extends AxiomErrorCode {
  /// Creates the code.
  const ContractMissing();
}

/// The contract is invalid.
class ContractInvalid extends AxiomErrorCode {
  /// Creates the code.
  const ContractInvalid();
}

/// The endpoint is not in the contract.
class EndpointNotFound extends AxiomErrorCode {
  /// Creates the code.
  const EndpointNotFound();
}

/// Request or response failed contract validation.
class ValidationError extends AxiomErrorCode {
  /// Creates the code.
  const ValidationError();
}

/// The call timed out.
class NetworkTimeout extends AxiomErrorCode {
  /// Creates the code.
  const NetworkTimeout();
}

/// The connection could not be made.
class NetworkConnectionFailed extends AxiomErrorCode {
  /// Creates the code.
  const NetworkConnectionFailed();
}

/// The response is not valid JSON.
class JsonParseError extends AxiomErrorCode {
  /// Creates the code.
  const JsonParseError();
}

/// Encoding or decoding failed.
class CodecError extends AxiomErrorCode {
  /// Creates the code.
  const CodecError();
}

/// The auth token expired.
class AuthTokenExpired extends AxiomErrorCode {
  /// Creates the code.
  const AuthTokenExpired();
}

/// The runtime is not initialized.
class NotInitialized extends AxiomErrorCode {
  /// Creates the code.
  const NotInitialized();
}

/// The server answered with HTTP status [code].
class HttpStatus extends AxiomErrorCode {
  /// HTTP status code.
  final int code;

  /// Creates the code.
  const HttpStatus(this.code);
}

/// A code this package does not know.
class UnknownCode extends AxiomErrorCode {
  /// The code as sent by the runtime.
  final String raw;

  /// Creates the code.
  const UnknownCode(this.raw);
}

/// The request was cancelled (`axiom_cancel`, query disposal,
/// `resetSession`, or a per-call timeout raised by the SDK).
class Cancelled extends AxiomErrorCode {
  /// Creates the code.
  const Cancelled();
}

/// An error from a call: where it happened ([stage]), why ([category],
/// [code]) and whether a retry can help ([retryable]).
///
/// For declared contract failures, [failureCode] and [failurePayload] are
/// set, and the generated `when<Endpoint>` matchers give typed objects.
class AxiomError {
  /// Pipeline stage where the error happened.
  final ErrorStage stage;

  /// Kind of problem.
  final ErrorCategory category;

  /// Machine-readable code.
  final AxiomErrorCode code;

  /// Readable message.
  final String message;

  /// True when retrying the call can succeed.
  final bool retryable;

  /// Extra detail, usually the server response body.
  final String? details;

  /// Contract `failure` code (for example `NotFound`, `InsufficientFunds`)
  /// when the server answered with a declared failure. Null otherwise.
  /// Read from the error JSON field `failure_code`.
  final String? failureCode;

  /// Decoded JSON payload of the contract failure (field `failure_payload`).
  final Object? failurePayload;

  /// Creates an error.
  AxiomError({
    required this.stage,
    required this.category,
    required this.code,
    required this.message,
    required this.retryable,
    this.details,
    this.failureCode,
    this.failurePayload,
  });

  /// Parses the error JSON sent by the runtime.
  factory AxiomError.fromJson(Map<String, dynamic> json) {
    return AxiomError(
      stage: ErrorStage.fromString(json['stage']),
      category: ErrorCategory.fromString(json['category']),
      code: AxiomErrorCode.fromJson(json['code']),
      message: json['message'],
      retryable: json['retryable'] ?? false,
      details: json['details'],
      failureCode: (json['failure_code'] ?? json['failureCode']) as String?,
      failurePayload: json['failure_payload'] ?? json['failurePayload'],
    );
  }

  /// True when [code] is [Cancelled].
  bool get isCancelled => code is Cancelled;

  /// Typed failure produced by the decoder registered for [failureCode] in
  /// [AxiomFailureRegistry], or null.
  Object? failure({String? namespace}) =>
      AxiomFailureRegistry.decode(this, namespace: namespace);

  /// Returns the validation message for [fieldName] from [details] when
  /// [code] is [ValidationError], or null.
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

/// Status of an [AxiomState].
enum AxiomStatus {
  /// No request yet (mutations before `execute`).
  idle,

  /// A request runs and there is no data yet.
  loading,

  /// Data arrived.
  success,

  /// The request failed.
  error,
}

/// Where the data of an [AxiomState] came from.
enum AxiomSource {
  /// No data yet.
  none,

  /// The runtime cache.
  cache,

  /// The network.
  network,
}

/// One state of a query, mutation or stream: status, data, error and
/// where the data came from.
class AxiomState<T> {
  /// Current status.
  final AxiomStatus status;

  /// Latest data. Kept while a refresh runs and after an error.
  final T? data;

  /// Error, when [status] is [AxiomStatus.error].
  final AxiomError? error;

  /// Where [data] came from.
  final AxiomSource source;

  /// True while a network request runs.
  final bool isFetching;

  /// True while a mutation runs.
  final bool isMutating;

  /// True while a streaming response is open.
  final bool isStreaming;

  /// Creates a state.
  const AxiomState({
    required this.status,
    this.data,
    this.error,
    this.source = AxiomSource.none,
    this.isFetching = false,
    this.isMutating = false,
    this.isStreaming = false,
  });

  /// Returns a state with [data] mapped by [mapper].
  AxiomState<R> map<R>(R Function(T data) mapper) {
    return AxiomState<R>(
      status: status,
      data: data != null ? mapper(data as T) : null,
      error: error,
      source: source,
      isFetching: isFetching,
      isMutating: isMutating,
      isStreaming: isStreaming,
    );
  }

  /// A state before any request.
  factory AxiomState.idle() => const AxiomState(status: AxiomStatus.idle);

  /// A state while the first request runs.
  factory AxiomState.loading() =>
      const AxiomState(status: AxiomStatus.loading, isFetching: true);

  /// A state while a mutation runs.
  factory AxiomState.mutating() =>
      const AxiomState(status: AxiomStatus.loading, isMutating: true);

  /// A state with [data] from [source].
  factory AxiomState.success(
    T data,
    AxiomSource source, {
    bool isFetching = false,
    bool isStreaming = false,
  }) => AxiomState(
    status: AxiomStatus.success,
    data: data,
    source: source,
    isFetching: isFetching,
    isStreaming: isStreaming,
  );

  /// A state with [error]. [previousData] keeps the last value visible.
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

  /// True before any request.
  bool get isIdle => status == AxiomStatus.idle;

  /// True while the first request runs.
  bool get isLoading => status == AxiomStatus.loading;

  /// True when data arrived.
  bool get isSuccess => status == AxiomStatus.success;

  /// True when the request failed.
  bool get hasError => status == AxiomStatus.error;

  /// True when [data] is not null.
  bool get hasData => data != null;
}
