// Web helpers for checks_webspeed.dart (test hooks of the web runtime).
// ignore: implementation_imports
import 'package:axiom_flutter/src/runtime_web.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web; // via axiom_flutter_auth

const bool wsIsWeb = true;
int wsExternalBodies() => AxiomRuntimeWeb.debugExternalBodyCount;
int wsFastStarts() => AxiomRuntimeWeb.debugFastStartCount;
Set<int> wsFastGet(String namespace) =>
    AxiomRuntimeWeb().debugFastGetEndpoints(namespace);
/// The page's base URL without the trailing slash (honours --base-href).
String wsPageBase() {
  final b = web.document.baseURI;
  return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
}
