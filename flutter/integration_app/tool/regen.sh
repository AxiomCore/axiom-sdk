#!/usr/bin/env bash
# Rebuild the fixture contract and regenerate lib/axiom_generated with the local generator.
#
#   tool/regen.sh                 # build contract, copy asset, run ../axiom_flutter_generator
#   tool/regen.sh --base-url URL  # extra flags go to the generator
#   USE_PULL=1 tool/regen.sh      # go through `axiom pull` instead (CLI copies the asset and
#                                 # runs `dart run axiom_flutter_generator:generate`)
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$APP/../fixtures/backend"
AXIOM="${AXIOM:-axiom}"
OUT="$FIX/.out"
mkdir -p "$OUT"
"$AXIOM" build "$FIX/main.acore" --out "$OUT/backend.axiom"
cd "$APP"
if [ "${USE_PULL:-0}" = "1" ]; then
  "$AXIOM" pull "$OUT/backend.axiom" --framework flutter --name fixture --out lib/axiom_generated "$@"
else
  mkdir -p assets/axiom
  cp "$OUT/backend.axiom" assets/axiom/fixture.axiom
  # The path dev_dependency in pubspec.yaml resolves this to ../axiom_flutter_generator.
  dart run axiom_flutter_generator:generate --config AxiomDeps.toml --out axiom_generated \
    --project-root "$APP" "$@"
fi
