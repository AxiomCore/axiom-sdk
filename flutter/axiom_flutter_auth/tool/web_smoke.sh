#!/usr/bin/env bash
# Web smoke: emulator + example app built for web, served on the emulator's
# allowed origin (http://127.0.0.1:5173), opened in headless Chrome. The app
# signs in with password, stores the refresh record in sessionStorage, reloads,
# restores the session from sessionStorage, reads the user and signs out.
# Prints the AXIOM_SMOKE console lines. Needs AXIOM_SQLITE_LIBRARY (see emulator.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
work="${AXIOM_AUTH_EMU_DIR:-$(mktemp -d)}"
port="${AXIOM_AUTH_EMU_PORT:-18777}"
export AXIOM_CLOUD_URL="${AXIOM_CLOUD_URL:-http://127.0.0.1:9}"
mkdir -p "$work"
( cd "$work" && exec axiom auth emulate --port "$port" ) >"$work/emulator.log" 2>&1 &
emu=$!
srv=""
trap 'kill $emu 2>/dev/null || true; [ -n "$srv" ] && kill $srv 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do
  issuer="$(grep -Eo 'issuer +http://[^ ]+' "$work/emulator.log" | awk '{print $2}' || true)"
  [ -n "$issuer" ] && break; sleep 0.5
done
email="web$(date +%s)@example.com"
python3 - "$issuer" "$email" <<'PY'
import json, re, sys, time, urllib.request
iss, email = sys.argv[1], sys.argv[2]
def post(p, b):
    r = urllib.request.Request(iss + p, json.dumps(b).encode(), {"content-type": "application/json"})
    return json.load(urllib.request.urlopen(r))
ch = post("/v1/signup", {"email": email, "password": "correct horse battery"})["challenge_id"]
origin = iss.split("/local/")[0]
mail = json.dumps(json.load(urllib.request.urlopen(origin + "/local/mail.json")))
code = [m for m in re.findall(r'Your code is (\d{6})', mail)]
post("/v1/signup/verify", {"challenge_id": ch, "code": code[-1] if mail.rfind(email) >= 0 else ""})
print("user created", email)
PY
cd "$here/example"
flutter build web --release --no-tree-shake-icons \
  --dart-define=AXIOM_AUTH_ISSUER="$issuer" --dart-define=AXIOM_AUTH_SMOKE_EMAIL="$email" >/dev/null
( cd build/web && exec python3 -m http.server 5173 --bind 127.0.0.1 ) >/dev/null 2>&1 &
srv=$!
sleep 1
prof="$(mktemp -d)"
timeout 40 "${CHROME_EXECUTABLE:-google-chrome}" --headless=new --no-sandbox --use-mock-keychain --password-store=basic \
  --user-data-dir="$prof" --enable-logging=stderr --v=0 http://127.0.0.1:5173/ 2>&1 \
  | grep -o 'AXIOM_SMOKE[^"]*' || true
