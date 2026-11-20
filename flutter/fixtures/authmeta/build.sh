#!/usr/bin/env bash
# Build the auth-metadata contract and copy it into the integration app's assets
# (integration_app/assets/axiom/authmeta.axiom), then print the endpoint auth it publishes.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
AXIOM="${AXIOM:-axiom}"
OUT="$HERE/.out"
mkdir -p "$OUT"
cd "$HERE"
"$AXIOM" check main.acore
"$AXIOM" build main.acore --out "$OUT/authmeta.axiom"
cp "$OUT/authmeta.axiom" "$HERE/../../integration_app/assets/axiom/authmeta.axiom"
python3 -I - "$OUT/authmeta.axiom" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for e in d["endpoints"]:
    print(e["id"], e["name"], json.dumps(e["auth"]["methods"] if e["auth"] else None))
PY
