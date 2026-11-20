#!/usr/bin/env python3
"""Merge raw benchmark outputs into one dated results file.

  python3 tool/collect_results.py --label linux-chrome \
      --web results/raw-web.jsonl --tooling results/tooling.json \
      --loc results/loc.json --size results/size.json
Writes results/<YYYY-MM-DD>-<label>.json. Every input is optional.
"""
import argparse, datetime, json, os, platform, statistics, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def cmd(c):
    try:
        return subprocess.run(c, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, shell=isinstance(c, str)).stdout.strip()
    except OSError:
        return ""


def machine():
    cpu = ""  # gVisor does not report the model name
    try:
        for l in open("/proc/cpuinfo"):
            if l.startswith("model name"):
                cpu = l.split(":", 1)[1].strip()
                cpu = "" if cpu.lower() == "unknown" else cpu
                break
        mem = next(l for l in open("/proc/meminfo") if l.startswith("MemTotal")).split()[1]
        mem_gb = round(int(mem) / 1024 / 1024, 1)
    except (OSError, StopIteration):
        mem_gb = None
    osname = platform.platform()
    if os.path.exists("/etc/os-release"):
        d = dict(l.rstrip().split("=", 1) for l in open("/etc/os-release") if "=" in l)
        osname = d.get("PRETTY_NAME", osname).strip('"') + f" (kernel {platform.release()})"
    chrome = cmd("google-chrome --version || chrome --version || chromium --version")
    return {"cpu": cpu or "", "cores": os.cpu_count(), "ram_gb": mem_gb, "os": osname,
            "chrome": chrome.split("\n")[0], "virtualised": "gVisor sandbox / container (shared host)"
            if "gvisor" in platform.release().lower() else ""}


# Scenarios added by unit bench2 (app/lib/bench_extra.dart).
EXTRA_BENCHES = ("parallel", "offline", "jank", "ttfi", "clients")


def _sfx(x):
    """Metric-key suffix for non-default protocols (h1 keys stay as before for history)."""
    p = x.get("proto") or "h1"
    return "" if p == "h1" else f" [{p}]"


def web_summary(path):
    recs = [json.loads(l) for l in open(path) if l.strip()]
    out = {"cold": {}, "latency": [], "cache": [], "decode": [], "ws": [], "errors": []}
    for b in EXTRA_BENCHES:
        out[b] = []
    cold = {}
    for r in recs:
        b = r.get("bench")
        if b == "cold":
            cold.setdefault(r["client"], []).append(r)
        elif b in ("latency", "cache", "decode", "ws") + EXTRA_BENCHES and r.get("status") != "error":
            out[b].append({k: v for k, v in r.items() if k not in ("run", "platform", "bench")})
        elif r.get("status") == "error":
            out["errors"].append(r)
    for client, rs in cold.items():
        v = [r["first_data_ms"] for r in rs if r.get("status") == "ok"]
        out["cold"][client] = {"runs": len(v), "first_data_ms": v,
                               "median_ms": round(statistics.median(v), 1) if v else None,
                               "init_median_ms": round(statistics.median(r["init_ms"] for r in rs), 1),
                               "method": rs[0].get("method")}
    modes = {r.get("mode") for r in recs if r.get("mode")}
    out["mode"] = ",".join(sorted(modes))
    return out


def _p50s(w):
    d = {f"cold {c}": v["median_ms"] for c, v in w["cold"].items()}
    for x in w["latency"]:
        d[f"latency {x['case']} {x['client']}"] = x.get("p50_ms")
    for x in w["cache"]:
        d[f"cache {x['case']} {x['client']}"] = x.get("p50_ms")
    for x in w["decode"]:
        d[f"decode {x['items']} {x['decoder']}"] = x.get("p50_ms")
    return d


def compare(a, b):
    """p50 (cold: median) of run 1 vs run 2 and the relative difference."""
    pa, pb = _p50s(a), _p50s(b)
    rows = []
    for k, x in pa.items():
        y = pb.get(k)
        if x and y is not None:
            rows.append({"metric": k, "run1_ms": x, "run2_ms": y, "diff_pct": round((y - x) / x * 100)})
    within = sum(1 for r in rows if abs(r["diff_pct"]) <= 10)
    return {"rows": rows, "within_10pct": within, "total": len(rows)}


