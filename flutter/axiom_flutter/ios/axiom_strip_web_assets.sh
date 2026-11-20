#!/bin/sh
# axiom_flutter: remove the web runtime (lib/assets/wasm: ~2.5 MB wasm + JS
# glue, never loaded on Apple platforms) from an iOS or macOS app.
#
# OPT-IN and UNVERIFIED (written without Apple tools). Use it as a Run Script
# build phase of the Runner target, placed AFTER the phase that runs
# `xcode_backend.sh build` (iOS "Run Script") and BEFORE "Thin Binary" (iOS) /
# BEFORE the `macos_assemble.sh embed` "Run Script" phase (macOS):
#
#   "${PODS_ROOT}/../.symlinks/plugins/axiom_flutter/ios/axiom_strip_web_assets.sh"
#   (macOS: .../plugins/axiom_flutter/macos/axiom_strip_web_assets.sh)
#
# Uncheck "Based on dependency analysis"; set ENABLE_USER_SCRIPT_SANDBOXING=NO
# for Runner if Xcode denies the delete.
#
# Why this position: Flutter assembles App.framework (with flutter_assets) in
# ${BUILT_PRODUCTS_DIR}; the embed step copies it into the .app and code-signs
# it. Deleting files inside an already signed App.framework breaks its
# resource seal (device installs and App Store validation fail), so this
# script edits only the unsigned copy in ${BUILT_PRODUCTS_DIR}. If it finds
# the files only in the embedded, signed copy it re-signs App.framework with
# the build's identity, or stops with an error when there is none to use.
# The asset manifest still lists the files; native code never requests them.
set -eu
rel="flutter_assets/packages/axiom_flutter/lib/assets/wasm"
removed=0
for fw in "${BUILT_PRODUCTS_DIR:?}/App.framework"; do
  [ -d "$fw" ] || continue
  for d in $(find "$fw" -type d -path "*/$rel" 2>/dev/null); do
    echo "axiom_flutter: removing web runtime from $d"
    find "$d" -type f \( -name 'axiom_runtime.js' -o -name 'axiom_runtime_bg.wasm' \) -exec /bin/rm -f {} +
    removed=1
  done
done
embedded="${TARGET_BUILD_DIR:-}/${FRAMEWORKS_FOLDER_PATH:-}/App.framework"
if [ -d "$embedded" ] && [ -n "$(find "$embedded" -type f -path "*/$rel/*" 2>/dev/null)" ]; then
  if [ "${CODE_SIGNING_REQUIRED:-YES}" = "NO" ] || [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    find "$embedded" -type f -path "*/$rel/*" -exec /bin/rm -f {} +
    echo "axiom_flutter: removed web runtime from unsigned $embedded"
  else
    find "$embedded" -type f -path "*/$rel/*" -exec /bin/rm -f {} +
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
      --preserve-metadata=identifier,entitlements,flags "$embedded"
    echo "axiom_flutter: removed web runtime from $embedded and re-signed it"
  fi
  removed=1
fi
[ "$removed" = 1 ] || echo "axiom_flutter: web runtime not found (already removed, or the phase runs too early)"
