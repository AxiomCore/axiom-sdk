import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'client.dart';
import 'types.dart';

/// The session of an [AxiomAuth] as a [ValueListenable].
class AxiomSessionListenable extends ChangeNotifier implements ValueListenable<PublicSession> {
  AxiomSessionListenable(this.auth) {
    _value = auth.session();
    _unsubscribe = auth.subscribe((s) {
      _value = s;
      notifyListeners();
    });
  }

  final AxiomAuth auth;
  late PublicSession _value;
  late final void Function() _unsubscribe;

  @override
  PublicSession get value => _value;

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

final Expando<AxiomSessionListenable> _listenables = Expando();

extension AxiomAuthListenable on AxiomAuth {
  /// One shared [ValueListenable] of the session per client.
  ValueListenable<PublicSession> get sessionListenable =>
      _listenables[this] ??= AxiomSessionListenable(this);
}

/// Rebuilds on every session change and picks a builder by status:
/// [signedIn] for `authenticated` (and `refreshing` with a principal),
/// [signedOut] for `anonymous`, `expired` and `error` without a principal,
/// [loading] for `unknown`, `loading` and `refreshing` before the first token.
class AxiomAuthBuilder extends StatelessWidget {
  const AxiomAuthBuilder({
    super.key,
    required this.auth,
    required this.signedIn,
    required this.signedOut,
    this.loading,
  });

  final AxiomAuth auth;
  final Widget Function(BuildContext context, PublicSession session) signedIn;
  final Widget Function(BuildContext context, PublicSession session) signedOut;
  final Widget Function(BuildContext context, PublicSession session)? loading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PublicSession>(
      valueListenable: auth.sessionListenable,
      builder: (context, s, _) {
        if (s.principal != null &&
            (s.status == AuthStatus.authenticated || s.status == AuthStatus.refreshing || s.status == AuthStatus.error)) {
          return signedIn(context, s);
        }
        switch (s.status) {
          case AuthStatus.unknown:
          case AuthStatus.loading:
          case AuthStatus.refreshing:
            return loading?.call(context, s) ?? const SizedBox.shrink();
          default:
            return signedOut(context, s);
        }
      },
    );
  }
}

/// Forwards app lifecycle to [AxiomAuth.setForeground] (auth-web's
/// `visibilitychange`): no refresh timer while paused, a due refresh at resume.
class AxiomAuthLifecycle extends StatefulWidget {
  const AxiomAuthLifecycle({super.key, required this.auth, required this.child});
  final AxiomAuth auth;
  final Widget child;
  @override
  State<AxiomAuthLifecycle> createState() => _AxiomAuthLifecycleState();
}

class _AxiomAuthLifecycleState extends State<AxiomAuthLifecycle> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.auth.setForeground(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      widget.auth.setForeground(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
