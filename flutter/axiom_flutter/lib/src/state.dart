enum AxiomStatus { loading, success, error }
enum AxiomSource { none, cache, network }

class AxiomState<T> {
  final AxiomStatus status;
  final T? data;
  final Object? error;
  final AxiomSource source;
  final bool isFetching; // True if a network request is in flight

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
  factory AxiomState.loading() => const AxiomState._(
        status: AxiomStatus.loading,
        isFetching: true,
      );

  /// Success state (from cache or network)
  factory AxiomState.success(T data, AxiomSource source, {bool isFetching = false}) =>
      AxiomState._(
        status: AxiomStatus.success,
        data: data,
        source: source,
        isFetching: isFetching,
      );

  /// Error state
  factory AxiomState.error(Object error, {T? previousData, AxiomSource? previousSource}) =>
      AxiomState._(
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