import '../lib/src/internal/contract_load_status.dart';

void main() {
  for (final status in [0, -1]) {
    requireContractLoadStatus(status);
  }
  for (final status in [-2, 1, 10, 11, 999]) {
    var rejected = false;
    try {
      requireContractLoadStatus(status);
    } on StateError {
      rejected = true;
    }
    if (!rejected) throw StateError('Unexpected accepted load result');
  }
  print('7 contract-load status cases passed');
}
