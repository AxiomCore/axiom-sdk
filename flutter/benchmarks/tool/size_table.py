#!/usr/bin/env python3
"""Size table: baseline app vs Axiom lean (default) vs Axiom + extensions add-on.

  python3 tool/size_table.py [--out results/size-table.json] [--skip-apk] [--skip-web]
      [--variants baseline,axiom,axiom_extensions]
      [--runtime NAME=DIR ...]   extra Axiom variants with replaced runtime binaries, e.g.
                                 --runtime axiom_full=/home/node/fp/artifacts/perf/default
                                 DIR/android-<abi>/libaxiom_runtime.so (or DIR/<abi>/...) and
                                 DIR/wasm/{axiom_runtime_bg.wasm,axiom_runtime.js} replace the
                                 binaries in a scratch copy of axiom_flutter (the repo is untouched)

Every variant is a scratch copy of baseline_app/ (dio + http, one call each) under
build/size_variants/<name>/:
  baseline          as is (no axiom_flutter dependency)
  axiom             + axiom_flutter (path dependency on this repo: whatever runtime it bundles;
                    the sha256 of the bundled binaries is recorded) + app/lib/size_main.dart as
                    main.dart + the generated client + the contract asset
  axiom_extensions  axiom + the add-on package flutter/axiom_flutter_extensions (skipped with
                    status not_available when the package is not on this branch)
Builds `flutter build apk --release --split-per-abi` and `flutter build web --release`.
Per ABI: APK bytes, libaxiom_runtime.so in-APK (compressed, what the APK stores) and raw
(installed, extracted on device) bytes, and gzip -9 of the raw .so (download estimate; Play
delivers compressed splits, bundletool was not used). Web: raw, gzip -9 and brotli (q11, via
node's zlib) bytes of all .js/.wasm/.mjs files, and of the Axiom runtime assets.
"""
import argparse, gzip, hashlib, json, os, shutil, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLUTTER_DIR = os.path.dirname(ROOT)
SCRATCH = os.path.join(ROOT, "build", "size_variants")
TRASH = os.environ.get("SIZE_TRASH", os.path.join(ROOT, "build", "size_trash"))
ABIS = ["arm64-v8a", "armeabi-v7a", "x86_64"]


def sh(cmd, cwd, env=None, check=True):
    print("+", " ".join(cmd), f"(in {os.path.relpath(cwd, ROOT)})", flush=True)
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                       env={**os.environ, **(env or {})})
    if check and p.returncode != 0:
        sys.exit(p.stdout[-4000:])
    return p.stdout


def gz(b):
    return len(gzip.compress(b, 9))


def br_many(paths):
    """brotli q11 sizes via node (no python brotli module on the bench boxes)."""
    if not paths:
        return {}
    js = ("const z=require('zlib'),fs=require('fs');const o={};for(const p of process.argv.slice(1)){"
          "o[p]=z.brotliCompressSync(fs.readFileSync(p),{params:{[z.constants.BROTLI_PARAM_QUALITY]:11}}).length}"
          "console.log(JSON.stringify(o))")
    p = subprocess.run(["node", "-e", js, *paths], stdout=subprocess.PIPE, text=True)
    return json.loads(p.stdout) if p.returncode == 0 else {}


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def move_away(path):
    """No rm on these boxes: move an old scratch dir aside."""
    if os.path.exists(path):
        os.makedirs(TRASH, exist_ok=True)
        dst = os.path.join(TRASH, f"{os.path.basename(path)}.{os.getpid()}.{len(os.listdir(TRASH))}")
        shutil.move(path, dst)


def copy_tree(src, dst):
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("build", ".dart_tool", ".gradle", "*.iml",
                                                          ".flutter-plugins*", "local.properties"))


def scratch_axiom_flutter(name, rdir):
    """Copy of axiom_flutter with runtime binaries from rdir."""
    dst = os.path.join(SCRATCH, f"_axiom_flutter_{name}")
    move_away(dst)
    copy_tree(os.path.join(FLUTTER_DIR, "axiom_flutter"), dst)
    for abi in ABIS:
        for cand in (os.path.join(rdir, f"android-{abi}", "libaxiom_runtime.so"),
                     os.path.join(rdir, abi, "libaxiom_runtime.so")):
            if os.path.exists(cand):
                shutil.copy(cand, os.path.join(dst, "android", "src", "main", "jniLibs", abi, "libaxiom_runtime.so"))
                break
        else:
            print(f"warning: {rdir} has no {abi} runtime; keeping the bundled one", flush=True)
    for f in ("axiom_runtime_bg.wasm", "axiom_runtime.js"):
        if os.path.exists(os.path.join(rdir, "wasm", f)):
            shutil.copy(os.path.join(rdir, "wasm", f), os.path.join(dst, "lib", "assets", "wasm", f))
    return dst


