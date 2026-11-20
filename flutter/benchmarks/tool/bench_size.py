#!/usr/bin/env python3
"""App size with and without the Axiom SDK.

  python3 tool/bench_size.py [--out results/size.json] [--skip-apk] [--skip-web]

baseline = baseline_app/lib/main.dart (dio + http, one call each, no axiom_flutter dependency)
axiom    = app/lib/size_main.dart (the same screen plus one Axiom call; app depends on axiom_flutter)
Builds: `flutter build apk --release --split-per-abi` and `flutter build web --release`.
Web sizes: main.dart.js, every file under build/web, the Axiom wasm/js assets, and gzip -9
sizes of the largest files (what a server with gzip would transfer).
"""
import argparse, gzip, json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = {"baseline": (os.path.join(ROOT, "baseline_app"), "lib/main.dart"),
        "axiom": (os.path.join(ROOT, "app"), "lib/size_main.dart")}


def sh(cmd, cwd):
    print("+", " ".join(cmd), flush=True)
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if p.returncode != 0:
        sys.exit(p.stdout[-4000:])
    return p.stdout


def gz(path):
    return len(gzip.compress(open(path, "rb").read(), 9))


def dir_size(d):
    return sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(d) for f in fs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "results", "size.json"))
    ap.add_argument("--skip-apk", action="store_true")
    ap.add_argument("--skip-web", action="store_true")
    a = ap.parse_args()
    res = {"method": __doc__.strip(), "apk": {}, "web": {}}
    for name, (app, target) in APPS.items():
        if not a.skip_apk:
            sh(["flutter", "build", "apk", "--release", "--split-per-abi", "-t", target], app)
            outdir = os.path.join(app, "build", "app", "outputs", "flutter-apk")
            res["apk"][name] = {f.replace("app-", "").replace("-release.apk", ""): os.path.getsize(os.path.join(outdir, f))
                                for f in sorted(os.listdir(outdir)) if f.endswith("-release.apk")}
        if not a.skip_web:
            sh(["flutter", "build", "web", "--release", "-t", target], app)
            web = os.path.join(app, "build", "web")
            entry = {"total_bytes": dir_size(web), "main_dart_js": os.path.getsize(os.path.join(web, "main.dart.js")),
                     "main_dart_js_gzip": gz(os.path.join(web, "main.dart.js"))}
            wasm_dir = os.path.join(web, "assets", "packages", "axiom_flutter", "lib", "assets", "wasm")
            if os.path.isdir(wasm_dir):
                for f in sorted(os.listdir(wasm_dir)):
                    p = os.path.join(wasm_dir, f)
                    entry[f"axiom_asset:{f}"] = os.path.getsize(p)
                    entry[f"axiom_asset:{f}:gzip"] = gz(p)
            contract = os.path.join(web, "assets", "assets", "axiom", "bench.axiom")
            if os.path.exists(contract):
                entry["contract_asset"] = os.path.getsize(contract)
            res["web"][name] = entry
    if res["apk"].get("axiom") and res["apk"].get("baseline"):
        res["apk_delta"] = {abi: res["apk"]["axiom"][abi] - res["apk"]["baseline"].get(abi, 0) for abi in res["apk"]["axiom"]}
    if res["web"].get("axiom") and res["web"].get("baseline"):
        res["web_delta"] = {k: res["web"]["axiom"][k] - res["web"]["baseline"][k]
                            for k in ("total_bytes", "main_dart_js", "main_dart_js_gzip")}
    res["flutter"] = sh(["flutter", "--version"], ROOT).split("\n")[0]
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    json.dump(res, open(a.out, "w"), indent=2)
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
