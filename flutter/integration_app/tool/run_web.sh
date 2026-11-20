#!/usr/bin/env bash
# Build the app for web, serve it on 127.0.0.1:${WEB_PORT:-8792}, run it in headless
# Chrome and collect AXIOM_CHECK / AXIOM_RECEIPT console lines into receipt-web.json.
# The fixture backend must already run (../fixtures/backend/run.sh) on FIXTURE_BASE_URL.
#
# Variants (environment):
#   MODE=debug|release      flutter build mode (default debug)
#   BASE_HREF=/app/         build with --base-href and serve the app under that path
#   CSP=1                   serve with Content-Security-Policy
#                           "script-src 'self' 'wasm-unsafe-eval'" (implies --no-web-resources-cdn)
#   WASM=1                  build with dart2wasm (flutter build web --wasm)
#   RECEIPT=path            where to write the receipt (default receipt-web.json)
#   SKIP_BUILD=1            reuse build/web
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)"
WEB_PORT="${WEB_PORT:-8792}"
BASE="${FIXTURE_BASE_URL:-http://127.0.0.1:8791}"
CHROME="${CHROME:-$(command -v google-chrome || command -v chrome || command -v chromium)}"
TIMEOUT="${TIMEOUT:-120}"
MODE="${MODE:-debug}"
BASE_HREF="${BASE_HREF:-/}"
CSP="${CSP:-0}"
WASM="${WASM:-0}"
RECEIPT="${RECEIPT:-$APP/receipt-web.json}"
cd "$APP"
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  args=(--"$MODE" --dart-define=FIXTURE_BASE_URL="$BASE" --base-href "$BASE_HREF")
  [ "$CSP" = "1" ] && args+=(--no-web-resources-cdn --csp)
  [ "$WASM" = "1" ] && args+=(--wasm)
  # shellcheck disable=SC2086
  flutter build web "${args[@]}" ${WEB_BUILD_ARGS:-}
fi
LOG="$APP/build/web-chrome.log"
PROFILE="$(mktemp -d)"
python3 -I - "$WEB_PORT" "$APP/build/web" "$BASE_HREF" "$CSP" "$WASM" >"$APP/build/web-server.log" 2>&1 <<'PY' &
import http.server, os, sys, functools
port, root, base, csp, wasm = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5] == "1"
class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".js": "text/javascript", ".mjs": "text/javascript"}
    def translate_path(self, path):
        if base != "/" and path.startswith(base):
            path = "/" + path[len(base):]
        elif base != "/":
            return os.path.join(root, "__outside_base_href__")
        return super().translate_path(path)
    def end_headers(self):
        if csp:
            self.send_header("Content-Security-Policy",
                             "script-src 'self' 'wasm-unsafe-eval'; object-src 'none'; base-uri 'self'")
        if wasm:
            # dart2wasm prefers cross-origin isolation (SharedArrayBuffer) but runs without it.
            pass
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
    def log_message(self, fmt, *a):
        sys.stderr.write("%s %s\n" % (self.command if hasattr(self, "command") else "-", fmt % a))
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(H, directory=root)).serve_forever()
PY
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true; kill $CHROME_PID 2>/dev/null || true' EXIT
sleep 1
"$CHROME" --headless=new --no-sandbox --use-mock-keychain --password-store=basic \
  --disable-gpu --no-first-run --user-data-dir="$PROFILE" \
  --enable-logging=stderr --v=0 "http://127.0.0.1:$WEB_PORT$BASE_HREF" >"$LOG" 2>&1 &
CHROME_PID=$!
for _ in $(seq "$TIMEOUT"); do
  grep -q AXIOM_RECEIPT "$LOG" && break
  sleep 1
done
kill $CHROME_PID 2>/dev/null || true
if ! grep -q AXIOM_RECEIPT "$LOG"; then
  echo "no AXIOM_RECEIPT within ${TIMEOUT}s; see $LOG" >&2
  grep -iE "Content Security|Refused|Uncaught|axiom" "$LOG" | head -20 >&2 || true
  exit 1
fi
python3 -I - "$LOG" "$RECEIPT" "$MODE" "$BASE_HREF" "$CSP" "$WASM" <<'PY'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
line = next(l for l in text.splitlines() if "AXIOM_RECEIPT" in l)
raw = line.split("AXIOM_RECEIPT ", 1)[1]
# Chrome logs console messages as: ... "AXIOM_RECEIPT {...}", source: ... (line)
raw = raw[: raw.rfind('}') + 1]
try:
    receipt = json.loads(raw)
except json.JSONDecodeError:
    receipt = json.loads(raw.encode().decode("unicode_escape"))
receipt["build"] = {"mode": sys.argv[3], "baseHref": sys.argv[4], "csp": sys.argv[5] == "1",
                    "compiler": "dart2wasm" if sys.argv[6] == "1" else "dart2js"}
receipt["cspViolations"] = sum(1 for l in text.splitlines() if "Content Security Policy" in l)
json.dump(receipt, open(sys.argv[2], "w"), indent=2)
for c in receipt["checks"]:
    print(f"AXIOM_CHECK {c['name']} {c['outcome']} {c['message']}")
print(f"{sys.argv[2]}: pass={receipt['pass']} fail={receipt['fail']} skip={receipt['skip']} "
      f"build={receipt['build']} cspViolations={receipt['cspViolations']}")
PY
