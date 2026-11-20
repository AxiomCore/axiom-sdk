import 'dart:typed_data';

// Native stand-ins for checks_webspeed_web.dart (the checks skip off the web).
const bool wsIsWeb = false;
int wsExternalBodies() => 0;
int wsFastStarts() => 0;
Set<int> wsFastGet(String namespace) => const {};
String wsPageBase() => '';
bool wsFastStartEnabled() => false;
Set<int> wsFastGetForContract(Uint8List bytes) => const {};
