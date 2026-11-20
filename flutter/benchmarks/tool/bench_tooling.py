#!/usr/bin/env python3
"""Client generation time: `axiom pull` end to end and the Axiom generator alone vs
`dart run build_runner build` for the retrofit/json_serializable client. 5 runs each, cold and warm.

  python3 tool/bench_tooling.py [--runs 5] [--out results/tooling.json]

cold  = tool caches removed first: the generator's compiled snapshot
        (app/.dart_tool/pub/bin/axiom_flutter_generator) for Axiom, `build_runner clean`
        (compiled build script + asset graph) for build_runner. pub's package cache stays warm.
warm  = caches present. Axiom always regenerates every file (no incremental mode). For
        build_runner a comment in api.dart and models.dart is changed before every warm run so
        it has to regenerate both .g.dart files (an unchanged warm run is a no-op and is
        reported separately as warm_noop).
Discarded caches are moved to build/trash (never deleted).
"""
import argparse, json, os, platform, shutil, statistics, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "app")
DIO = os.path.join(ROOT, "api", "dio_client")
CONTRACT = os.path.join(ROOT, "api", "acore", ".out", "bench.axiom")
TRASH = os.path.join(ROOT, "build", "trash")
AXIOM = os.environ.get("AXIOM", "axiom")


def run(cmd, cwd):
    t = time.perf_counter()
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    dt = time.perf_counter() - t
    if p.returncode != 0:
        sys.exit(f"failed: {' '.join(cmd)}\n{p.stdout[-3000:]}")
    return dt


def discard(path):
    if os.path.exists(path):
        os.makedirs(TRASH, exist_ok=True)
        shutil.move(path, os.path.join(TRASH, f"{os.path.basename(path)}.{time.time_ns()}"))


def restore_deps():
    # `axiom pull` rewrites AxiomDeps.toml with an absolute contract path; keep the repo copy.
    subprocess.run(["git", "checkout", "--", "AxiomDeps.toml"], cwd=APP, check=False)


def touch_comment(path, i):
    lines = open(path).read().split("\n")
    lines = [l for l in lines if not l.startswith("// bench-touch")]
    lines.insert(0, f"// bench-touch {i}")
    open(path, "w").write("\n".join(lines))


def untouch(path):
    lines = open(path).read().split("\n")
    open(path, "w").write("\n".join(l for l in lines if not l.startswith("// bench-touch")))


def summary(xs):
    return {"runs_s": [round(x, 3) for x in xs], "median_s": round(statistics.median(xs), 3),
            "min_s": round(min(xs), 3), "max_s": round(max(xs), 3)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--out", default=os.path.join(ROOT, "results", "tooling.json"))
    a = ap.parse_args()
    snap = os.path.join(APP, ".dart_tool", "pub", "bin", "axiom_flutter_generator")
    pull = [AXIOM, "pull", CONTRACT, "--framework", "flutter", "--name", "bench", "--out", "lib/axiom_generated"]
    gen = ["dart", "run", "axiom_flutter_generator:generate", "--config", "AxiomDeps.toml",
           "--out", "axiom_generated", "--project-root", APP]
    br = ["dart", "run", "build_runner", "build", "--delete-conflicting-outputs"]
    res = {}
    try:
        for name, cmd in (("axiom_pull", pull), ("axiom_generator", gen)):
            cold, warm = [], []
            for _ in range(a.runs):
                discard(snap)
                cold.append(run(cmd, APP)); restore_deps()
            for _ in range(a.runs):
                warm.append(run(cmd, APP)); restore_deps()
            res[name] = {"cold": summary(cold), "warm": summary(warm)}
            print(name, res[name], flush=True)
        api, models = os.path.join(DIO, "lib/src/api.dart"), os.path.join(DIO, "lib/src/models.dart")
        cold, warm, noop = [], [], []
        for _ in range(a.runs):
            run(["dart", "run", "build_runner", "clean"], DIO)
            cold.append(run(br, DIO))
        for i in range(a.runs):
            touch_comment(api, i); touch_comment(models, i)
            warm.append(run(br, DIO))
        untouch(api); untouch(models)
        run(br, DIO)
        for _ in range(a.runs):
            noop.append(run(br, DIO))
        res["build_runner"] = {"cold": summary(cold), "warm": summary(warm), "warm_noop": summary(noop)}
        print("build_runner", res["build_runner"], flush=True)
    finally:
        restore_deps()
    ver = lambda c: subprocess.run(c, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout.strip().split("\n")[0]
    out = {
        "machine": {"cpu_count": os.cpu_count(), "os": platform.platform(), "python": platform.python_version()},
        "tools": {"axiom": ver([AXIOM, "--version"]), "dart": ver(["dart", "--version"]),
                  "flutter": ver(["flutter", "--version"])},
        "method": __doc__.strip(),
        "results": res,
    }
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    json.dump(out, open(a.out, "w"), indent=2)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
