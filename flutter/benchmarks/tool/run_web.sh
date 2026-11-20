#!/usr/bin/env bash
# Build the bench app for web (release), serve it, run it in headless Chrome and collect the
# AXIOM_BENCH lines into a JSONL file.
#
#   tool/run_web.sh [out.jsonl]
#   COLD_RUNS=5 BENCH=all SKIP_BUILD=1 WEB_RENDERER_ARGS=--wasm tool/run_web.sh
#   BENCH=all,extra H2_BENCH=clients,parallel,ttfi tool/run_web.sh   (h2 pass: ?proto=h2, needs the
#       server's TLS listener on BENCH_BASE_URL port + 2: tool/server.sh 8851 8853)
#   WEB_PORT_LOCK=/home/node/fp/web-port.lock LOCK_TRASH=<dir>   take the shared page-port lock
#       (noclobber) for the run and move it to LOCK_TRASH afterwards (no rm)
#
# Needs the bench server (tool/server.sh) on BENCH_BASE_URL (default http://127.0.0.1:8851).
# Each Chrome launch uses a fresh profile under $WORK (no HTTP cache), and only the PID this
# script started is killed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
OUT="${1:-$ROOT/results/raw-web.jsonl}"
WEB_PORT="${WEB_PORT:-8852}"
BASE="${BENCH_BASE_URL:-http://127.0.0.1:8851}"
CHROME="${CHROME:-$(command -v google-chrome || command -v chrome || command -v chromium)}"
WORK="${WORK:-$ROOT/build/chrome}"
COLD_RUNS="${COLD_RUNS:-5}"
BENCH="${BENCH:-all}"
TIMEOUT="${TIMEOUT:-600}"
H2_BENCH="${H2_BENCH:-none}"
mkdir -p "$WORK" "$(dirname "$OUT")"
LOCKED=""
if [ -n "${WEB_PORT_LOCK:-}" ]; then
  if ! ( set -o noclobber; echo "bench run_web.sh pid $$ port $WEB_PORT $(date -u +%FT%TZ)" > "$WEB_PORT_LOCK" ) 2>/dev/null; then
    echo "page-port lock $WEB_PORT_LOCK is held: $(cat "$WEB_PORT_LOCK")" >&2
    exit 3
  fi
  LOCKED=1
fi
release_lock() {
  if [ -n "$LOCKED" ]; then
    mkdir -p "${LOCK_TRASH:?LOCK_TRASH must be set with WEB_PORT_LOCK}"
    mv "$WEB_PORT_LOCK" "$LOCK_TRASH/web-port.lock.$(date -u +%H%M%S).$$"
    LOCKED=""
  fi
}
: > "$OUT"
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  (cd "$APP" && flutter build web --release --dart-define=BENCH_BASE_URL="$BASE" ${WEB_RENDERER_ARGS:-})
fi
python3 -I -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$APP/build/web" >/dev/null 2>&1 &
SERVER=$!
CHROME_PID=""
trap 'kill $SERVER 2>/dev/null || true; [ -n "$CHROME_PID" ] && kill $CHROME_PID 2>/dev/null || true; release_lock' EXIT
sleep 1

run_once() { # $1 = bench selection, $2 = label
  local profile log
  profile="$(mktemp -d "$WORK/profile.XXXXXX")"
  log="$profile.log"
  "$CHROME" --headless=new --no-sandbox --use-mock-keychain --password-store=basic \
    --disable-gpu --no-first-run --disable-extensions --user-data-dir="$profile" \
    ${CHROME_EXTRA_ARGS:-} \
    --enable-logging=stderr --v=0 "http://127.0.0.1:$WEB_PORT/?bench=$1" >"$log" 2>&1 &
  CHROME_PID=$!
  local ok=0
  for _ in $(seq "$TIMEOUT"); do
    if grep -q 'AXIOM_BENCH {\\\?"bench\\\?":\\\?"done' "$log" 2>/dev/null || grep -q '"bench":"done"' "$log"; then ok=1; break; fi
    sleep 1
  done
  kill "$CHROME_PID" 2>/dev/null || true
  wait "$CHROME_PID" 2>/dev/null || true
  CHROME_PID=""
  [ "$ok" = 1 ] || echo "run $2 ($1): no done line within ${TIMEOUT}s; see $log" >&2
  python3 -I - "$log" "$OUT" "$2" <<'PY'
import json, sys
log, out, label = sys.argv[1:4]
with open(out, "a") as f:
    for line in open(log, encoding="utf-8", errors="replace"):
        if "AXIOM_BENCH " not in line:
            continue
        raw = line.split("AXIOM_BENCH ", 1)[1]
        raw = raw[: raw.rfind("}") + 1]
        try:
            rec = json.loads(raw)
        except json.JSONDecodeError:
            rec = json.loads(raw.encode().decode("unicode_escape"))
        rec["run"] = label
        f.write(json.dumps(rec) + "\n")
        print("AXIOM_BENCH", json.dumps(rec))
PY
}

for i in $(seq "$COLD_RUNS"); do
  for c in axiom dio http; do run_once "cold:$c" "cold-$c-$i"; done
done
[ "$BENCH" = "none" ] || run_once "$BENCH" "main"
if [ "$H2_BENCH" != "none" ]; then
  # The self-signed certificate of the TLS listener is accepted by this Chrome instance only.
  CHROME_EXTRA_ARGS="--ignore-certificate-errors" run_once "$H2_BENCH&proto=h2" "main-h2"
fi
echo "wrote $OUT"
