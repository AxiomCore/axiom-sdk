#!/usr/bin/env python3
"""Render a results JSON (results/<date>-<label>.json) as markdown for the repo README.

  python3 tool/render_readme.py results/2026-11-20-linux-chrome.json [more.json ...]
  python3 tool/render_readme.py results/X.json --insert ../../README.md

With --insert the output replaces the text between <!-- BENCHMARKS:START --> and
<!-- BENCHMARKS:END --> in that file; otherwise it is printed.
"""
import json, sys

START, END = "<!-- BENCHMARKS:START -->", "<!-- BENCHMARKS:END -->"


def f(v, unit="", nd=1):
    if v is None:
        return "–"
    if isinstance(v, (int, float)):
        return f"{v:.{nd}f}{unit}"
    return str(v)


def kb(n):
    return "–" if n is None else f"{n / 1024:,.0f} KB"


def mb(n):
    return "–" if n is None else f"{n / 1024 / 1024:.2f} MB"


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "| " + " | ".join("---" for _ in head) + " |"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


LABELS = {"axiom": "Axiom", "dio": "dio + retrofit", "http": "package:http", "web_socket_channel": "web_socket_channel",
          "dio_cache_interceptor": "dio + dio_cache_interceptor", "axiom_generated": "Axiom generated models",
          "json_serializable": "json_serializable", "manual_fromJson": "manual fromJson", "json_only": "jsonDecode only"}
CASES = {"small_get_item": "getItem (~110 B)", "small_create_item": "createItem (POST)",
         "large_list_1000": "listItems 1 000 items (91 KB)", "large_list_10000": "listItems 10 000 items (938 KB)",
         "repeat_list_1000": "cache hit, 1 000 items, repeat call"}


def describe(key):
    p = key.split()
    if p[0] == "cold":
        return (f"Cold start, {'time to first data' if p[1] == 'first_data' else 'runtime/client init'} (median of 5 launches)",
                LABELS.get(p[2], p[2]))
    if p[0] in ("latency", "cache"):
        return f"{CASES.get(p[1], p[1])}, {p[3]}", LABELS.get(p[2], p[2])
    if p[0] == "decode":
        return f"Decode only, {int(p[1]):,} items, p50 (main isolate, no network)", LABELS.get(p[2], p[2])
    if p[0] == "ws":
        return "WebSocket echo, 1 000 sequential round trips", LABELS.get(p[2], p[2])
    return key, ""


def web_stats_md(r, ws):
    nruns = len(r.get("web_runs", [])) or 3
    md = [f"#### App benchmarks: web, headless Chrome, release build, {nruns} full runs (not a physical device)", "",
          f"Each value is the median of the {nruns} run medians; spread = (max - min) / median of the run medians. "
          f"Only metrics with spread <= 10% are listed ({ws['stable_count']} of {ws['total']}). "
          "Time: lower is better; round trips/s: higher is better.", ""]
    rows = []
    for k, v in ws["metrics"].items():
        if not v["stable"]:
            continue
        what, client = describe(k)
        unit = v["unit"]
        val = f"{v['median']:,.0f}/s" if unit == "/s" else (f"{v['median']:.0f} ms" if v["median"] >= 100 else f"{v['median']:.2f} ms")
        rows.append([what, client, val, f"{v['spread_pct']:.1f}%", " / ".join(f"{x:g}" for x in v["runs"])])
    md += [table(["Measurement", "Client", "Median", "Spread", "Run medians"], rows), ""]
    ns = [(k, v) for k, v in ws["metrics"].items() if not v["stable"]]
    if ns:
        md += ["Not stable (spread above 10%, not published as a number): " + "; ".join(
            f"{' '.join(describe(k))} ({v['spread_pct']:.0f}%)" if v.get("spread_pct") is not None else f"{' '.join(describe(k))} (n/a)"
            for k, v in ns) + ".", ""]
    return md


