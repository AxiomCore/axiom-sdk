#!/usr/bin/env bash
# Starts `axiom auth emulate` in a scratch directory, runs the emulator tests
# against it, and stops it. Usage: tool/emulator.sh [flutter test args...]
#
# Needs: the `axiom` CLI (0.156+) on PATH. The emulator's local store needs
# SQLite >= 3.44; Debian 12 ships 3.40, so point AXIOM_SQLITE_LIBRARY at a
# newer libsqlite3.so (any amalgamation build: gcc -O2 -fPIC -shared sqlite3.c).
# A loopback AXIOM_CLOUD_URL keeps the CLI's Cloud access gate out of the way
# on machines that are not registered (the emulator makes no Cloud call).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
work="${AXIOM_AUTH_EMU_DIR:-$(mktemp -d)}"
port="${AXIOM_AUTH_EMU_PORT:-18777}"
mkdir -p "$work/auth"
cat > "$work/auth/config.local.json" <<JSON
{
  "format": "axiom-auth-config/v1",
  "source": {"kind": "local", "project": "fluttertest"},
  "settings": {
    "enabled": true,
    "signup_policy": "open",
    "enabled_methods": ["password", "email_code"],
    "require_verified_email": true,
    "password_min_length": 8,
    "access_ttl_seconds": 900,
    "session_idle_seconds": 1209600,
    "session_absolute_seconds": 2592000,
    "redirect_urls": ["http://127.0.0.1:5173/auth/callback", "com.axiomcore.fluttertest:/auth/callback"],
    "allowed_origins": ["http://127.0.0.1:5173"],
    "app_name": "Flutter test",
    "email_sender": "platform"
  },
  "providers": [],
  "trusted_issuers": [],
  "policy": {"format": "axiom-auth-policy/v1", "permissions": [], "roles": []},
  "outbound": {"webhooks": [], "hooks": []}
}
JSON
export AXIOM_CLOUD_URL="${AXIOM_CLOUD_URL:-http://127.0.0.1:9}"
log="$work/emulator.log"
( cd "$work" && exec axiom auth emulate --port "$port" --identity alice@example.com --identity bob@example.com ) >"$log" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do
  issuer="$(grep -Eo 'issuer +http://[^ ]+' "$log" | awk '{print $2}' || true)"
  [ -n "$issuer" ] && break
  if ! kill -0 $pid 2>/dev/null; then cat "$log"; exit 1; fi
  sleep 0.5
done
[ -n "${issuer:-}" ] || { cat "$log"; exit 1; }
echo "emulator: $issuer"
cd "$here"
AXIOM_AUTH_ISSUER="$issuer" flutter test "${@:-test/emulator_test.dart}"
