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
    if (oldWidget.query.key != widget.query.key) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.query.stream.listen((rawState) {
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
          newState = AxiomState.success(
            rawState.data as R,
            rawState.source,
            isFetching: rawState.isFetching,
          );
        }
      } else if (rawState.hasError) {
        newState = AxiomState.error(
          rawState.error!,
          previousData: _currentState?.data,
          previousSource: _currentState?.source,
        );
      } else {
        newState = AxiomState.loading();
      }

      if (widget.selector != null && newState.data != null) {
        final newSelection = widget.selector!(newState.data as R);

        if (_currentState?.data != null &&
            _deepEquals(_previousSelection, newSelection)) {
          if (_currentState?.isFetching == newState.isFetching) {
            _currentState = newState;
            return;
          }
        }
        _previousSelection = newSelection;
      }

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
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _currentState;

    if (state == null || (state.isLoading && state.data == null)) {
      return widget.loading?.call(context) ?? const SizedBox.shrink();
    }

    if (state.hasError && state.data == null) {
      if (widget.error != null) {
        return widget.error!(context, state.error!);
      }
      return Center(child: Text('Error: ${state.error}'));
    }

    return widget.builder(context, state, state.data as R);
  }

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
