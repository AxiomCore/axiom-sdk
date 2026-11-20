#!/usr/bin/env bash
# Start the bench server (all three clients call it): tool/server.sh [port]  (default 8851)
set -euo pipefail
cd "$(dirname "$0")/../api/server"
dart pub get >/dev/null
exec dart run bin/server.dart "${1:-8851}"
