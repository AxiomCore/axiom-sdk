#!/usr/bin/env bash
# Build the app for web, serve it on 127.0.0.1:${WEB_PORT:-8792}, run it in headless
# Chrome and collect AXIOM_CHECK / AXIOM_RECEIPT console lines into receipt-web.json.
# The fixture backend must already run (../fixtures/backend/run.sh) on FIXTURE_BASE_URL.
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)"
WEB_PORT="${WEB_PORT:-8792}"
BASE="${FIXTURE_BASE_URL:-http://127.0.0.1:8791}"
CHROME="${CHROME:-$(command -v google-chrome || command -v chrome || command -v chromium)}"
TIMEOUT="${TIMEOUT:-90}"
cd "$APP"
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  flutter build web --debug --dart-define=FIXTURE_BASE_URL="$BASE" ${WEB_BUILD_ARGS:-}
fi
LOG="$APP/build/web-chrome.log"
PROFILE="$(mktemp -d)"
python3 -I -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$APP/build/web" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true; kill $CHROME_PID 2>/dev/null || true' EXIT
sleep 1
"$CHROME" --headless=new --no-sandbox --use-mock-keychain --password-store=basic \
  --disable-gpu --no-first-run --user-data-dir="$PROFILE" \
  --enable-logging=stderr --v=0 "http://127.0.0.1:$WEB_PORT/" >"$LOG" 2>&1 &
CHROME_PID=$!
for _ in $(seq "$TIMEOUT"); do
  grep -q AXIOM_RECEIPT "$LOG" && break
  sleep 1
done
kill $CHROME_PID 2>/dev/null || true
if ! grep -q AXIOM_RECEIPT "$LOG"; then
  echo "no AXIOM_RECEIPT within ${TIMEOUT}s; see $LOG" >&2
  exit 1
fi
python3 -I - "$LOG" "$APP/receipt-web.json" <<'PY'
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
json.dump(receipt, open(sys.argv[2], "w"), indent=2)
for c in receipt["checks"]:
    print(f"AXIOM_CHECK {c['name']} {c['outcome']} {c['message']}")
print(f"receipt-web.json: pass={receipt['pass']} fail={receipt['fail']} skip={receipt['skip']}")
PY