def make_variant(name, axiom_pkg=None, extensions=False):
    dst = os.path.join(SCRATCH, name)
    move_away(dst)
    copy_tree(os.path.join(ROOT, "baseline_app"), dst)
    pub = os.path.join(dst, "pubspec.yaml")
    text = open(pub).read()
    for rel in ("../api/dio_client", "../api/http_client"):
        text = text.replace(f"path: {rel}", f"path: {os.path.join(ROOT, rel[3:])}")
    if axiom_pkg:
        app = os.path.join(ROOT, "app")
        deps = f"  axiom_flutter:\n    path: {axiom_pkg}\n"
        if extensions:
            deps += f"  axiom_flutter_extensions:\n    path: {os.path.join(FLUTTER_DIR, 'axiom_flutter_extensions')}\n"
        text = text.replace("dependencies:\n  flutter:\n    sdk: flutter\n", "dependencies:\n  flutter:\n    sdk: flutter\n" + deps, 1)
        text += f"\ndependency_overrides:\n  axiom_flutter:\n    path: {axiom_pkg}\n"
        text = text.replace("  uses-material-design: true", "  uses-material-design: true\n  assets:\n    - assets/axiom/bench.axiom")
        shutil.copytree(os.path.join(app, "lib", "axiom_generated"), os.path.join(dst, "lib", "axiom_generated"))
        os.makedirs(os.path.join(dst, "assets", "axiom"), exist_ok=True)
        shutil.copy(os.path.join(app, "assets", "axiom", "bench.axiom"), os.path.join(dst, "assets", "axiom", "bench.axiom"))
        main = open(os.path.join(app, "lib", "size_main.dart")).read()
        if extensions:
            # Import only: the add-on's native runtime is bundled by plugin registration either way.
            main = main.replace("import 'package:axiom_flutter/axiom_flutter.dart';",
                                "import 'package:axiom_flutter/axiom_flutter.dart';\n"
                                "// ignore: unused_import\n"
                                "import 'package:axiom_flutter_extensions/axiom_flutter_extensions.dart';")
        open(os.path.join(dst, "lib", "main.dart"), "w").write(main)
    open(pub, "w").write(text)
    return dst


def apk_rows(outdir):
    rows = {}
    for abi in ABIS:
        apk = os.path.join(outdir, f"app-{abi}-release.apk")
        if not os.path.exists(apk):
            continue
        row = {"apk": os.path.getsize(apk)}
        with zipfile.ZipFile(apk) as z:
            for i in z.infolist():
                base = os.path.basename(i.filename)
                key = {"libaxiom_runtime.so": "axiom_so", "libaxiom_runtime_full.so": "axiom_full_so",
                       "libapp.so": "libapp_so", "libflutter.so": "libflutter_so"}.get(base)
                if key and i.filename.startswith("lib/"):
                    row[f"{key}_in_apk"] = i.compress_size
                    row[f"{key}_raw"] = i.file_size
                    if key in ("axiom_so", "axiom_full_so"):
                        row[f"{key}_gzip9"] = gz(z.read(i))
                        # Both Axiom runtimes together (the extensions add-on ships the full one).
                        row["runtime_raw"] = row.get("runtime_raw", 0) + i.file_size
                        row["runtime_gzip9"] = row.get("runtime_gzip9", 0) + row[f"{key}_gzip9"]
                if "packages/axiom_flutter/lib/assets/wasm/" in i.filename:
                    row["axiom_web_assets_in_apk"] = row.get("axiom_web_assets_in_apk", 0) + i.compress_size
        rows[abi] = row
    return rows


