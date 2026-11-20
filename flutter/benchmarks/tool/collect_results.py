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


def web_summary(path):
    recs = [json.loads(l) for l in open(path) if l.strip()]
    out = {"cold": {}, "latency": [], "cache": [], "decode": [], "ws": [], "errors": []}
    cold = {}
    for r in recs:
        b = r.get("bench")
        if b == "cold":
            cold.setdefault(r["client"], []).append(r)
        elif b in ("latency", "cache", "decode", "ws"):
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", default="linux-chrome")
    for k in ("web", "web_repeat", "tooling", "loc", "size"):
        ap.add_argument(f"--{k.replace('_', '-')}")
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
    for k in ("tooling", "loc", "size"):
        p = getattr(a, k)
        if p:
            res[k] = json.load(open(p))
    out = os.path.join(ROOT, "results", f"{date}-{a.label}.json")
    json.dump(res, open(out, "w"), indent=2)
    print("wrote", out)


if __name__ == "__main__":
    main()
