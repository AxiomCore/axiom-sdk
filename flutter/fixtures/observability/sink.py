"""Local OTLP/HTTP sink and header recorder for the observability checks (fixture only).

  python3 sink.py [port]       default 8804

POST /v1/traces    records an OTLP export (any encoding) and answers 200 {}
GET  /echo/<path>  records the request headers, answers like the fixture's echo endpoint
                   (the observed contract's namespace points its base URL here)
GET  /records      JSON list of everything recorded; DELETE /records clears it
CORS is open (the browser posts OTLP from the app origin).
"""
import json, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

RECORDS, LOCK = [], threading.Lock()


class H(BaseHTTPRequestHandler):
    def cors(self):
        self.send_header("Access-Control-Allow-Origin", self.headers.get("Origin") or "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", self.headers.get("Access-Control-Request-Headers") or "*")
        self.send_header("Access-Control-Max-Age", "600")

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def record(self, body=b""):
        with LOCK:
            RECORDS.append({"method": self.command, "path": self.path,
                            "headers": {k.lower(): v for k, v in self.headers.items()},
                            "bytes": len(body), "contentType": self.headers.get("Content-Type")})

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.end_headers()

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        self.record(body)
        self.reply(200, {})

    def do_DELETE(self):
        with LOCK:
            RECORDS.clear()
        self.reply(200, {})

    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/records":
            with LOCK:
                return self.reply(200, list(RECORDS))
        if u.path.startswith("/echo/"):
            self.record()
            q = parse_qs(u.query)
            return self.reply(200, {"path": u.path[len("/echo/"):], "q": q.get("q", [""])[0],
                                    "limit": int(q.get("limit", ["0"])[0])})
        self.reply(404, {"error": "not found"})

    def log_message(self, fmt, *a):
        sys.stderr.write("%s %s\n" % (self.command, self.path))


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 8804), H).serve_forever()
