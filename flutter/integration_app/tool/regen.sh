#!/usr/bin/env bash
# Rebuild the fixture contract and regenerate lib/axiom_generated with the local generator.
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$APP/../fixtures/backend"
AXIOM="${AXIOM:-axiom}"
OUT="$FIX/.out"
mkdir -p "$OUT"
"$AXIOM" build "$FIX/main.acore" --out "$OUT/backend.axiom"
cd "$APP"
# `axiom pull` copies the contract to assets/axiom/fixture.axiom and runs
# `dart run axiom_flutter_generator:generate`, which resolves to ../axiom_flutter_generator
# through the path dev_dependency in pubspec.yaml.
"$AXIOM" pull "$OUT/backend.axiom" --framework flutter --name fixture --out lib/axiom_generated
dart format lib/axiom_generated >/dev/null || true
