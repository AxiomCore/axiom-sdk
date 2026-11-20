#!/usr/bin/env bash
# Variant check: build the fixture with a second variant that includes a subset of endpoints, run
# the generator with --variant, and assert the generated client contains only those endpoints.
#
#   fixtures/tool/variant-check.sh            exit 0 = pass, 1 = generator emitted extra endpoints,
#                                             2 = the CLI could not build the variant (see below)
#
# CLI 0.156.0 result: `axiom build --variant mobile` fails for every managed endpoint the variant
# leaves out: "AXSERVER_AUTHORING at <endpoint>: handle() endpoint is not included in this contract"
# (also with exclude:, also for axiom_flutter_generator/test/golden/extras). `axiom explain
# --variant` works, so only the build/check step refuses. Product finding for the CLI owner.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/../backend"
GEN="$HERE/../../axiom_flutter_generator"
APP="$HERE/../../integration_app"
AXIOM="${AXIOM:-axiom}"
INCLUDE='"echo", "everything", "createItem"'
WORK="$(mktemp -d)"
cp "$FIX/AxiomDeps.toml" "$WORK/"
sed "s/^variant default(include: \[\"\*\"\])/&\nvariant mobile(include: [$INCLUDE])/" "$FIX/main.acore" > "$WORK/main.acore"
grep -q '^variant mobile' "$WORK/main.acore"
echo "explain --variant mobile (endpoints):"
"$AXIOM" explain "$WORK/main.acore" --variant mobile | python3 -I -c 'import json,sys; print(" ", sorted(json.load(sys.stdin)["endpoints"]))'
if [ -n "${VARIANT_CONTRACT:-}" ]; then
  cp "$VARIANT_CONTRACT" "$WORK/mobile.axiom"   # test hook: skip the build
elif ! (cd "$WORK" && "$AXIOM" build main.acore --variant mobile --out "$WORK/mobile.axiom"); then
  echo "VARIANT_CHECK BLOCKED: axiom build --variant mobile failed (CLI limitation above)" >&2
  exit 2
fi
mkdir -p "$WORK/app/assets/axiom" "$WORK/app/lib"
printf "name: variant_probe\nenvironment:\n  sdk: ^3.8.0\n" > "$WORK/app/pubspec.yaml"
cp "$WORK/mobile.axiom" "$WORK/app/assets/axiom/fixture.axiom"
printf 'framework = "flutter"\n\n[contracts]\n\n[contracts.fixture]\nsource = "%s"\n' "$WORK/mobile.axiom" > "$WORK/app/AxiomDeps.toml"
(cd "$APP" && dart run axiom_flutter_generator:generate --config "$WORK/app/AxiomDeps.toml" --out axiom_generated \
   --project-root "$WORK/app" --variant mobile)
python3 -I - "$WORK/app/lib/axiom_generated/axiom_sdk.dart" "$INCLUDE" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
want = set(re.findall(r'"(\w+)"', sys.argv[2]))
m = re.search(r"endpointIds = <String, int>\{(.*?)\};", src, re.S) or re.search(r"endpointIds = \{(.*?)\};", src, re.S)
got = set(re.findall(r"'(\w+)':", m.group(1))) if m else set()
print("generated endpoints:", sorted(got))
if got != want:
    print("VARIANT_CHECK FAIL: expected", sorted(want)); sys.exit(1)
print("VARIANT_CHECK PASS")
PY
