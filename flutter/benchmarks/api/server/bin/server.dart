// Benchmark server: serves the endpoints of ../acore/main.acore with deterministic data.
//
//   dart run bin/server.dart [port]      (default 8851, binds 0.0.0.0)
//
// GET  /items?n=N          ItemList with N items (N <= 10000); bodies are pre-encoded
// GET  /cached/items?n=N   same body, `cache-control: max-age=600`
// GET  /items/{id}         one Item
// POST /items              body {name, price, qty} -> 201 Item
// WS   /ws                 echoes every text message
// GET  /_ready             "ok"
import 'dart:convert';
import 'dart:io';

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
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('bench server on http://0.0.0.0:$port');
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