def render(r):
    m = r.get("machine", {})
    md = [f"### {r.get('label')} ({r.get('date')})", "",
          f"Machine: {m.get('cpu') or 'CPU model not reported (gVisor)'}, {m.get('cores')} vCPU, {m.get('ram_gb')} GB RAM, {m.get('os')}"
          + (f", {m['virtualised']}" if m.get("virtualised") else "") + ". "
          f"{r.get('flutter')}. Axiom CLI {r.get('axiom_cli')}. SDK commit `{r.get('sdk_commit')}`."
          + (f" Browser: {m.get('chrome')}." if m.get("chrome") else ""), ""]
    for n in r.get("notes", []):
        md.append(f"- {n}")
    md.append("")
    ws = r.get("web_stats")
    if ws:
        md += web_stats_md(r, ws)
    w = None if ws else r.get("web")
    if w:
        md += [f"#### App benchmarks: web, headless Chrome, {w.get('mode')} build (not a physical device)", ""]
        if w.get("cold"):
            rows = [[c, v["runs"], f(v["median_ms"], " ms"), f(v["init_median_ms"], " ms")] for c, v in w["cold"].items()]
            md += ["Cold start to first data (fresh browser profile per run; timer starts in the first frame, "
                   "covers client/runtime init, contract load and one `listItems(n:1)`):", "",
                   table(["Client", "Runs", "Median first data", "Median init"], rows), ""]
        if w.get("latency"):
            rows = [[x["case"], x["client"], x.get("samples"), f(x.get("p50_ms"), " ms", 2), f(x.get("p95_ms"), " ms", 2)]
                    for x in w["latency"]]
            md += ["Per-call latency (sequential calls after 20 warm-up calls):", "",
                   table(["Case", "Client", "Calls", "p50", "p95"], rows), ""]
        if w.get("cache"):
            rows = [[x["client"], x["case"], x.get("status"), f(x.get("first_call_ms"), " ms", 2),
                     f(x.get("p50_ms"), " ms", 2), f(x.get("p95_ms"), " ms", 2)] for x in w["cache"]]
            md += ["Cache hit, time to first data on a repeat call (1 000 items):", "",
                   table(["Client", "Case", "Status", "First call", "Repeat p50", "Repeat p95"], rows), ""]
        if w.get("decode"):
            rows = [[x["items"], kb(x["bytes"]), x["decoder"], f(x.get("p50_ms"), " ms", 2), f(x.get("p95_ms"), " ms", 2)]
                    for x in w["decode"]]
            md += ["Decode, bytes to typed models on the main isolate (no network; Axiom runtime-side validation "
                   "not included):", "", table(["Items", "Body", "Decoder", "p50", "p95"], rows), ""]
        if w.get("ws"):
            rows = [[x["client"], x.get("status"), f(x.get("round_trips_per_s"), "/s", 0), f(x.get("mean_rtt_ms"), " ms", 3),
                     x.get("note", "")] for x in w["ws"]]
            md += ["WebSocket echo, sequential round trips (1 000 messages):", "",
                   table(["Client", "Status", "Round trips", "Mean RTT", "Note"], rows), ""]
    rep = None if ws else r.get("reproducibility")
    if rep:
        rows = [[x["metric"], f(x["run1_ms"], " ms", 2), f(x["run2_ms"], " ms", 2), f"{x['diff_pct']:+d}%"]
                for x in rep["rows"]]
        md += [f"#### Reproducibility: second web run ({rep['within_10pct']} of {rep['total']} medians within 10%)", "",
               table(["Metric (p50 / median)", "Run 1", "Run 2", "Diff"], rows), ""]
    t = r.get("tooling")
    if t:
        rows = []
        names = {"axiom_pull": "`axiom pull` (end to end)", "axiom_generator": "Axiom generator alone",
                 "build_runner": "`dart run build_runner build` (retrofit + json_serializable)"}
        for k, v in t["results"].items():
            for mode in ("cold", "warm", "warm_noop"):
                if mode in v:
                    rows.append([names.get(k, k), mode.replace("_", " "), f(v[mode]["median_s"], " s", 2),
                                 f"{f(v[mode]['min_s'], '', 2)}–{f(v[mode]['max_s'], ' s', 2)}"])
        md += ["#### Client generation time (5 runs each)", "", table(["Tool", "Mode", "Median", "Range"], rows), "",
               "cold: tool caches removed (generator snapshot; `build_runner clean`). warm: caches present; "
               "build_runner gets a changed comment in both input files; warm noop: nothing changed.", ""]
    loc = r.get("loc")
    if loc:
        a = loc["approaches"]
        ax = a["axiom"]
        rows = [["Axiom (Acore contract + config + setup)", ax["hand_written"]["total"],
                 f"{ax.get('hand_written_unary_only', '–')} without the WebSocket endpoint; "
                 f"{ax.get('acore_managed_bodies')} are server bodies", ax["generated"]["total"]],
                ["dio + retrofit + json_serializable", a["dio_retrofit"]["hand_written"]["total"], "",
                 a["dio_retrofit"]["generated"]["total"]],
                ["package:http + manual fromJson", a["http_manual"]["hand_written"]["total"], "", 0]]
        md += ["#### Lines of code for the same API (4 endpoints; non-blank, non-comment)", "",
               table(["Approach", "Hand-written", "Notes", "Generated"], rows), "",
               "Files counted: see `tool/count_loc.py`. The Acore contract also describes the server, so it "
               "is not only client code.", ""]
    s = r.get("size")
    if s:
        if s.get("apk"):
            bd = s.get("apk_breakdown")
            if bd:
                rows = []
                for abi in s["apk"]["axiom"]:
                    b, x = bd["baseline"][abi], bd["axiom"][abi]
                    part = lambda k: x[k]["in_apk"] - b[k]["in_apk"]
                    rows.append([abi, mb(s["apk"]["baseline"][abi]), mb(s["apk"]["axiom"][abi]), kb(s["apk_delta"][abi]),
                                 kb(part("libaxiom_runtime.so")), kb(part("libapp.so (Dart AOT)")),
                                 kb(part("axiom web runtime assets (wasm+js)")), kb(part("contract asset")),
                                 kb(s.get("apk_delta_wasm_opt_out", {}).get(abi))])
                md += ["#### Android APK size (`flutter build apk --release --split-per-abi`)", "",
                       table(["ABI", "Baseline (dio + http)", "With Axiom SDK", "Delta", "of which libaxiom_runtime.so",
                              "Dart AOT (libapp.so)", "web runtime assets (wasm + JS glue)", "contract asset",
                              "Delta with wasm opt-out"], rows), "",
                       "Sizes are bytes inside the APK (the .so files are stored uncompressed, page-aligned; the wasm "
                       "is compressed). The web runtime assets are shipped in Android builds because Flutter 3.32 has "
                       "no per-platform assets; the opt-out in `flutter/axiom_flutter/doc/wasm-size.md` removes them "
                       "(last column). The remainder of the delta is APK metadata/alignment.", ""]
            else:
                rows = [[abi, mb(s["apk"]["baseline"].get(abi)), mb(s["apk"]["axiom"].get(abi)),
                         kb(s.get("apk_delta", {}).get(abi))] for abi in s["apk"].get("axiom", {})]
                md += ["#### Android APK size (`flutter build apk --release --split-per-abi`)", "",
                       table(["ABI", "Baseline (dio + http)", "With Axiom SDK", "Delta"], rows), ""]
            if s.get("apk_note"):
                md += [s["apk_note"], ""]
        if s.get("web"):
            b, x = s["web"]["baseline"], s["web"]["axiom"]
            rows = [["main.dart.js", kb(b["main_dart_js"]), kb(x["main_dart_js"]), kb(x["main_dart_js"] - b["main_dart_js"])],
                    ["main.dart.js gzip -9", kb(b["main_dart_js_gzip"]), kb(x["main_dart_js_gzip"]),
                     kb(x["main_dart_js_gzip"] - b["main_dart_js_gzip"])]]
            for k, v in x.items():
                if k.startswith("axiom_asset:"):
                    rows.append([k.split(":", 1)[1], "–", kb(v), kb(v)])
            if "js_wasm_bytes" in x:
                rows.append(["all JS + wasm (incl. CanvasKit)", mb(b["js_wasm_bytes"]), mb(x["js_wasm_bytes"]),
                             kb(x["js_wasm_bytes"] - b["js_wasm_bytes"])])
                rows.append(["all JS + wasm, gzip -9", mb(b["js_wasm_gzip"]), mb(x["js_wasm_gzip"]),
                             kb(x["js_wasm_gzip"] - b["js_wasm_gzip"])])
            rows.append(["build/web total", mb(b["total_bytes"]), mb(x["total_bytes"]), mb(x["total_bytes"] - b["total_bytes"])])
            md += ["#### Web bundle size (`flutter build web --release`)", "",
                   table(["File", "Baseline", "With Axiom SDK", "Delta"], rows), ""]
    return "\n".join(md)


def main():
    args = sys.argv[1:]
    target = None
    if "--insert" in args:
        i = args.index("--insert")
        target = args[i + 1]
        args = args[:i] + args[i + 2:]
    body = "\n\n".join(render(json.load(open(p))) for p in args)
    body += "\n\nReproduce: see `flutter/benchmarks/README.md`.\n"
    if not target:
        print(body)
        return
    text = open(target).read()
    if START not in text or END not in text:
        sys.exit(f"{target}: markers {START} / {END} not found")
    pre, rest = text.split(START, 1)
    _, post = rest.split(END, 1)
    open(target, "w").write(pre + START + "\n" + body + END + post)
    print("updated", target)


if __name__ == "__main__":
    main()
