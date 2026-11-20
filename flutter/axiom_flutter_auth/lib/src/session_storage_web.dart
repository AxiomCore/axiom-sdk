// Browser helpers: sessionStorage, the page URL and history (web only).
import 'package:web/web.dart' as web;

import 'types.dart';

const bool isWeb = true;

web.Storage get _s {
  try {
    return web.window.sessionStorage;
  } catch (_) {
    throw AxiomAuthError('unavailable');
  }
}

String? read(String key) => _s.getItem(key);
void write(String key, String value) => _s.setItem(key, value);
void delete(String key) => _s.removeItem(key);

String? currentUrl() => web.window.location.href;

String? pageOrigin() => web.window.location.origin;

void replaceUrl(String pathQueryFragment) {
  try {
    web.window.history.replaceState(
      web.window.history.state,
      '',
      pathQueryFragment,
    );
  } catch (_) {
    // A history failure must not leave the flow half done; the code is single use.
  }
}

void assignUrl(String url) => web.window.location.assign(url);
