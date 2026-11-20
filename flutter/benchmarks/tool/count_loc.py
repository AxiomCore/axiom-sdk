#!/usr/bin/env python3
"""Lines of code per client approach. Counts non-blank lines that are not only a comment
(`//`, `///`, `#`). Prints JSON; `--out FILE` writes it.

Hand-written files per approach are listed in FILES below; generated files are counted
separately and never added to the hand-written total. For Acore the contract also carries the
server implementation (`managed { ... }` bodies); those lines are reported separately
(`acore_managed_bodies`) so a reader can compare declarations only. The contract also declares a
WebSocket endpoint the other clients do not have: `hand_written_unary_only` subtracts it.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FILES = {
    "axiom": {
        "hand_written": ["api/acore/main.acore", "app/AxiomDeps.toml", "app/lib/bench_axiom_setup.dart"],
        "generated": ["app/lib/axiom_generated/axiom_sdk.dart", "app/lib/axiom_generated/models.dart"],
    },
    "dio_retrofit": {
        "hand_written": ["api/dio_client/lib/src/api.dart", "api/dio_client/lib/src/models.dart",
                         "api/dio_client/lib/bench_dio_client.dart"],
        "generated": ["api/dio_client/lib/src/api.g.dart", "api/dio_client/lib/src/models.g.dart"],
    },
    "http_manual": {
        "hand_written": ["api/http_client/lib/bench_http_client.dart"],
        "generated": [],
    },
}


def code_lines(path):
    n = 0
    for line in open(os.path.join(ROOT, path), encoding="utf-8"):
        s = line.strip()
        if not s or s.startswith("//") or s.startswith("#"):
            continue
        n += 1
    return n


def managed_lines(path):
    text = open(os.path.join(ROOT, path), encoding="utf-8").read()
    n = 0
    for m in re.finditer(r"managed\s*\{", text):
        depth, i = 1, m.end()
        while depth and i < len(text):
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        body = text[m.start():i]
        n += len([l for l in body.split("\n") if l.strip()])
    return n


def ws_lines(path):
    """Contract lines that exist only for the WebSocket endpoint (the dio and http clients
    have no WebSocket code): the guard line and everything after the WebSocket marker."""
    n, after = 0, False
    for line in open(os.path.join(ROOT, path), encoding="utf-8"):
        s = line.strip()
        if s.startswith("// ---- WebSocket"):
            after = True
        if not s or s.startswith("//"):
            continue
        if after or s.startswith("guard signedIn"):
            n += 1
    return n


def main():
    out = {"method": __doc__.strip(), "approaches": {}}
    for name, groups in FILES.items():
        entry = {}
        for g, files in groups.items():
            per = {f: code_lines(f) for f in files}
            entry[g] = {"files": per, "total": sum(per.values())}
        out["approaches"][name] = entry
    out["approaches"]["axiom"]["acore_managed_bodies"] = managed_lines("api/acore/main.acore")
    out["approaches"]["axiom"]["acore_websocket_lines"] = ws_lines("api/acore/main.acore")
    a = out["approaches"]["axiom"]
    a["hand_written_unary_only"] = a["hand_written"]["total"] - a["acore_websocket_lines"]
    s = json.dumps(out, indent=2)
    if len(sys.argv) > 2 and sys.argv[1] == "--out":
        open(sys.argv[2], "w").write(s + "\n")
    print(s)


if __name__ == "__main__":
    main()
