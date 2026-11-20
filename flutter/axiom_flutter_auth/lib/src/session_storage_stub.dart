// Non-web stand-ins for the browser helpers in session_storage_web.dart.
import 'types.dart';

const bool isWeb = false;

String? read(String key) => throw AxiomAuthError('unavailable');
void write(String key, String value) => throw AxiomAuthError('unavailable');
void delete(String key) => throw AxiomAuthError('unavailable');

/// The page URL on web; null elsewhere.
String? currentUrl() => null;

/// The page origin on web; null elsewhere.
String? pageOrigin() => null;

/// Replaces the page URL without navigation (web only).
void replaceUrl(String pathQueryFragment) {}

/// Full-page navigation (web only).
void assignUrl(String url) => throw AxiomAuthError('unavailable');
