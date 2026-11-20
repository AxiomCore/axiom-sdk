import 'dart:io';

ServerSocket? _server;
final _held = <Socket>[];

/// Native: a loopback socket that accepts connections and never answers, so
/// requests stay in flight until cancelled.
Future<String> bBlackholeUrl() async {
  var s = _server;
  if (s == null) {
    s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    s.listen(_held.add);
    _server = s;
  }
  return 'http://127.0.0.1:${s.port}';
}
