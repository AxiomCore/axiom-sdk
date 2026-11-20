// Platform-selected HTTP clients for the fair-comparison rows. Conditional import: the dart:io
// side has dio_http2_adapter, cronet_http (Android) and cupertino_http (iOS/macOS); the web side
// returns null for all of them (in the browser every client uses fetch, and HTTP/2 is decided by
// the browser and the server's ALPN, so web HTTP/2 rows use the plain clients on the h2 URL).
export 'platform_clients_stub.dart' if (dart.library.io) 'platform_clients_io.dart';
