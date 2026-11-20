#!/usr/bin/env bash
# Numbers of record in one go: 3 web runs (release, headless Chrome, fresh profile per launch,
# h1 full set + h2 pass) and 3 VM runs, then merge and render.
#
#   AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so DATE=2026-11-21 tool/run_record.sh
#
# Env: PORT (bench server, default 8771; TLS listener PORT+2), WEB_PORT (default 8792),
# WEB_PORT_LOCK / LOCK_TRASH (shared page-port lock, see run_web.sh), RUNS (3), SKIP_WEB=1,
# SKIP_VM=1, WEB_LABEL (linux-chrome-idle), VM_LABEL (linux-vm), EXTRA (extra JSON for
# collect_results.py: machine details, commits), BEFORE (results file to compare against).
# Starts its own bench server unless SERVER_RUNNING=1. Kills only the PIDs it started.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="${PORT:-8771}"
DATE="${DATE:-$(date -u +%F)}"
RUNS="${RUNS:-3}"
WEB_LABEL="${WEB_LABEL:-linux-chrome-idle}"
VM_LABEL="${VM_LABEL:-linux-vm}"
BEFORE="${BEFORE:-results/2026-11-20-linux-chrome-idle.json}"
BASE="http://127.0.0.1:$PORT"
export BENCH_BASE_URL="$BASE"
SRV=""
cleanup() { [ -n "$SRV" ] && kill "$SRV" 2>/dev/null || true; }
trap cleanup EXIT
if [ "${SERVER_RUNNING:-0}" != "1" ]; then
  (cd api/server && dart pub get >/dev/null)
  dart run api/server/bin/server.dart "$PORT" "$((PORT + 2))" > "results/.server-$DATE.log" 2>&1 &
  SRV=$!
  for _ in $(seq 60); do curl -sf "$BASE/_ready" >/dev/null && break; sleep 1; done
fi
top -bn1 | head -15 > "results/.top-$DATE.txt"
cat "results/.top-$DATE.txt"

if [ "${SKIP_WEB:-0}" != "1" ]; then
  for i in $(seq "$RUNS"); do
    skip=1; [ "$i" = 1 ] && skip="${SKIP_BUILD:-0}"
    SKIP_BUILD="$skip" COLD_RUNS="${COLD_RUNS:-5}" BENCH="${BENCH:-all,extra}" \
      H2_BENCH="${H2_BENCH:-clients,parallel,ttfi}" WEB_PORT="${WEB_PORT:-8792}" \
      tool/run_web.sh "results/raw-web-$DATE-run$i.jsonl" | grep -v '^AXIOM_BENCH' || true
  done
  python3 tool/collect_results.py --label "$WEB_LABEL" \
    --web-runs $(for i in $(seq "$RUNS"); do echo "results/raw-web-$DATE-run$i.jsonl"; done) \
    ${EXTRA:+--extra "$EXTRA"} --out "results/$DATE-$WEB_LABEL.json"
fi
if [ "${SKIP_VM:-0}" != "1" ]; then
  : "${AXIOM_RUNTIME_LIB:?set AXIOM_RUNTIME_LIB for the VM runs}"
  dart run tool/vm_bench.dart --lib "$AXIOM_RUNTIME_LIB" --runs "$RUNS" --base "$BASE" \
    --bench "${VM_SET:-latency,cache,decode,extra}" --h2 "${VM_H2:-clients,parallel}" --cold "${COLD_RUNS:-5}" \
    --out "results/raw-vm-$DATE" | grep -E '^(==|wrote)' || true
  python3 tool/collect_results.py --label "$VM_LABEL" \
    --web-runs $(for i in $(seq "$RUNS"); do echo "results/raw-vm-$DATE-run$i.jsonl"; done) \
    --note "Native column: Dart VM in flutter_tester (JIT) on the same Linux x86_64 container, host runtime library $(basename "$(dirname "$(dirname "$AXIOM_RUNTIME_LIB")")")/$(basename "$(dirname "$AXIOM_RUNTIME_LIB")"); not a phone." \
    ${EXTRA:+--extra "$EXTRA"} --out "results/$DATE-$VM_LABEL.json"
fi
W="results/$DATE-$WEB_LABEL.json"; V="results/$DATE-$VM_LABEL.json"
SIZE_ARG=""; [ -f "results/size-table-$DATE.json" ] && SIZE_ARG="--size-table results/size-table-$DATE.json"
if [ -f "$W" ]; then
  python3 tool/render_readme.py --summary "$W" $([ -f "$V" ] && echo "--vm $V") $SIZE_ARG > results/README-SUMMARY.md
  python3 tool/render_readme.py "$W" $([ -f "$V" ] && echo "$V") > results/README-TABLE.md
  [ -f "$BEFORE" ] && python3 tool/render_readme.py --compare "$BEFORE" "$W" > "results/BEFORE-AFTER-$DATE.md"
fi
echo "done: $W $V"
