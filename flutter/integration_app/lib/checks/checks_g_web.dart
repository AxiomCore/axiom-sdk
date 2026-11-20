// Browser helpers for checks_g.dart (cookie session for WebSockets on web).
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web; // via axiom_flutter_auth

const bool gIsWeb = true;
String? gPageOrigin() => web.window.location.origin;

/// `chromium` when the browser sends "permessage-deflate; client_max_window_bits"
/// on a WebSocket upgrade, otherwise `other` (see fixtures/backend/tool/session.py).
String gBrowserFamily() {
  final ua = web.window.navigator.userAgent;
  return (ua.contains('Chrome/') || ua.contains('Chromium/') || ua.contains('Edg/'))
      ? 'chromium'
      : 'other';
}

// Cookies are not port-scoped: a cookie set by the page on 127.0.0.1:8802 is
// sent with the WebSocket upgrade to 127.0.0.1:8803 (same site).
void gSetCookie(String name, String value) =>
    web.document.cookie = '$name=$value; path=/; SameSite=Lax';
void gClearCookie(String name) =>
    web.document.cookie = '$name=; path=/; max-age=0';
