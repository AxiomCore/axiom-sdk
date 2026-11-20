#!/usr/bin/env python3
"""App size with and without the Axiom SDK.

  python3 tool/bench_size.py [--out results/size.json] [--skip-apk] [--skip-web]

baseline = baseline_app/lib/main.dart (dio + http, one call each, no axiom_flutter dependency)
axiom    = app/lib/size_main.dart (the same screen plus one Axiom call; app depends on axiom_flutter)
Builds: `flutter build apk --release --split-per-abi` and `flutter build web --release`.
Web sizes: main.dart.js, every file under build/web, the Axiom wasm/js assets, and gzip -9
sizes of the largest files (what a server with gzip would transfer).
"""
import argparse, gzip, json, os, shutil, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = {"baseline": (os.path.join(ROOT, "baseline_app"), "lib/main.dart"),
        "axiom": (os.path.join(ROOT, "app"), "lib/size_main.dart")}


def sh(cmd, cwd, env=None):
    print("+", " ".join(cmd), flush=True)
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                       env={**os.environ, **(env or {})})
    if p.returncode != 0:
        sys.exit(p.stdout[-4000:])
    return p.stdout


def gz(path):
    return len(gzip.compress(open(path, "rb").read(), 9))


def apk_breakdown(path):
    """Compressed (in-APK) and raw sizes of the parts that differ between the two apps."""
    out = {"total": os.path.getsize(path)}
    groups = {"libaxiom_runtime.so": lambda n: n.endswith("/libaxiom_runtime.so"),
              "libapp.so (Dart AOT)": lambda n: n.endswith("/libapp.so"),
              "libflutter.so": lambda n: n.endswith("/libflutter.so"),
              "axiom web runtime assets (wasm+js)": lambda n: "packages/axiom_flutter/lib/assets/wasm/" in n,
              "contract asset": lambda n: n.endswith("assets/axiom/bench.axiom")}
    with zipfile.ZipFile(path) as z:
        for g, pred in groups.items():
            infos = [i for i in z.infolist() if pred(i.filename)]
            out[g] = {"in_apk": sum(i.compress_size for i in infos), "raw": sum(i.file_size for i in infos)}
    return out


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
            apks = sorted(f for f in os.listdir(outdir) if f.endswith("-release.apk"))
            res["apk"][name] = {f.replace("app-", "").replace("-release.apk", ""): os.path.getsize(os.path.join(outdir, f)) for f in apks}
            res.setdefault("apk_breakdown", {})[name] = {f.replace("app-", "").replace("-release.apk", ""): apk_breakdown(os.path.join(outdir, f)) for f in apks}
            if name == "axiom":
                # Documented opt-out (axiom_flutter/doc/wasm-size.md), enabled via AXIOM_DROP_WASM=1 in
                # app/android/app/build.gradle.kts.
                sh(["flutter", "build", "apk", "--release", "--split-per-abi", "-t", target], app, {"AXIOM_DROP_WASM": "1"})
                res["apk"]["axiom_wasm_opt_out"] = {f.replace("app-", "").replace("-release.apk", ""): os.path.getsize(os.path.join(outdir, f)) for f in apks}
                res["apk_breakdown"]["axiom_wasm_opt_out"] = {f.replace("app-", "").replace("-release.apk", ""): apk_breakdown(os.path.join(outdir, f)) for f in apks}
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
            js_files = [os.path.join(r, f) for r, _, fs in os.walk(web) for f in fs if f.endswith((".js", ".wasm", ".mjs"))]
            entry["js_wasm_bytes"] = sum(os.path.getsize(p) for p in js_files)
            entry["js_wasm_gzip"] = sum(gz(p) for p in js_files)
            entry["js_wasm_files"] = sorted(os.path.relpath(p, web) for p in js_files)
            contract = os.path.join(web, "assets", "assets", "axiom", "bench.axiom")
            if os.path.exists(contract):
                entry["contract_asset"] = os.path.getsize(contract)
            res["web"][name] = entry
    if res["apk"].get("axiom") and res["apk"].get("baseline"):
        res["apk_delta"] = {abi: res["apk"]["axiom"][abi] - res["apk"]["baseline"].get(abi, 0) for abi in res["apk"]["axiom"]}
    if res["web"].get("axiom") and res["web"].get("baseline"):
        res["web_delta"] = {k: res["web"]["axiom"][k] - res["web"]["baseline"][k]
                            for k in ("total_bytes", "main_dart_js", "main_dart_js_gzip", "js_wasm_bytes", "js_wasm_gzip")}
    if res["apk"].get("axiom_wasm_opt_out") and res["apk"].get("baseline"):
        res["apk_delta_wasm_opt_out"] = {abi: res["apk"]["axiom_wasm_opt_out"][abi] - res["apk"]["baseline"].get(abi, 0) for abi in res["apk"]["axiom_wasm_opt_out"]}
    res["flutter"] = sh(["flutter", "--version"], ROOT).split("\n")[0]
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    json.dump(res, open(a.out, "w"), indent=2)
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
