import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'client.dart';

/// Hosted sign-in and provider flows through `flutter_web_auth_2`:
/// ASWebAuthenticationSession on iOS/macOS, Custom Tabs on Android, a popup
/// on web (the callback page must post the URL back; see the README).
///
/// Android: add the `CallbackActivity` intent filter for the redirect scheme
/// to `AndroidManifest.xml`. iOS/macOS: nothing to add for a custom scheme.
class FlutterWebAuth2Launcher implements AuthRedirectLauncher {
  const FlutterWebAuth2Launcher({
    this.options = const FlutterWebAuth2Options(),
  });

  final FlutterWebAuth2Options options;

  @override
  Future<Uri?> authenticate(
    Uri url, {
    required String callbackUrlScheme,
  }) async {
    final result = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: callbackUrlScheme,
      options: options,
    );
    return Uri.parse(result);
  }
}

/// Makes [FlutterWebAuth2Launcher] the default launcher of every [AxiomAuth]
/// created without one. Called by `AxiomAuth.flutter`.
void installDefaultLauncher() {
  AxiomAuth.defaultLauncher ??= const FlutterWebAuth2Launcher();
}
