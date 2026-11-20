// Benchmark server: serves the endpoints of ../acore/main.acore with deterministic data.
//
//   dart run bin/server.dart [port] [h2port]   (default 8851 and port+2, binds 0.0.0.0)
//
// `port` speaks plain HTTP/1.1. `h2port` speaks HTTP/2 over TLS only (ALPN h2) with the
// self-signed certificate in certs/ (CN/SAN 127.0.0.1, localhost; test only). Both serve the
// same routes and the same pre-encoded bodies. h2port 0 disables the TLS listener.
//
// GET  /items?n=N          ItemList with N items (N <= 10000); bodies are pre-encoded
// GET  /cached/items?n=N   same body, `cache-control: max-age=600`
// GET  /items/{id}         one Item
// POST /items              body {name, price, qty} -> 201 Item
// WS   /ws                 echoes every text message
// GET  /_ready             "ok"
// GET  /items.ndjson?n=N   the same N items, one JSON object per line, written in 64 KB chunks
// GET  /_ctl/offline?on=1  data routes drop the connection without a response until ?on=0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http2/http2.dart' as h2;

/// BENCH_SERVER_LOG=1 logs WebSocket traffic (debugging only; adds latency).
final bool _log = Platform.environment['BENCH_SERVER_LOG'] == '1';

Map<String, Object?> item(int i) => {
      'id': '$i',
      'name': 'item $i',
      'price': i * 1.25,
      'qty': i % 100,
      'active': i.isEven,
      'tags': ['t${i % 7}', 'bench'],
    };

bool _offline = false;

final _ndjson = <int, List<int>>{};
List<int> ndjsonBody(int n) => _ndjson.putIfAbsent(
    n, () => utf8.encode([for (var i = 1; i <= n; i++) '${jsonEncode(item(i))}\n'].join()));

final _lists = <int, List<int>>{};
List<int> listBody(int n) => _lists.putIfAbsent(n, () {
      final items = [for (var i = 1; i <= n; i++) item(i)];
      return utf8.encode(jsonEncode({'items': items, 'total': n}));
    });

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8851;
  for (final n in const [1, 100, 1000, 10000]) {
    listBody(n);
  }
  ndjsonBody(10000);
  final h2port = args.length > 1 ? int.parse(args[1]) : port + 2;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('bench server on http://0.0.0.0:$port');
  if (h2port != 0) await _startH2(h2port);
  await for (final req in server) {
    _handle(req).catchError((Object e) {
      try {
        req.response.statusCode = 500;
        req.response.close();
      } catch (_) {}
    });
  }
}

void _cors(HttpRequest req) {
  final h = req.response.headers;
  h.set('access-control-allow-origin', '*');
  h.set('access-control-allow-methods', 'GET, POST, OPTIONS');
  h.set('access-control-allow-headers',
      req.headers.value('access-control-request-headers') ?? '*');
  h.set('access-control-max-age', '600');
}

Future<void> _json(HttpRequest req, int status, List<int> body, {String? cache}) async {
  final res = req.response;
  res.statusCode = status;
  res.headers.contentType = ContentType.json;
  res.headers.set('cache-control', cache ?? 'no-store');
  res.contentLength = body.length;
  res.add(body);
  await res.close();
}

Future<void> _handle(HttpRequest req) async {
  final path = req.uri.path;
  if (path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
    final ws = await WebSocketTransformer.upgrade(req);
    if (_log) stdout.writeln('ws open ${req.uri} origin=${req.headers.value('origin')}');
    ws.listen((m) {
      if (_log) stdout.writeln('ws msg ${m is String ? m : 'binary ${(m as List).length} B'}');
      ws.add(m);
    }, onDone: () {
      if (_log) stdout.writeln('ws closed ${ws.closeCode}');
      ws.close();
    });
    return;
  }
  _cors(req);
  if (req.method == 'OPTIONS') {
    req.response.statusCode = 204;
    await req.response.close();
    return;
  }
  if (path == '/_ready') {
    return _json(req, 200, utf8.encode('"ok"'));
  }
  if (path == '/_ctl/offline') {
    _offline = req.uri.queryParameters['on'] == '1';
    return _json(req, 200, utf8.encode('{"offline":$_offline}'));
  }
  if (_offline) {
    final s = await req.response.detachSocket(writeHeaders: false);
    s.destroy();
    return;
  }
  if (path == '/items.ndjson' && req.method == 'GET') {
    final n = (int.tryParse(req.uri.queryParameters['n'] ?? '') ?? 1).clamp(0, 10000);
    final body = ndjsonBody(n);
    final res = req.response;
    res.headers.set('content-type', 'application/x-ndjson');
    res.headers.set('cache-control', 'no-store');
    res.bufferOutput = false;
    for (var o = 0; o < body.length; o += 65536) {
      res.add(body.sublist(o, o + 65536 > body.length ? body.length : o + 65536));
      await res.flush();
    }
    await res.close();
    return;
  }
  if ((path == '/items' || path == '/cached/items') && req.method == 'GET') {
    final n = int.tryParse(req.uri.queryParameters['n'] ?? '') ?? 1;
    if (n < 0 || n > 10000) return _json(req, 400, utf8.encode('{"error":"n out of range"}'));
    return _json(req, 200, listBody(n), cache: path == '/cached/items' ? 'max-age=600' : null);
  }
  if (path == '/items' && req.method == 'POST') {
    final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, Object?>;
    final out = {
      'id': 'new',
      'name': body['name'],
      'price': body['price'],
      'qty': body['qty'],
      'active': true,
      'tags': ['new'],
    };
    return _json(req, 201, utf8.encode(jsonEncode(out)));
  }
  if (path.startsWith('/items/') && req.method == 'GET') {
    final id = int.tryParse(path.substring(7)) ?? 1;
    return _json(req, 200, utf8.encode(jsonEncode(item(id))));
  }
  return _json(req, 404, utf8.encode('{"error":"not found"}'));
}

