#!/usr/bin/env python3
"""Release checks for @axiomcore/auth-web.

verify-input VERSION     fail closed unless web/auth/package.json names VERSION and the checkout is clean.
inspect ...              passive checks of the final npm archive bytes; writes a receipt bound to its sha256.
verify-receipt ...       the archive about to be published is the one that was inspected.
The checker never runs package code or lifecycle scripts.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "@axiomcore/auth-web"
ALLOWED = re.compile(r"package/(package\.json|README\.md|LICENSE|dist/[A-Za-z0-9._/-]+\.(js|d\.ts))")
PRIVATE = re.compile(rb"/Users/|/Volumes/|/home/runner/|axiom-internal-docs|BEGIN [A-Z ]*PRIVATE KEY")
STABLE = re.compile(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def verify_input(version):
    if not STABLE.fullmatch(version):
        raise SystemExit("invalid stable version")
    package = json.loads((ROOT / "web/auth/package.json").read_text())
    if package["name"] != NAME or package["version"] != version:
        raise SystemExit(f"web/auth/package.json: expected {NAME}@{version}, found {package['name']}@{package['version']}")
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=True)
    if status.stdout.strip():
        raise SystemExit("release source checkout must be clean and committed")
    print(f"verified {NAME}@{version} from committed source")


def inspect(artifact, scanner, receipt):
    data = Path(artifact).read_bytes()
    members = []
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive, tempfile.TemporaryDirectory() as tmp:
        for member in archive.getmembers():
            if member.isdir() and re.fullmatch(r"package(/dist(/[A-Za-z0-9._-]+)*)?/?", member.name):
                continue
            if not member.isfile() or not ALLOWED.fullmatch(member.name) or ".." in member.name.split("/"):
                raise SystemExit(f"unexpected archive member: {member.name}")
            body = archive.extractfile(member).read()
            if PRIVATE.search(body):
                raise SystemExit(f"private path or key material in {member.name}")
            members.append({"name": member.name, "size": len(body), "sha256": sha256(body)})
            target = Path(tmp) / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(body)
        package = json.loads((Path(tmp) / "package/package.json").read_text())
        if package["name"] != NAME:
            raise SystemExit(f"archive names {package['name']}, expected {NAME}")
        if package.get("scripts", {}).keys() & {"preinstall", "install", "postinstall", "prepare"}:
            raise SystemExit("install lifecycle scripts are not allowed in the published package")
        scan = subprocess.run([scanner, "dir", tmp, "--no-banner", "--redact", "--exit-code", "3"], capture_output=True, text=True)
        if scan.returncode != 0:
            print(scan.stdout[-4000:], scan.stderr[-4000:], sep="\n", file=sys.stderr)
            raise SystemExit("credential scan rejected the archive")
    Path(receipt).write_text(json.dumps({
        "package": NAME, "version": package["version"], "artifact": Path(artifact).name,
        "sha256": sha256(data), "members": members, "scanner": "gitleaks 8.30.1",
    }, indent=1) + "\n")
    print(f"inspected {Path(artifact).name}: {len(members)} files, sha256 {sha256(data)}")


def verify_receipt(artifact, receipt):
    record = json.loads(Path(receipt).read_text())
    actual = sha256(Path(artifact).read_bytes())
    if record["package"] != NAME or record["artifact"] != Path(artifact).name or record["sha256"] != actual:
        raise SystemExit("archive does not match its inspection receipt")
    print(f"archive matches inspection receipt (sha256 {actual})")


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("verify-input").add_argument("version")
    check = commands.add_parser("inspect")
    check.add_argument("--artifact", required=True)
    check.add_argument("--scanner", required=True)
    check.add_argument("--receipt", required=True)
    bound = commands.add_parser("verify-receipt")
    bound.add_argument("--artifact", required=True)
    bound.add_argument("--receipt", required=True)
    args = parser.parse_args()
    if args.command == "verify-input":
        verify_input(args.version)
    elif args.command == "inspect":
        inspect(args.artifact, args.scanner, args.receipt)
    else:
        verify_receipt(args.artifact, args.receipt)


if __name__ == "__main__":
    main()
