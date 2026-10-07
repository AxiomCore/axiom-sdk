#!/usr/bin/env python3
"""Reject internal/generated files anywhere in reachable public Git history."""
from pathlib import PurePosixPath
import subprocess
import sys

INTERNAL_DOCUMENTS = frozenset()

def prohibited(path):
    return ('.summary_files' in PurePosixPath(path).parts
            or path.startswith('release/control/') or path in INTERNAL_DOCUMENTS)

def main():
    try:
        output = subprocess.check_output([
            'git', 'log', '--all', '--format=', '--name-only', '--no-renames'
        ], stderr=subprocess.PIPE).decode('utf-8')
    except (subprocess.CalledProcessError, UnicodeError):
        print('Public source check could not inspect complete Git history.', file=sys.stderr)
        return 2
    findings = {p for p in output.splitlines() if prohibited(p)}
    if findings:
        print(f'Public source check rejected {len(findings)} internal/generated paths. '
              'Use a fresh sanitized clone and contact the repository maintainer.', file=sys.stderr)
        return 1
    print('Reachable public Git history passes the file-boundary policy.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
