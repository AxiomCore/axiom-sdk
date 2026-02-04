import 'dart:async';
import 'package:flutter/widgets.dart';
import '../state.dart';
import '../query.dart';

typedef AxiomDataWidgetBuilder<R> =
    Widget Function(BuildContext context, AxiomState<R> state, R data);

typedef AxiomErrorWidgetBuilder =
    Widget Function(BuildContext context, AxiomError error);

typedef AxiomLoadingWidgetBuilder = Widget Function(BuildContext context);

/// A powerful builder that handles Axiom query state, data transformation, and build optimization.
///
/// [T] is the raw type coming from the SDK (e.g. models.User).
/// [R] is the transformed type used in the UI (e.g. String). Defaults to [T].
class AxiomBuilder<T, R> extends StatefulWidget {
  final AxiomQuery<T> query;

  /// Optional: Transform the data before it reaches the builder or selector.
  /// If null, [T] is cast to [R].
  final R Function(T data)? transform;

  /// Optional: Select specific fields to determine when to rebuild.
  /// If the selected value hasn't changed (compared via deep equality),
  /// the [builder] is NOT called, saving performance.
  ///
  /// Example: `selector: (user) => [user.name, user.role]`
  final Object? Function(R data)? selector;

  final AxiomDataWidgetBuilder<R> builder;
  final AxiomErrorWidgetBuilder? error;
  final AxiomLoadingWidgetBuilder? loading;

  const AxiomBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.transform,
    this.selector,
    this.error,
    this.loading,
  });

  @override
  State<AxiomBuilder<T, R>> createState() => _AxiomBuilderState<T, R>();
}

class _AxiomBuilderState<T, R> extends State<AxiomBuilder<T, R>> {
  StreamSubscription<AxiomState<T>>? _subscription;
  AxiomState<R>? _currentState;
  Object? _previousSelection;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AxiomBuilder<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the query key changes (different params or endpoint), re-subscribe.
    if (oldWidget.query.key != widget.query.key) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.query.stream.listen((rawState) {
      // 1. Transform Step: Convert AxiomState<T> -> AxiomState<R>
      final AxiomState<R> newState;

      if (rawState.data != null) {
        if (widget.transform != null) {
          final transformedData = widget.transform!(rawState.data as T);
          newState = AxiomState.success(
            transformedData,
            rawState.source,
            isFetching: rawState.isFetching,
          );
        } else {
          // If no transform is provided, we assume T == R
          newState = AxiomState.success(
            rawState.data as R,
            rawState.source,
            isFetching: rawState.isFetching,
          );
        }
      } else if (rawState.hasError) {
        newState = AxiomState.error(
          rawState.error!,
          previousData:
              _currentState?.data, // Keep showing stale data if available
          previousSource: _currentState?.source,
        );
      } else {
        newState = AxiomState.loading();
      }

      // 2. Selector Step (Optimization)
      if (widget.selector != null && newState.data != null) {
        final newSelection = widget.selector!(newState.data as R);

        // If we have previous data, check if selection changed
        if (_currentState?.data != null &&
            _deepEquals(_previousSelection, newSelection)) {
          // Data changed, but the selected fields did NOT.
          // However, we MUST still rebuild if `isFetching` status changed,
          // otherwise loading indicators won't update.
          if (_currentState?.isFetching == newState.isFetching) {
            _currentState =
                newState; // Update state internally but don't rebuild
            return;
          }
        }
        _previousSelection = newSelection;
      }

      // 3. Update UI
      if (mounted) {
        setState(() {
          _currentState = newState;
        });
      }
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
    _previousSelection = null;
    // We don't clear _currentState so we don't flash loading if swapping similar queries
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _currentState;

    // 1. Initial Loading (No data yet)
    if (state == null || (state.isLoading && state.data == null)) {
      return widget.loading?.call(context) ?? const SizedBox.shrink();
    }

    // 2. Error (Blocking - no previous data to show)
    if (state.hasError && state.data == null) {
      if (widget.error != null) {
        return widget.error!(context, state.error!);
      }
      // Default error view if none provided
      return Center(child: Text('Error: ${state.error}'));
    }

    // 3. Data (Success, or Error with Stale Data)
    return widget.builder(context, state, state.data as R);
  }

  /// Deep equality check for Lists (used for selector: [a, b])
  bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }
}
