#!/usr/bin/env bash
# Build and run the Flutter SDK fixture backend on 127.0.0.1:${1:-8791}.
set -euo pipefail
PORT="${1:-8791}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${FIXTURE_OUT:-$HERE/.out}"
AXIOM="${AXIOM:-axiom}"
mkdir -p "$OUT"
cd "$HERE"
"$AXIOM" check main.acore
"$AXIOM" build main.acore --out "$OUT/backend.axiom"
"$AXIOM" server deployment "$OUT/backend.axiom" "$OUT/backend.server.json" --output "$OUT/deployment.json.new" --static-key >/dev/null
mv -f "$OUT/deployment.json.new" "$OUT/deployment.json"
python3 -I "$HERE/tool/jwt.py" patch "$OUT/deployment.json"
export AXIOM_FIXTURE_JWT_SECRET="$(python3 -I "$HERE/tool/jwt.py" secret)"
echo "fixture bearer token: $(python3 -I "$HERE/tool/jwt.py" token)"
echo "fixture api key:      fixture-api-key"
exec "$AXIOM" run main.acore --deployment "$OUT/deployment.json" --host 127.0.0.1 --port "$PORT"