def _metrics(w):
    """Every per-run figure that is compared across runs: (key, value, unit, lower_is_better)."""
    d = {}
    for c, v in w["cold"].items():
        d[f"cold first_data {c}"] = (v["median_ms"], "ms")
        d[f"cold init {c}"] = (v["init_median_ms"], "ms")
    for x in w["latency"]:
        d[f"latency {x['case']} {x['client']} p50{_sfx(x)}"] = (x.get("p50_ms"), "ms")
        d[f"latency {x['case']} {x['client']} p95{_sfx(x)}"] = (x.get("p95_ms"), "ms")
    for x in w.get("clients", []):
        d[f"clients {x['case']} {x['client']} p50{_sfx(x)}"] = (x.get("p50_ms"), "ms")
    for x in w.get("parallel", []):
        d[f"parallel {x['case']} {x['client']} p50{_sfx(x)}"] = (x.get("p50_ms"), "ms")
    for x in w.get("offline", []):
        if x.get("status") == "ok":
            d[f"offline {x['case']} {x['client']} p50{_sfx(x)}"] = (x.get("p50_ms"), "ms")
    for x in w.get("jank", []):
        d[f"jank {x['case']} {x['client']} longest_gap_p50{_sfx(x)}"] = (x.get("p50_ms"), "ms")
    for x in w.get("ttfi", []):
        if x.get("status") == "ok":
            d[f"ttfi {x['case']} {x['client']} p50{_sfx(x)}"] = (x.get("p50_ms"), "ms")
    for x in w["cache"]:
        d[f"cache {x['case']} {x['client']} p50"] = (x.get("p50_ms"), "ms")
        d[f"cache {x['case']} {x['client']} p95"] = (x.get("p95_ms"), "ms")
    for x in w["decode"]:
        d[f"decode {x['items']} {x['decoder']} p50"] = (x.get("p50_ms"), "ms")
    for x in w["ws"]:
        if x.get("status") == "ok":
            d[f"ws echo {x['client']} round_trips_per_s"] = (x.get("round_trips_per_s"), "/s")
    return d


def web_stats(runs, max_spread):
    """Median of the run medians and spread = (max - min) / median per metric."""
    per = [_metrics(w) for w in runs]
    out = {}
    keys = list(dict.fromkeys(k for m in per for k in m))
    for k in keys:
        unit = next(m[k][1] for m in per if k in m)
        vals = [m[k][0] for m in per if k in m and m[k][0] is not None]
        if len(vals) != len(runs):
            out[k] = {"runs": vals, "unit": unit, "stable": False, "note": "missing in a run"}
            continue
        med = statistics.median(vals)
        spread = (max(vals) - min(vals)) / med if med else None
        out[k] = {"runs": vals, "median": round(med, 3), "unit": unit,
                  "spread_pct": None if spread is None else round(spread * 100, 1),
                  "stable": spread is not None and spread <= max_spread}
    n = sum(1 for v in out.values() if v["stable"])
    return {"rule": f"median of {len(runs)} run medians; publishable if (max-min)/median <= {max_spread:.0%}",
            "stable_count": n, "total": len(out), "metrics": out}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", default="linux-chrome")
    for k in ("web", "web_repeat", "tooling", "loc", "size"):
        ap.add_argument(f"--{k.replace('_', '-')}")
    ap.add_argument("--web-runs", nargs="+", help="several full web runs (JSONL); adds web_runs + web_stats")
    ap.add_argument("--max-spread", type=float, default=0.10)
    ap.add_argument("--extra", help="JSON file merged into the top level (machine details, commits)")
    ap.add_argument("--out", help="output path (default results/<date>-<label>.json)")
    ap.add_argument("--note", action="append", default=[], help="extra note line (repeatable)")
    a = ap.parse_args()
    date = datetime.date.today().isoformat()
    res = {
        "date": date,
        "label": a.label,
        "machine": machine(),
        "flutter": cmd(["flutter", "--version"]).split("\n")[0],
        "dart": cmd(["dart", "--version"]),
        "axiom_cli": cmd([os.environ.get("AXIOM", "axiom"), "--version"]),
        "sdk_commit": cmd(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"]),
        "notes": [
            "Web numbers: headless Chrome on a 4 vCPU Linux container (no GPU), release build "
            "(dart2js), server on 127.0.0.1. Not a physical device.",
            "All three clients call the same local Dart server (api/server); see README for method.",
        ],
    }
    res["notes"] += a.note
    if a.web:
        res["web"] = web_summary(a.web)
    if a.web_repeat:
        res["web_repeat"] = web_summary(a.web_repeat)
        res["reproducibility"] = compare(res["web"], res["web_repeat"])
    if a.web_runs:
        runs = [web_summary(p) for p in a.web_runs]
        res["web_runs"] = [{"file": os.path.relpath(p, ROOT), **w} for p, w in zip(a.web_runs, runs)]
        res["web_stats"] = web_stats(runs, a.max_spread)
    if a.extra:
        ex = json.load(open(a.extra))
        res["machine"].update(ex.pop("machine", {}))
        res.update(ex)
    for k in ("tooling", "loc", "size"):
        p = getattr(a, k)
        if p:
            res[k] = json.load(open(p))
    out = a.out or os.path.join(ROOT, "results", f"{date}-{a.label}.json")
    json.dump(res, open(out, "w"), indent=2)
    print("wrote", out)


if __name__ == "__main__":
    main()
