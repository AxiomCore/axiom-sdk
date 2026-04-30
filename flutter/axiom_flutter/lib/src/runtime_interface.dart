import 'dart:typed_data';

import 'state.dart';
import 'query.dart';

import 'runtime_stub.dart'
    if (dart.library.io) 'runtime_io.dart'
    if (dart.library.js_interop) 'runtime_web.dart';

class AxiomStreamResponse {
  final int requestId;
  final Stream<AxiomState<Uint8List>> stream;
  AxiomStreamResponse(this.requestId, this.stream);
}

abstract class AxiomRuntime {
  factory AxiomRuntime() => getRuntime();

  bool debug = false;

  Future<void> init([String? dbPath]);

  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  });

  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
  });

  /// Execute a read-only or cacheable query.
  /// Results are shared and de-duplicated via AxiomQueryManager — multiple
  /// callers with the same key receive the same stream.
  AxiomQuery<T> send<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  });

  /// Execute a mutation (POST/PUT/DELETE).
  /// Each call creates a fresh stream that is NEVER cached or shared.
  /// This is the correct method for login, form submission, delete actions, etc.
  AxiomQuery<T> sendMutation<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  });

  AxiomStreamResponse callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required Uint8List requestBytes,
  });

  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  });

  void clearAuthToken({required String namespace, required String methodName});

  void sendStreamMessage({required int requestId, required Uint8List payload});
}

class EventType {
  static const int complete = 0;
  static const int networkSuccess = 1;
  static const int cacheHit = 2;
  static const int cacheHitAndFetching = 3;
  static const int error = 4;
  static const int streamChunk = 5;
}

class FfiError {
  static const int successUnverified = -1;
  static const int success = 0;
  static const int unknownError = 1;
  static const int requestParsingFailed = 2;
  static const int networkError = 3;
  static const int responseDeserializationFailed = 4;
  static const int unknownEndpoint = 5;
  static const int timeout = 6;
  static const int requestFailed = 7;
  static const int authError = 8;
  static const int serverError = 9;
  static const int invalidContract = 10;
  static const int runtimeTooOld = 11;
  static const int contractNotLoaded = 12;
  static const int initializationFailed = 13;
  static const int internalError = 14;

  static String name(int code) {
    return switch (code) {
      successUnverified => 'SuccessUnverified',
      success => 'Success',
      unknownError => 'UnknownError',
      requestParsingFailed => 'RequestParsingFailed',
      networkError => 'NetworkError',
      responseDeserializationFailed => 'ResponseDeserializationFailed',
      unknownEndpoint => 'UnknownEndpoint',
      timeout => 'Timeout',
      requestFailed => 'RequestFailed',
      authError => 'AuthError',
      serverError => 'ServerError',
      invalidContract => 'InvalidContract',
      runtimeTooOld => 'RuntimeTooOld',
      contractNotLoaded => 'ContractNotLoaded',
      initializationFailed => 'InitializationFailed',
      internalError => 'InternalError',
      _ => 'UnrecognizedErrorCode',
    };
  }
}
