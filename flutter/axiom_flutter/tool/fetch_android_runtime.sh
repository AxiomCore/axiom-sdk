#!/usr/bin/env bash
# Copy a set of Android runtime libraries into the package and record their
# sha256 in runtime-pin.json (package copy and repo root copy).
#
#   tool/fetch_android_runtime.sh <dir> [source description]
#
# <dir> holds <abi>/libaxiom_runtime.so for arm64-v8a, armeabi-v7a, x86_64,
# as written by axiom-runtime/scripts/build-android-so.sh <dir>.
# AXIOM_ANDROID_RUNTIME_DIR can be used instead of the first argument.
# --check verifies the committed libraries against runtime-pin.json and exits.
# The libraries must be the LEAN build (variant "lean"). To refresh lean,
# wasm and the full add-on runtime together use tool/bundle_runtime.sh.
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
JNI="$PKG/android/src/main/jniLibs"
ABIS=(arm64-v8a armeabi-v7a x86_64)
PINS=("$PKG/runtime-pin.json")
[ -f "$PKG/../../runtime-pin.json" ] && PINS+=("$(cd "$PKG/../.." && pwd)/runtime-pin.json")

if [ "${1:-}" = "--check" ]; then
  python3 - "$PKG/runtime-pin.json" "$JNI" "${ABIS[@]}" <<'PY'
import hashlib, json, sys
pin = json.load(open(sys.argv[1]))["android"]["libraries"]
bad = 0
for abi in sys.argv[3:]:
    got = hashlib.sha256(open(f"{sys.argv[2]}/{abi}/libaxiom_runtime.so", "rb").read()).hexdigest()
    ok = got == pin[abi]["sha256"]
    bad |= not ok
    print(("OK  " if ok else "BAD ") + abi + " " + got)
sys.exit(bad)
PY
  exit $?
fi

SRC="${1:-${AXIOM_ANDROID_RUNTIME_DIR:-}}"
DESC="${2:-local build from $SRC}"
[ -n "$SRC" ] || { echo "usage: $0 <dir> [source description] | --check" >&2; exit 2; }
for abi in "${ABIS[@]}"; do
  f="$SRC/$abi/libaxiom_runtime.so"
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
  # 16 KB page alignment of every LOAD segment (Android 15+ devices).
  if command -v llvm-readelf >/dev/null || [ -n "${ANDROID_NDK_HOME:-}" ]; then
    RE="$(command -v llvm-readelf || ls "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin/llvm-readelf | head -1)"
    if "$RE" -lW "$f" | awk '$1=="LOAD"{print $NF}' | grep -qv '^0x4000$'; then
      echo "$f: LOAD segment not 16 KB aligned" >&2; exit 1
    fi
  fi
done
for abi in "${ABIS[@]}"; do
  mkdir -p "$JNI/$abi"
  cp "$SRC/$abi/libaxiom_runtime.so" "$JNI/$abi/libaxiom_runtime.so"
done
for pin in "${PINS[@]}"; do
  python3 - "$pin" "$JNI" "$DESC" "${ABIS[@]}" <<'PY'
import hashlib, json, os, sys
path, jni, desc, abis = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
pin = json.load(open(path))
libs = {}
for abi in abis:
    f = f"{jni}/{abi}/libaxiom_runtime.so"
    libs[abi] = {"variant": "lean", "sha256": hashlib.sha256(open(f, "rb").read()).hexdigest(), "bytes": os.path.getsize(f)}
pin["android"] = {
    "distribution": "bundled",
    "variant": "lean",
    "path": "flutter/axiom_flutter/android/src/main/jniLibs/<abi>/libaxiom_runtime.so",
    "source": desc,
    "archive": None, "url": None, "sha256": None,
    "libraries": libs,
}
with open(path, "w") as fh:
    json.dump(pin, fh, indent=2)
    fh.write("\n")
print("updated", path)
PY
done
