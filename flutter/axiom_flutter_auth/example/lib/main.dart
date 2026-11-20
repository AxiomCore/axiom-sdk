// axiom_flutter_auth example: sign-in screen, session-aware home, and an
// automated web smoke run (--dart-define=AXIOM_AUTH_SMOKE_EMAIL=...).
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:flutter/material.dart';

import 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';

const issuer = String.fromEnvironment(
  'AXIOM_AUTH_ISSUER',
  defaultValue: 'http://127.0.0.1:18777/local/example',
);
const redirectUri = String.fromEnvironment(
  'AXIOM_AUTH_REDIRECT',
  defaultValue: 'com.axiomcore.fluttertest:/auth/callback',
);
const smokeEmail = String.fromEnvironment('AXIOM_AUTH_SMOKE_EMAIL');
const smokePassword = String.fromEnvironment(
  'AXIOM_AUTH_SMOKE_PASSWORD',
  defaultValue: 'correct horse battery',
);

late final AxiomAuth auth;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keychain/Keystore on mobile and desktop, sessionStorage on web.
  auth = createAxiomAuth(
    AxiomAuthOptions(
      issuer: issuer,
      redirectUri: redirectUri,
      storage: platformStorage(),
    ),
  );
  if (smokeEmail.isNotEmpty) {
    await _smoke();
  } else {
    // Calls to the `api` namespace (your own backend) now carry a fresh
    // token. Other namespaces never see it.
    AxiomAuthBinding.attach(
      auth,
      runtime: AxiomRuntime(),
      namespaces: const ['api'],
    );
    await auth.restore();
  }
  runApp(AxiomAuthLifecycle(auth: auth, child: const App()));
}

Future<void> _smoke() async {
  try {
    final s = await auth.restore();
    if (s.status == AuthStatus.authenticated) {
      // ignore: avoid_print
      print('AXIOM_SMOKE restored ${s.principal!.subject} storage=session');
      final user = await auth.user();
      // ignore: avoid_print
      print('AXIOM_SMOKE user ${user?.email}');
      await auth.signOut();
      // ignore: avoid_print
      print('AXIOM_SMOKE signed_out ${auth.session().status.name}');
      return;
    }
    await auth.signInWithPassword(smokeEmail, smokePassword);
    // ignore: avoid_print
    print('AXIOM_SMOKE signed_in ${auth.session().status.name}; reloading');
    reloadPage();
  } catch (e) {
    // ignore: avoid_print
    print('AXIOM_SMOKE FAIL $e');
  }
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Axiom auth',
    home: AxiomAuthBuilder(
      auth: auth,
      loading: (_, __) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      signedIn: (_, s) => Scaffold(
        appBar: AppBar(title: const Text('Signed in')),
        body: Center(child: Text('${s.principal!.subject} (${s.acr.name})')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => auth.signOut(),
          label: const Text('Sign out'),
        ),
      ),
      signedOut: (_, __) => const SignInPage(),
    ),
  );
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  String? error;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => error = null);
    try {
      await f();
    } on AxiomAuthError catch (e) {
      setState(() => error = e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mfa = auth.mfaChallenge();
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                _run(() => auth.signInWithPassword(email.text, password.text)),
            child: const Text('Sign in'),
          ),
          TextButton(
            onPressed: () => _run(() => auth.signInWithProvider('local')),
            child: const Text('Sign in with provider (PKCE)'),
          ),
          if (mfa != null) ...[
            TextField(
              controller: code,
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  _run(() => auth.verifyMfa(mfa.factors.first.id, code.text)),
              child: const Text('Verify'),
            ),
          ],
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
