import 'state.dart';

/// One error seen by the runtime, delivered on [AxiomRuntime.onError].
class AxiomErrorEvent {
  final AxiomError error;
  final String? namespace;
  final int? endpointId;
  final int? requestId;

  const AxiomErrorEvent(
    this.error, {
    this.namespace,
    this.endpointId,
    this.requestId,
  });

  @override
  String toString() =>
      'AxiomErrorEvent($namespace#$endpointId req=$requestId: $error)';
}

/// Decodes a contract failure payload into a generated Dart class.
typedef AxiomFailureDecoder = Object Function(Object? payload);

/// Registry used by generated code to map a contract `failure` code to a
/// typed Dart class. Generated `create()` registers one decoder per failure
/// declared in the contract; [AxiomError.failure] then returns the instance.
class AxiomFailureRegistry {
  AxiomFailureRegistry._();

  static final Map<String, AxiomFailureDecoder> _decoders = {};

  static String _key(String? namespace, String code) =>
      '${namespace ?? '*'}::$code';

  /// Registers [decoder] for [failureCode]. With a null [namespace] it
  /// applies to every namespace.
  static void register(
    String failureCode,
    AxiomFailureDecoder decoder, {
    String? namespace,
  }) {
    _decoders[_key(namespace, failureCode)] = decoder;
  }

  static void unregisterAll({String? namespace}) {
    if (namespace == null) {
      _decoders.clear();
    } else {
      _decoders.removeWhere((k, _) => k.startsWith('$namespace::'));
    }
  }

  /// Decodes [error] into its typed failure, or returns null when it has no
  /// failure code or no decoder is registered.
  static Object? decode(AxiomError error, {String? namespace}) {
    final code = error.failureCode;
    if (code == null) return null;
    final decoder =
        _decoders[_key(namespace, code)] ?? _decoders[_key(null, code)];
    return decoder?.call(error.failurePayload);
  }
}
