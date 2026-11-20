#!/usr/bin/env bash
# Sign a built contract the way axiom-runtime verifies it and write the proof next to it.
#
#   fixtures/tool/sign.sh [contract.axiom] [out.json]
#
# Defaults: integration_app/assets/axiom/fixture.axiom -> integration_app/assets/axiom/fixture.signed.json
#
# Format (axiom-runtime src/runtime/mod.rs Runtime::verify_signature, src/ffi/api.rs):
#   signature = base64(Ed25519.sign(privateKey, SHA-256(contract bytes)))   (64 raw bytes -> 88 chars)
#   publicKey = base64(raw 32-byte Ed25519 public key)                      (44 chars)
#   sha256    = lowercase hex SHA-256 of the contract bytes (axiom_load_contract_locked expected_sha256)
# The key pair below is a FIXTURE-ONLY test key committed in the repo; never use it for a real contract.
# The written JSON also carries a second public key (wrongPublicKey) for the negative check.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/../../integration_app"
IN="${1:-$APP/assets/axiom/fixture.axiom}"
OUT="${2:-$APP/assets/axiom/fixture.signed.json}"
KEY="$HERE/fixture-signing-key.pem"
WRONG="$HERE/fixture-wrong-key.pem"
[ -f "$KEY" ] || openssl genpkey -algorithm ed25519 -out "$KEY"
[ -f "$WRONG" ] || openssl genpkey -algorithm ed25519 -out "$WRONG"
TMP="$(mktemp -d)"
openssl dgst -sha256 -binary "$IN" > "$TMP/digest"
openssl pkeyutl -sign -inkey "$KEY" -rawin -in "$TMP/digest" -out "$TMP/sig"
# The raw public key is the last 32 bytes of the 44-byte DER SubjectPublicKeyInfo.
pub() { openssl pkey -in "$1" -pubout -outform DER | tail -c 32 | base64 -w0; }
SIG="$(base64 -w0 < "$TMP/sig")"
PUB="$(pub "$KEY")"
WPUB="$(pub "$WRONG")"
SHA="$(sha256sum "$IN" | cut -d' ' -f1)"
# Self-check with openssl before writing anything.
openssl pkey -in "$KEY" -pubout -out "$TMP/pub.pem"
openssl pkeyutl -verify -pubin -inkey "$TMP/pub.pem" -rawin -in "$TMP/digest" -sigfile "$TMP/sig" >/dev/null
cat > "$OUT" <<JSON
{
  "contract": "$(basename "$IN")",
  "sha256": "$SHA",
  "signature": "$SIG",
  "publicKey": "$PUB",
  "wrongPublicKey": "$WPUB",
  "note": "fixture-only key (flutter/fixtures/tool/fixture-signing-key.pem); signature = base64(Ed25519(SHA-256(bytes)))"
}
JSON
echo "signed $IN -> $OUT"
echo "sha256    $SHA"
echo "publicKey $PUB"
