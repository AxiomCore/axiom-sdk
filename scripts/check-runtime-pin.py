#!/usr/bin/env python3
"""Check that every AxiomRuntime pin in axiom-sdk agrees with runtime-pin.json.

Checks:
  * flutter/axiom_flutter/runtime-pin.json is byte-identical to runtime-pin.json
  * both podspecs read the pin file and carry no literal version or digest
  * swift/Package.swift binaryTarget url and checksum match the Apple pin
  * the Apple url names the pinned runtime version
  * variants: axiom_flutter bundles the "lean" Android libraries and wasm,
    axiom_flutter_extensions bundles the "full" Android libraries
    (libaxiom_runtime_full.so); every bundled library matches its pinned sha256
  * with --download: the Apple archive digest equals the pinned sha256

Exit status 0 when all checks pass, 1 otherwise.
"""
import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PIN = ROOT / "runtime-pin.json"
FLUTTER_PIN = ROOT / "flutter/axiom_flutter/runtime-pin.json"
PODSPECS = [
    ROOT / "flutter/axiom_flutter/ios/axiom_flutter.podspec",
    ROOT / "flutter/axiom_flutter/macos/axiom_flutter.podspec",
]
EXT_PIN = ROOT / "flutter/axiom_flutter_extensions/runtime-pin.json"
PACKAGE_SWIFT = ROOT / "swift/Package.swift"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")

failures = []


def check(ok, message):
    print(("ok   " if ok else "FAIL ") + message)
    if not ok:
        failures.append(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--download", action="store_true",
                        help="download the Apple archive and verify its sha256")
    args = parser.parse_args()

    pin_bytes = PIN.read_bytes()
    pin = json.loads(pin_bytes)
    version = pin["runtime_version"]
    apple = pin["apple"]
    print(f"runtime-pin.json: runtime {version}")

    check(FLUTTER_PIN.exists() and FLUTTER_PIN.read_bytes() == pin_bytes,
          f"{FLUTTER_PIN.relative_to(ROOT)} identical to runtime-pin.json")
    check(bool(SHA_RE.match(apple["sha256"])), "apple.sha256 is 64 lowercase hex characters")
    check(f"/v{version}/{apple['archive']}" in apple["url"],
          "apple.url names runtime_version and archive")

    for spec in PODSPECS:
        text = spec.read_text()
        rel = spec.relative_to(ROOT)
        check("runtime-pin.json" in text and "runtime_pin.fetch('apple')" in text,
              f"{rel} reads runtime-pin.json")
        check(not re.search(r"\b[0-9a-f]{64}\b", text), f"{rel} has no literal sha256")
        check(not re.search(r"runtime_version\s*=\s*'", text),
              f"{rel} has no literal runtime version")

    swift = PACKAGE_SWIFT.read_text()
    url = re.search(r'url:\s*"([^"]+AxiomRuntime[^"]*)"', swift)
    checksum = re.search(r'checksum:\s*"([0-9a-f]{64})"', swift)
    check(bool(url) and url.group(1) == apple["url"], "swift/Package.swift url matches apple.url")
    check(bool(checksum) and checksum.group(1) == apple["sha256"],
          "swift/Package.swift checksum matches apple.sha256")

    wasm = pin.get("wasm") or {}
    wasm_dir = ROOT / "flutter/axiom_flutter/lib/assets/wasm"
    for key, name in (("axiom_runtime_js_sha256", "axiom_runtime.js"),
                      ("axiom_runtime_bg_wasm_sha256", "axiom_runtime_bg.wasm")):
        expected = wasm.get(key)
        if expected is None:
            print(f"skip wasm.{key} is not pinned yet")
            continue
        actual = hashlib.sha256((wasm_dir / name).read_bytes()).hexdigest()
        check(actual == expected, f"bundled {name} matches wasm.{key}")

    def check_libs(section, jni, name, variant, label):
        if section.get("distribution") != "bundled":
            return
        check(section.get("variant") == variant, f"{label} android.variant is {variant!r}")
        for abi, entry in sorted((section.get("libraries") or {}).items()):
            check(entry.get("variant") == variant, f"{label} {abi} variant is {variant!r}")
            lib = jni / abi / name
            ok = lib.exists() and hashlib.sha256(lib.read_bytes()).hexdigest() == entry.get("sha256")
            check(ok, f"{lib.relative_to(ROOT)} matches pinned sha256")

    check_libs(pin.get("android") or {}, ROOT / "flutter/axiom_flutter/android/src/main/jniLibs",
               "libaxiom_runtime.so", "lean", "axiom_flutter")
    if wasm.get("variant") is not None:
        check(wasm.get("variant") == "lean", "axiom_flutter wasm.variant is 'lean'")
    if EXT_PIN.exists():
        ext = json.loads(EXT_PIN.read_bytes())
        check_libs(ext.get("android") or {}, ROOT / "flutter/axiom_flutter_extensions/android/src/main/jniLibs",
                   "libaxiom_runtime_full.so", "full", "axiom_flutter_extensions")

    if args.download:
        print(f"downloading {apple['url']}")
        digest = hashlib.sha256()
        size = 0
        with urllib.request.urlopen(apple["url"], timeout=120) as response:
            while True:
                chunk = response.read(1 << 20)
                if not chunk:
                    break
                digest.update(chunk)
                size += len(chunk)
        actual = digest.hexdigest()
        print(f"downloaded {size} bytes, sha256 {actual}")
        check(actual == apple["sha256"], "downloaded Apple archive matches apple.sha256")

    if failures:
        print(f"{len(failures)} check(s) failed")
        return 1
    print("all runtime pin checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