def web_row(web):
    files = [os.path.join(r, f) for r, _, fs in os.walk(web) for f in fs if f.endswith((".js", ".wasm", ".mjs"))]
    brs = br_many(files)
    row = {"js_wasm_raw": 0, "js_wasm_gzip": 0, "js_wasm_brotli": 0, "files": {}}
    for p in files:
        b = open(p, "rb").read()
        rel = os.path.relpath(p, web)
        g, r = gz(b), brs.get(p)
        row["files"][rel] = {"raw": len(b), "gzip": g, "brotli": r}
        row["js_wasm_raw"] += len(b)
        row["js_wasm_gzip"] += g
        row["js_wasm_brotli"] += r or 0
    # What one page load fetches: main.dart.js + flutter js + one CanvasKit variant + Axiom assets.
    ax = {k: v for k, v in row["files"].items() if "packages/axiom_flutter/lib/assets/wasm/" in k}
    row["axiom_assets"] = {m: sum(v[m] or 0 for v in ax.values()) for m in ("raw", "gzip", "brotli")}
    row["main_dart_js"] = row["files"].get("main.dart.js")
    return row


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(ROOT, "results", "size-table.json"))
    ap.add_argument("--skip-apk", action="store_true")
    ap.add_argument("--skip-web", action="store_true")
    ap.add_argument("--variants", default="baseline,axiom,axiom_extensions")
    ap.add_argument("--runtime", action="append", default=[], help="NAME=DIR")
    a = ap.parse_args()
    os.makedirs(SCRATCH, exist_ok=True)
    plan = []
    for v in a.variants.split(","):
        v = v.strip()
        if v == "baseline":
            plan.append((v, None, False))
        elif v == "axiom":
            plan.append((v, os.path.join(FLUTTER_DIR, "axiom_flutter"), False))
        elif v == "axiom_extensions":
            plan.append((v, os.path.join(FLUTTER_DIR, "axiom_flutter"), True))
    for spec in a.runtime:
        name, rdir = spec.split("=", 1)
        plan.append((name, ("runtime", rdir), False))
    res = {"method": __doc__.strip(), "variants": {}}
    for name, pkg, ext in plan:
        entry = {}
        if ext and not os.path.isdir(os.path.join(FLUTTER_DIR, "axiom_flutter_extensions")):
            res["variants"][name] = {"status": "not_available",
                                     "note": "flutter/axiom_flutter_extensions is not on this branch"}
            continue
        if isinstance(pkg, tuple):
            pkg = scratch_axiom_flutter(name, pkg[1])
            entry["runtime_dir"] = [s.split("=", 1)[1] for s in a.runtime if s.startswith(name + "=")][0]
        app = make_variant(name, pkg, ext)
        if pkg:
            entry["bundled_runtime_sha256"] = {
                abi: sha(os.path.join(pkg, "android", "src", "main", "jniLibs", abi, "libaxiom_runtime.so"))
                for abi in ABIS if os.path.exists(os.path.join(pkg, "android", "src", "main", "jniLibs", abi, "libaxiom_runtime.so"))}
            w = os.path.join(pkg, "lib", "assets", "wasm", "axiom_runtime_bg.wasm")
            if os.path.exists(w):
                entry["bundled_runtime_sha256"]["wasm"] = sha(w)
        sh(["flutter", "pub", "get"], app)
        if not a.skip_apk:
            sh(["flutter", "build", "apk", "--release", "--split-per-abi"], app)
            entry["apk"] = apk_rows(os.path.join(app, "build", "app", "outputs", "flutter-apk"))
        if not a.skip_web:
            sh(["flutter", "build", "web", "--release"], app)
            entry["web"] = web_row(os.path.join(app, "build", "web"))
        entry["status"] = "ok"
        res["variants"][name] = entry
    base = res["variants"].get("baseline", {})
    for name, v in res["variants"].items():
        if name == "baseline" or v.get("status") != "ok":
            continue
        if base.get("apk") and v.get("apk"):
            v["apk_delta_vs_baseline"] = {abi: v["apk"][abi]["apk"] - base["apk"][abi]["apk"]
                                          for abi in v["apk"] if abi in base["apk"]}
        if base.get("web") and v.get("web"):
            v["web_delta_vs_baseline"] = {m: v["web"][m] - base["web"][m]
                                          for m in ("js_wasm_raw", "js_wasm_gzip", "js_wasm_brotli")}
    res["flutter"] = sh(["flutter", "--version"], ROOT).split("\n")[0]
    res["sdk_commit"] = sh(["git", "rev-parse", "--short", "HEAD"], ROOT).strip()
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    json.dump(res, open(a.out, "w"), indent=2)
    print(json.dumps({k: {kk: vv for kk, vv in v.items() if kk not in ("web",)} for k, v in res["variants"].items()}, indent=1))


if __name__ == "__main__":
    main()
