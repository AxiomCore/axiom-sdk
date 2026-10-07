/// Require a known successful load result. -1 is explicit local unsigned mode.
/// A release application must additionally select a trusted proof/key policy.
void requireContractLoadStatus(int status) {
  if (status != 0 && status != -1) {
    throw StateError('Axiom contract load failed (status $status)');
  }
}
