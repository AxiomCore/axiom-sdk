#!/usr/bin/env python3
"""Render a results JSON (results/<date>-<label>.json) as markdown for the repo README.

  python3 tool/render_readme.py results/2026-11-20-linux-chrome.json [more.json ...]   long table
  python3 tool/render_readme.py results/X.json --insert ../../README.md

  Short summary block (the one between the README markers: a timings table with Axiom / dio /
  http columns and a size table), from the web results, optionally the VM results and the
  size table (tool/size_table.py):
  python3 tool/render_readme.py --summary results/<web>.json [--vm results/<vm>.json]
      [--size-table results/size-table.json] [--insert ../../README.md]

  Before/after table for every metric two results files share:
  python3 tool/render_readme.py --compare results/<old>.json results/<new>.json

  Append one line per release and machine to the history file:
  python3 tool/render_readme.py --history results/history.jsonl --release 0.150.1 results/<x>.json ...

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
LABELS.update({"dio_compute": "dio + compute() decode", "dio_http2": "dio + dio_http2_adapter",
               "cronet_http": "cronet_http", "cupertino_http": "cupertino_http", "idle": "idle (no request)",
               "http_ndjson": "package:http, NDJSON stream", "dio_ndjson": "dio, NDJSON stream"})
CASES = {"small_get_item": "getItem (~110 B)", "small_create_item": "createItem (POST)",
         "large_list_1000": "listItems 1 000 items (91 KB)", "large_list_10000": "listItems 10 000 items (938 KB)",
         "repeat_list_1000": "cache hit, 1 000 items, repeat call"}


EXTRA_CASES = {"parallel20_get_item": "20 parallel getItem calls, wall time",
               "parallel20_list_1000": "20 parallel listItems(~1 000) calls, wall time",
               "cached_repeat_list_1000": "repeat call after caching, 1 000 items",
               "offline_first_data_list_1000": "first data with the server unreachable, 1 000 items",
               "list_10000": "10 000 items"}


def describe(key):
    proto = ""
    if key.endswith("]") and " [" in key:
        key, proto = key[:key.rindex(" [")], key[key.rindex(" [") + 2:-1]
    what, client = _describe(key)
    if proto:
        what += f" ({'HTTP/2 over TLS' if proto == 'h2' else 'HTTP/1.1 over TLS'})"
    return what, client


def _describe(key):
    p = key.split()
    if p[0] in ("parallel", "offline", "clients"):
        c = EXTRA_CASES.get(p[1]) or CASES.get(p[1], p[1])
        return f"{c}, {p[3]}", LABELS.get(p[2], p[2])
    if p[0] == "jank":
        return f"Longest UI-isolate stall while fetching + decoding {EXTRA_CASES.get(p[1], p[1])} (median of 10 calls)", LABELS.get(p[2], p[2])
    if p[0] == "ttfi":
        return f"Time to first item, {EXTRA_CASES.get(p[1], p[1])}, p50", LABELS.get(p[2], p[2])
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


# ---------------- short summary, compare, history (unit bench2) ----------------

def _m(r, key):
    """(median, stable, spread) of a web_stats metric, or None."""
    v = (r or {}).get("web_stats", {}).get("metrics", {}).get(key)
    if not v or v.get("median") is None:
        return None
    return v["median"], v.get("stable", False), v.get("spread_pct")


def _ms(v):
    if v is None:
        return "–"
    med, stable, spread = v
    txt = f"{med:,.0f} ms" if med >= 100 else (f"{med:.1f} ms" if med >= 10 else f"{med:.2f} ms")
    return txt if stable else f"not stable ({spread:.0f}% spread)" if spread is not None else "not stable"


SUMMARY_ROWS = [
    # (label, axiom key, dio key, http key)
    ("Cold start to first data", "cold first_data axiom", "cold first_data dio", "cold first_data http"),
    ("getItem (~110 B), p50", "latency small_get_item axiom p50", "latency small_get_item dio p50", "latency small_get_item http p50"),
    ("List of 1 000 items (91 KB), p50", "latency large_list_1000 axiom p50", "latency large_list_1000 dio p50", "latency large_list_1000 http p50"),
    ("List of 10 000 items (938 KB), p50", "latency large_list_10000 axiom p50", "latency large_list_10000 dio p50", "latency large_list_10000 http p50"),
    ("20 parallel getItem calls, all done, p50", "parallel parallel20_get_item axiom p50", "parallel parallel20_get_item dio p50", "parallel parallel20_get_item http p50"),
    ("20 parallel 1 000-item lists, all done, p50", "parallel parallel20_list_1000 axiom p50", "parallel parallel20_list_1000 dio p50", "parallel parallel20_list_1000 http p50"),
    ("Repeat call served from cache, 1 000 items, p50", "cache repeat_list_1000 axiom p50", "cache repeat_list_1000 dio_cache_interceptor p50", None),
    ("First data with the server unreachable, 1 000 items", "offline offline_first_data_list_1000 axiom p50", "offline offline_first_data_list_1000 dio_cache_interceptor p50", None),
    ("Longest UI stall while loading 10 000 items", "jank list_10000 axiom longest_gap_p50", "jank list_10000 dio longest_gap_p50", "jank list_10000 http longest_gap_p50"),
    ("Time to first item, 10 000 items", "latency large_list_10000 axiom p50", "ttfi list_10000 dio_ndjson p50", "ttfi list_10000 http_ndjson p50"),
    ("Decode only, 10 000 items, p50", "decode 10000 axiom_generated p50", "decode 10000 json_serializable p50", "decode 10000 manual_fromJson p50"),
]
NOTES = {"Repeat call served from cache, 1 000 items, p50": (None, " (`dio_cache_interceptor`)", "not applicable"),
         "First data with the server unreachable, 1 000 items": (None, " (`dio_cache_interceptor`)", "fails (no cache)"),
         "Time to first item, 10 000 items": (" (no streaming call; whole list)", " (NDJSON stream)", " (NDJSON stream)"),
         "Decode only, 10 000 items, p50": (None, " (`json_serializable`)", " (manual `fromJson`)")}


def _timing_table(r):
    rows = []
    for label, *keys in SUMMARY_ROWS:
        cells = []
        for i, k in enumerate(keys):
            note = NOTES.get(label, (None, None, None))[i]
            if k is None:
                cells.append(note or "not applicable")
                continue
            v = _m(r, k)
            cells.append(_ms(v) + (note or "") if v else "–")
        if all(c == "–" for c, k in zip(cells, keys) if k is not None):
            continue
        rows.append([label] + cells)
    t = r.get("tooling", {}).get("results", {})
    for mode in ("cold", "warm"):
        g, pull, br = (t.get(k, {}).get(mode, {}).get("median_s") for k in ("axiom_generator", "axiom_pull", "build_runner"))
        if g is not None and br is not None:
            rows.insert(0 if mode == "cold" else 1, [f"Client generation, {mode}", f"{g:.1f} s (`axiom pull` {pull:.1f} s)",
                                                     f"{br:.1f} s (`build_runner`)", "none"])
    loc = r.get("loc", {}).get("approaches")
    if loc:
        rows.append(["Hand-written client code", f"{loc['axiom']['hand_written']['total']} lines",
                     f"{loc['dio_retrofit']['hand_written']['total']} lines (plus {loc['dio_retrofit']['generated']['total']} generated)",
                     f"{loc['http_manual']['hand_written']['total']} lines"])
    return table(["Measurement", "Axiom", "dio + retrofit", "package:http"], rows)


def _size_table(st):
    v = st.get("variants", {})
    base = v.get("baseline", {})
    rows = []
    names = {"axiom": "Axiom (runtime bundled by axiom_flutter)", "axiom_extensions": "Axiom + `axiom_flutter_extensions`"}
    for name, x in v.items():
        if name == "baseline":
            continue
        label = names.get(name, f"Axiom, runtime `{name}`")
        if x.get("status") != "ok":
            rows.append([label, "not available on this branch", "", ""])
            continue
        for abi, d in (x.get("apk_delta_vs_baseline") or {}).items():
            a = x["apk"][abi]
            rows.append([f"{label}, Android {abi}", mb(d), mb(a.get("runtime_raw", a.get("axiom_so_raw"))), mb(a.get("runtime_gzip9", a.get("axiom_so_gzip9")))])
        wd = x.get("web_delta_vs_baseline")
        if wd:
            rows.append([f"{label}, web", f"{mb(wd['js_wasm_raw'])} ({mb(wd['js_wasm_gzip'])} gzip, {mb(wd['js_wasm_brotli'])} brotli)",
                         mb(x['web']['axiom_assets']['raw']), mb(x['web']['axiom_assets']['gzip'])])
    return table(["Target", "Added to the app", "Runtime installed", "Runtime download (gzip -9)"], rows)


def summary(web, vm=None, size_table=None, size_legacy=None):
    m = web.get("machine", {})
    md = [f"Measured {web.get('date')} on a {m.get('cores')} vCPU Linux container: release web build in headless "
          f"{(m.get('chrome') or 'Chrome').replace('Google ', '')}, {(web.get('flutter') or '').split(' •')[0]}, "
          f"local loopback server, {len(web.get('web_runs', [])) or 3} full run(s). Each value is the median of the run "
          "medians; a value whose runs differ by more than 10% is shown as not stable. These are not "
          "physical-device numbers. All clients call the same server.", ""]
    md += [_timing_table(web), ""]
    if vm:
        md += [f"Native Dart VM on the same machine (Linux x86_64, `flutter_tester` JIT, host runtime library; "
               f"a server CPU, not a phone), {len(vm.get('web_runs', [])) or 3} run(s):", "", _timing_table(vm), ""]
    if size_table:
        md += ["Size added to an app:", "", _size_table(size_table), ""]
    elif web.get("size", {}).get("apk_delta"):
        sz = web["size"]
        rows = [[f"Android APK, {abi}", f"{mb(d)} (runtime library {mb(sz['apk_breakdown']['axiom'][abi]['libaxiom_runtime.so']['in_apk'])})"]
                for abi, d in sz["apk_delta"].items()]
        if sz.get("web_delta"):
            rows.append(["Web", f"{mb(sz['web_delta']['js_wasm_bytes'])} ({mb(sz['web_delta']['js_wasm_gzip'])} gzip)"])
        md += ["Size added to an app:", "", table(["Target", "Added"], rows), ""]
    md += ["The full table, including every unstable metric, the HTTP/2 rows and the method, is in "
           "[`flutter/benchmarks`](flutter/benchmarks/README.md) and "
           "[`flutter/benchmarks/results/README-TABLE.md`](flutter/benchmarks/results/README-TABLE.md).", ""]
    return "\n".join(md)


def compare_md(old, new):
    om = old.get("web_stats", {}).get("metrics", {})
    nm = new.get("web_stats", {}).get("metrics", {})
    rows = []
    for k, n in nm.items():
        o = om.get(k)
        if not o or o.get("median") is None or n.get("median") is None:
            continue
        what, client = describe(k)
        ch = (n["median"] - o["median"]) / o["median"] * 100 if o["median"] else None
        both = o.get("stable") and n.get("stable")
        rows.append([what, client, f"{o['median']:g}", f"{n['median']:g}",
                     "–" if ch is None else f"{ch:+.0f}%",
                     "yes" if both else f"no ({o.get('spread_pct')}% / {n.get('spread_pct')}%)"])
    head = (f"#### Before/after: {old.get('label')} {old.get('date')} (`{old.get('sdk_commit')}`) vs "
            f"{new.get('label')} {new.get('date')} (`{new.get('sdk_commit')}`)")
    return "\n".join([head, "", "Medians of the run medians (ms; ws: round trips/s). A change is only meaningful "
                       "when both sides are stable (spread <= 10%).", "",
                       table(["Measurement", "Client", "Before", "After", "Change", "Both stable"], rows), ""])


def history_line(r, release):
    ws = r.get("web_stats", {}).get("metrics", {})
    return {"release": release, "date": r.get("date"), "label": r.get("label"), "sdk_commit": r.get("sdk_commit"),
            "machine": {k: r.get("machine", {}).get(k) for k in ("cores", "ram_gb", "os", "chrome", "virtualised")},
            "runs": len(r.get("web_runs", [])),
            "stable": {k: v["median"] for k, v in ws.items() if v.get("stable")},
            "not_stable": {k: v.get("spread_pct") for k, v in ws.items() if not v.get("stable")}}


def _opt(args, name, n=1):
    if name not in args:
        return args, None
    i = args.index(name)
    val = args[i + 1] if n == 1 else True
    return args[:i] + args[i + 1 + n - (0 if n == 1 else 1):] if n != 1 else args[:i] + args[i + 2:], val


def main():
    args = sys.argv[1:]
    if "--compare" in args:
        args.remove("--compare")
        print(compare_md(json.load(open(args[0])), json.load(open(args[1]))))
        return
    if "--history" in args:
        args, hist = _opt(args, "--history")
        args, rel = _opt(args, "--release")
        with open(hist, "a") as fh:
            for p in args:
                fh.write(json.dumps(history_line(json.load(open(p)), rel or "unreleased")) + "\n")
        print("appended", len(args), "line(s) to", hist)
        return
    if "--summary" in args:
        args.remove("--summary")
        args, vm = _opt(args, "--vm")
        args, st = _opt(args, "--size-table")
        args, target = _opt(args, "--insert")
        body = summary(json.load(open(args[0])), json.load(open(vm)) if vm else None,
                       json.load(open(st)) if st else None)
        if not target:
            print(body)
            return
        text = open(target).read()
        pre, rest = text.split(START, 1)
        _, post = rest.split(END, 1)
        open(target, "w").write(pre + START + "\n" + body + END + post)
        print("updated", target)
        return
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
