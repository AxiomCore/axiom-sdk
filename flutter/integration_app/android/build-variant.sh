#!/usr/bin/env bash
# Build the integration app APK with the lean default runtime or with the
# axiom_flutter_extensions add-on (full runtime).
#
#   android/build-variant.sh lean|ext <flutter build apk args...>
#   e.g. android/build-variant.sh ext --release --target-platform android-arm64 \
#          --dart-define=FIXTURE_BASE_URL=http://10.0.2.2:8791 ...
#
# `ext` adds axiom_flutter_extensions (path ../axiom_flutter_extensions) to
# pubspec.yaml for the build only and restores the original file afterwards.
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)"
VARIANT="${1:?usage: build-variant.sh lean|ext <flutter build apk args>}"; shift
cd "$APP"
case "$VARIANT" in
  lean) exec flutter build apk "$@" ;;
  ext)
    cp pubspec.yaml .pubspec.yaml.lean
    restore() { mv .pubspec.yaml.lean pubspec.yaml; flutter pub get >/dev/null 2>&1 || true; }
    trap restore EXIT
    python3 - <<'PY'
from pathlib import Path
p = Path("pubspec.yaml"); s = p.read_text()
s = s.replace("dependency_overrides:\n",
              "dependency_overrides:\n  axiom_flutter_extensions:\n    path: ../axiom_flutter_extensions\n", 1)
s = s.replace("  axiom_flutter: ^0.150.0\n", "  axiom_flutter: ^0.150.0\n  axiom_flutter_extensions: ^0.150.1\n", 1)
p.write_text(s)
PY
    flutter build apk "$@"
    ;;
  *) echo "unknown variant $VARIANT (lean|ext)" >&2; exit 2 ;;
esac
