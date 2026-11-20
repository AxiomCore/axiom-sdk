#!/usr/bin/env bash
# Start the bench server (all clients call it): tool/server.sh [port] [h2port]  (default 8851; h2port 0 = no HTTP/2 TLS listener)
set -euo pipefail
cd "$(dirname "$0")/../api/server"
dart pub get >/dev/null
exec dart run bin/server.dart "${1:-8851}" "${2:-0}"
