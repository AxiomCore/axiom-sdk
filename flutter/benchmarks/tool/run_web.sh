#!/usr/bin/env bash
# Build the bench app for web (release), serve it, run it in headless Chrome and collect the
# AXIOM_BENCH lines into a JSONL file.
#
#   tool/run_web.sh [out.jsonl]
#   COLD_RUNS=5 BENCH=all SKIP_BUILD=1 WEB_RENDERER_ARGS=--wasm tool/run_web.sh
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
mkdir -p "$WORK" "$(dirname "$OUT")"
: > "$OUT"
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  (cd "$APP" && flutter build web --release --dart-define=BENCH_BASE_URL="$BASE" ${WEB_RENDERER_ARGS:-})
fi
python3 -I -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$APP/build/web" >/dev/null 2>&1 &
SERVER=$!
CHROME_PID=""
trap 'kill $SERVER 2>/dev/null || true; [ -n "$CHROME_PID" ] && kill $CHROME_PID 2>/dev/null || true' EXIT
sleep 1

run_once() { # $1 = bench selection, $2 = label
  local profile log
  profile="$(mktemp -d "$WORK/profile.XXXXXX")"
  log="$profile.log"
  "$CHROME" --headless=new --no-sandbox --use-mock-keychain --password-store=basic \
    --disable-gpu --no-first-run --disable-extensions --user-data-dir="$profile" \
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
echo "wrote $OUT"