// ---- HTTP/2 over TLS ----

final String _certDir = Platform.environment['BENCH_CERT_DIR'] ??
    '${File.fromUri(Platform.script).parent.parent.path}/certs';

Future<void> _startH2(int port) async {
  final ctx = SecurityContext()
    ..useCertificateChain('$_certDir/cert.pem')
    ..usePrivateKey('$_certDir/key.pem')
    ..setAlpnProtocols(const ['h2'], true);
  final sock = await SecureServerSocket.bind(InternetAddress.anyIPv4, port, ctx);
  stdout.writeln('bench server (HTTP/2, TLS, self-signed) on https://0.0.0.0:$port');
  sock.listen((s) {
    if (s.selectedProtocol != 'h2') {
      s.destroy();
      return;
    }
    s.setOption(SocketOption.tcpNoDelay, true);
    final conn = h2.ServerTransportConnection.viaSocket(
      s,
      settings: const h2.ServerSettings(concurrentStreamLimit: 1000),
    );
    conn.incomingStreams.listen((st) => _h2Stream(st).catchError((Object _) {}),
        onError: (Object _) {});
  }, onError: (Object _) {});
}

Future<void> _h2Stream(h2.ServerTransportStream st) async {
  final headers = <String, String>{};
  final body = BytesBuilder(copy: false);
  var gotHeaders = false;
  await for (final m in st.incomingMessages) {
    if (m is h2.HeadersStreamMessage && !gotHeaders) {
      gotHeaders = true;
      for (final h in m.headers) {
        headers[utf8.decode(h.name).toLowerCase()] = utf8.decode(h.value);
      }
    } else if (m is h2.DataStreamMessage) {
      body.add(m.bytes);
    }
    if (m.endStream) break;
  }
  if (_offline) {
    st.terminate();
    return;
  }
  final method = headers[':method'] ?? 'GET';
  final uri = Uri.parse(headers[':path'] ?? '/');
  final r = _route(method, uri, body.takeBytes());
  final out = <h2.Header>[
    h2.Header.ascii(':status', '${r.status}'),
    h2.Header.ascii('content-type', 'application/json; charset=utf-8'),
    h2.Header.ascii('cache-control', r.cache),
    h2.Header.ascii('content-length', '${r.body.length}'),
    h2.Header.ascii('access-control-allow-origin', '*'),
    h2.Header.ascii('access-control-allow-methods', 'GET, POST, OPTIONS'),
    h2.Header.ascii('access-control-allow-headers',
        headers['access-control-request-headers'] ?? '*'),
    h2.Header.ascii('access-control-max-age', '600'),
  ];
  if (r.body.isEmpty) {
    st.sendHeaders(out, endStream: true);
  } else {
    st.sendHeaders(out);
    st.sendData(r.body, endStream: true);
  }
}

class _Res {
  _Res(this.status, this.body, [this.cache = 'no-store']);
  final int status;
  final List<int> body;
  final String cache;
}

/// Same routes as [_handle] (minus WebSocket) for the HTTP/2 listener.
_Res _route(String method, Uri uri, List<int> reqBody) {
  final path = uri.path;
  if (method == 'OPTIONS') return _Res(204, const []);
  if (path == '/_ready') return _Res(200, utf8.encode('"ok"'));
  if (path == '/items.ndjson' && method == 'GET') {
    final n = (int.tryParse(uri.queryParameters['n'] ?? '') ?? 1).clamp(0, 10000);
    return _Res(200, ndjsonBody(n));
  }
  if ((path == '/items' || path == '/cached/items') && method == 'GET') {
    final n = int.tryParse(uri.queryParameters['n'] ?? '') ?? 1;
    if (n < 0 || n > 10000) return _Res(400, utf8.encode('{"error":"n out of range"}'));
    return _Res(200, listBody(n), path == '/cached/items' ? 'max-age=600' : 'no-store');
  }
  if (path == '/items' && method == 'POST') {
    final body = jsonDecode(utf8.decode(reqBody)) as Map<String, Object?>;
    return _Res(201, utf8.encode(jsonEncode({
      'id': 'new',
      'name': body['name'],
      'price': body['price'],
      'qty': body['qty'],
      'active': true,
      'tags': ['new'],
    })));
  }
  if (path.startsWith('/items/') && method == 'GET') {
    final id = int.tryParse(path.substring(7)) ?? 1;
    return _Res(200, utf8.encode(jsonEncode(item(id))));
  }
  return _Res(404, utf8.encode('{"error":"not found"}'));
}
