/// Managed Axiom project authentication for Flutter: the Dart port of
/// `@axiomcore/auth-web` (auth-surfaces/v1).
library;

import 'src/client.dart';
import 'src/redirect.dart';

export 'src/binding.dart';
export 'src/client.dart'
    show
        AxiomAuth,
        AxiomAuthOptions,
        AuthRedirectLauncher,
        AxiomPasskeys,
        TimerFactory,
        parseStepUpChallenge,
        runtimeAuthRefusal,
        validReturnTo;
export 'src/redirect.dart';
export 'src/storage.dart';
export 'src/types.dart';
export 'src/widgets.dart';

/// Creates an [AxiomAuth] with the Flutter defaults: flutter_web_auth_2 for
/// redirect flows when [AxiomAuthOptions.launcher] is not set.
AxiomAuth createAxiomAuth(AxiomAuthOptions options) {
  installDefaultLauncher();
  return AxiomAuth(options);
}
