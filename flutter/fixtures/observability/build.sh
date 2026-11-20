#!/usr/bin/env bash
# Build the observed contract: the main fixture plus an observability block that exports traces to
# the local sink (sink.py, default http://127.0.0.1:8804/v1/traces). Copies it into the app assets
# and signs it: the runtime starts the exporter ONLY for a verified (signed) contract
# (axiom-runtime src/runtime/mod.rs: "Never activate an exporter from an unsigned/debug artifact").
#   OTLP_URL=http://127.0.0.1:8804/v1/traces SAMPLE_RATE=1.0 fixtures/observability/build.sh
# Sampling off: SAMPLE_RATE=0.0 (or enabled: false) and rebuild.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
AXIOM="${AXIOM:-axiom}"
URL="${OTLP_URL:-http://127.0.0.1:8804/v1/traces}"
RATE="${SAMPLE_RATE:-1.0}"
OUT="$HERE/.out"
APP="$HERE/../../integration_app"
mkdir -p "$OUT"
cp "$HERE/../backend/AxiomDeps.toml" "$OUT/"
sed "s#^variant default(include: \[\"\*\"\])#&\nobservability(enabled: true, telemetryUrl: \"$URL\", sampleRate: $RATE)#" \
  "$HERE/../backend/main.acore" > "$OUT/main.acore"
grep -q '^observability(' "$OUT/main.acore"
(cd "$OUT" && "$AXIOM" check main.acore && "$AXIOM" build main.acore --out "$OUT/observed.axiom")
cp "$OUT/observed.axiom" "$APP/assets/axiom/observed.axiom"
"$HERE/../tool/sign.sh" "$APP/assets/axiom/observed.axiom" "$APP/assets/axiom/observed.signed.json"
python3 -I -c 'import json,sys; print("observability:", json.load(open(sys.argv[1]))["observability"])' "$OUT/observed.axiom"
