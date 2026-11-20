#!/usr/bin/env bash
# Bundle a runtime artifact set into axiom_flutter (lean) and
# axiom_flutter_extensions (full), update every runtime-pin.json and run the
# pin check.
#
#   flutter/axiom_flutter/tool/bundle_runtime.sh <artifact-root> [source description]
#
# <artifact-root> layout (as written by the axiom-runtime build scripts):
#   lean/android/<abi>/libaxiom_runtime.so      -> axiom_flutter jniLibs
#   lean/wasm/axiom_runtime{.js,_bg.wasm}       -> axiom_flutter lib/assets/wasm
#   full/android/<abi>/libaxiom_runtime.so      -> axiom_flutter_extensions jniLibs
#                                                  as libaxiom_runtime_full.so
# (`default/` is accepted instead of `full/`.)  ABIs: arm64-v8a armeabi-v7a x86_64.
# The description defaults to <artifact-root>/BUILD-INFO or BUILD-SOURCE.
# Every library must be path clean (no build-machine paths), or the script stops.
set -euo pipefail
ROOT_ART="$(cd "${1:?usage: bundle_runtime.sh <artifact-root> [source description]}" && pwd)"
PKG="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$PKG/../.." && pwd)"
EXT="$REPO/flutter/axiom_flutter_extensions"
ABIS=(arm64-v8a armeabi-v7a x86_64)

LEAN="$ROOT_ART/lean"
FULL="$ROOT_ART/full"; [ -d "$FULL" ] || FULL="$ROOT_ART/default"
[ -d "$LEAN/android" ] || { echo "missing $LEAN/android" >&2; exit 1; }
[ -d "$LEAN/wasm" ] || { echo "missing $LEAN/wasm" >&2; exit 1; }
[ -d "$FULL/android" ] || { echo "missing $ROOT_ART/full/android (or default/android)" >&2; exit 1; }

DESC="${2:-}"
if [ -z "$DESC" ]; then
  for f in BUILD-SOURCE BUILD-INFO; do
    [ -f "$ROOT_ART/$f" ] && DESC="$(tr '\n' ' ' < "$ROOT_ART/$f" | sed 's/  */ /g;s/ $//')" && break
  done
fi
DESC="${DESC:-$ROOT_ART}"

clean() {
  local n
  n=$(strings -a "$1" | grep -cE '/home/|/Users/|/Volumes/|/root/|\.cargo/registry|/rustup/' || true)
  if [ "$n" != "0" ]; then echo "NOT PATH CLEAN ($n hits): $1" >&2; exit 1; fi
}

RE="$(command -v llvm-readelf || ls "${ANDROID_NDK_HOME:-/nonexistent}"/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | head -1 || true)"
aligned() {
  [ -n "$RE" ] || { echo "warning: llvm-readelf not found, 16 KB alignment not checked" >&2; return 0; }
  if "$RE" -lW "$1" | awk '$1=="LOAD"{print $NF}' | grep -qv '^0x4000$'; then
    echo "LOAD segment not 16 KB aligned: $1" >&2; exit 1
  fi
}

for abi in "${ABIS[@]}"; do
  aligned "$LEAN/android/$abi/libaxiom_runtime.so"
  aligned "$FULL/android/$abi/libaxiom_runtime.so"
  clean "$LEAN/android/$abi/libaxiom_runtime.so"
  clean "$FULL/android/$abi/libaxiom_runtime.so"
done
clean "$LEAN/wasm/axiom_runtime_bg.wasm"

for abi in "${ABIS[@]}"; do
  mkdir -p "$PKG/android/src/main/jniLibs/$abi" "$EXT/android/src/main/jniLibs/$abi"
  cp "$LEAN/android/$abi/libaxiom_runtime.so" "$PKG/android/src/main/jniLibs/$abi/libaxiom_runtime.so"
  cp "$FULL/android/$abi/libaxiom_runtime.so" "$EXT/android/src/main/jniLibs/$abi/libaxiom_runtime_full.so"
done
cp "$LEAN/wasm/axiom_runtime.js" "$LEAN/wasm/axiom_runtime_bg.wasm" "$PKG/lib/assets/wasm/"

python3 - "$REPO" "$DESC" "${ABIS[@]}" <<'PY'
import hashlib, json, sys
from pathlib import Path
repo, desc, abis = Path(sys.argv[1]), sys.argv[2], sys.argv[3:]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
pkg = repo / "flutter/axiom_flutter"
ext = repo / "flutter/axiom_flutter_extensions"

def libs(jni, name, variant):
    return {abi: {"variant": variant,
                  "sha256": sha(jni / abi / name),
                  "bytes": (jni / abi / name).stat().st_size} for abi in abis}

pin_path = repo / "runtime-pin.json"
pin = json.loads(pin_path.read_text())
pin["android"].update({
    "distribution": "bundled",
    "variant": "lean",
    "path": "flutter/axiom_flutter/android/src/main/jniLibs/<abi>/libaxiom_runtime.so",
    "source": desc + " (lean: no executable extensions, no telemetry exporter)",
    "libraries": libs(pkg / "android/src/main/jniLibs", "libaxiom_runtime.so", "lean"),
})
w = pkg / "lib/assets/wasm"
pin["wasm"] = {
    "variant": "lean",
    "runtime_branch": desc + " (lean), scripts/build-wasm-flutter.sh, --remap-path-prefix",
    "axiom_runtime_js_sha256": sha(w / "axiom_runtime.js"),
    "axiom_runtime_bg_wasm_sha256": sha(w / "axiom_runtime_bg.wasm"),
}
pin["apple"]["variant"] = "full"
pin["apple"]["note"] = ("Apple keeps the published full runtime 0.148.6 (cannot be rebuilt on the "
                        "build boxes); axiom_flutter_extensions changes nothing on iOS/macOS.")
text = json.dumps(pin, indent=2) + "\n"
pin_path.write_text(text)
(pkg / "runtime-pin.json").write_text(text)

ext_pin = {
    "schema": 1,
    "package": "axiom_flutter_extensions",
    "android": {
        "distribution": "bundled",
        "variant": "full",
        "path": "flutter/axiom_flutter_extensions/android/src/main/jniLibs/<abi>/libaxiom_runtime_full.so",
        "source": desc + " (full: default features, executable extensions + telemetry)",
        "libraries": libs(ext / "android/src/main/jniLibs", "libaxiom_runtime_full.so", "full"),
    },
    "apple": {"variant": "full", "note": "not bundled: iOS/macOS use axiom_flutter's published full runtime"},
    "wasm": {"note": "not applicable: executable extensions are native only"},
}
(ext / "runtime-pin.json").write_text(json.dumps(ext_pin, indent=2) + "\n")
for abi in abis:
    print(f"{abi}: lean {pin['android']['libraries'][abi]['bytes']} B, "
          f"full {ext_pin['android']['libraries'][abi]['bytes']} B")
PY

python3 "$REPO/scripts/check-runtime-pin.py"
