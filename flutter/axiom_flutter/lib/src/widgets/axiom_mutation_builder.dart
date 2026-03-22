// FILE: lib/src/widgets/axiom_mutation_builder.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../state.dart';
import '../mutation.dart';

typedef AxiomMutationWidgetBuilder<T, Args> =
    Widget Function(
      BuildContext context,
      AxiomState<T> state,
      void Function(Args args) execute,
    );

/// A reactive builder for Form Submissions and Mutations (POST, PUT, DELETE).
class AxiomMutationBuilder<T, Args> extends StatefulWidget {
  final AxiomMutation<T, Args> mutation;
  final AxiomMutationWidgetBuilder<T, Args> builder;

  const AxiomMutationBuilder({
    super.key,
    required this.mutation,
    required this.builder,
  });

  @override
  State<AxiomMutationBuilder<T, Args>> createState() =>
      _AxiomMutationBuilderState<T, Args>();
}

class _AxiomMutationBuilderState<T, Args>
    extends State<AxiomMutationBuilder<T, Args>> {
  AxiomState<T> _state = AxiomState.idle();
  StreamSubscription<AxiomState<T>>? _subscription;

  void _execute(Args args) {
    if (!mounted) return;

    // Switch UI to mutating state
    setState(() {
      _state = AxiomState.mutating();
    });

    _subscription?.cancel();

    // Execute the SDK query (triggers Wasm Engine immediately)
    final query = widget.mutation.mutationFn(args);

    _subscription = query.stream.listen((newState) {
      if (mounted) {
        setState(() {
          // Keep isMutating true until success or error
          if (newState.isLoading) {
            _state = AxiomState.mutating();
          } else {
            _state = AxiomState(
              status: newState.status,
              data: newState.data,
              error: newState.error,
              source: newState.source,
              isFetching: false,
              isMutating: false, // Execution finished!
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state, _execute);
  }
}
