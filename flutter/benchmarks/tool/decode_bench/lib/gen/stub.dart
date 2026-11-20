// Minimal stand-ins for the axiom_flutter types the generated models use.
class AxiomError {
  String? failureCode;
  Object? failurePayload;
  String? details;
}

abstract final class AxiomFailureRegistry {
  static void register(String code, Object? Function(Object?) f, {String? namespace}) {}
}
