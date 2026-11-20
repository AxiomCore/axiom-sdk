### linux-chrome-idle (2026-11-20)

Machine: CPU model not reported (gVisor), 4 vCPU, 32.0 GB RAM, Debian GNU/Linux 12 (bookworm) (kernel 4.19.0-gvisor), gVisor sandbox / container (shared host). Flutter 3.32.0 • channel stable • https://github.com/flutter/flutter.git. Axiom CLI axiom 0.156.0. SDK commit `6a48226 (axiom-sdk flutter/perf, BENCH_GO)`. Browser: Google Chrome 158.0.8127.36.

- Web numbers: headless Chrome on a 4 vCPU Linux container (no GPU), release build (dart2js), server on 127.0.0.1. Not a physical device.
- All three clients call the same local Dart server (api/server); see README for method.

#### App benchmarks: web, headless Chrome, release build, 3 full runs (not a physical device)

Each value is the median of the 3 run medians; spread = (max - min) / median of the run medians. Only metrics with spread <= 10% are listed (60 of 94). Time: lower is better; round trips/s: higher is better.

| Measurement | Client | Median | Spread | Run medians |
| --- | --- | --- | --- | --- |
| Cold start, time to first data (median of 5 launches) | Axiom | 259 ms | 0.9% | 259.4 / 259.4 / 261.8 |
| Cold start, runtime/client init (median of 5 launches) | Axiom | 247 ms | 1.3% | 247.4 / 247.4 / 250.6 |
| Cold start, time to first data (median of 5 launches) | dio + retrofit | 219 ms | 2.7% | 219.4 / 222.7 / 216.8 |
| Cold start, time to first data (median of 5 launches) | package:http | 215 ms | 4.7% | 215 / 224.6 / 214.6 |
| getItem (~110 B), p95 | dio + retrofit | 2.50 ms | 4.0% | 2.5 / 2.4 / 2.5 |
| createItem (POST), p95 | Axiom | 2.50 ms | 8.0% | 2.5 / 2.5 / 2.3 |
| listItems 1 000 items (91 KB), p50 | Axiom | 3.40 ms | 5.9% | 3.5 / 3.4 / 3.3 |
| listItems 1 000 items (91 KB), p95 | Axiom | 4.10 ms | 4.9% | 4.299 / 4.099 / 4.1 |
| listItems 1 000 items (91 KB), p50 | dio + retrofit | 3.40 ms | 5.9% | 3.4 / 3.4 / 3.201 |
| listItems 1 000 items (91 KB), p50 | package:http | 2.90 ms | 3.4% | 3 / 2.9 / 2.9 |
| listItems 1 000 items (91 KB), p95 | package:http | 3.60 ms | 8.4% | 3.9 / 3.6 / 3.599 |
| listItems 10 000 items (938 KB), p50 | Axiom | 15.40 ms | 1.3% | 15.299 / 15.4 / 15.5 |
| listItems 10 000 items (938 KB), p95 | Axiom | 17.20 ms | 4.6% | 17.101 / 17.2 / 17.9 |
| listItems 10 000 items (938 KB), p50 | dio + retrofit | 18.30 ms | 7.1% | 18.9 / 18.301 / 17.6 |
| listItems 10 000 items (938 KB), p95 | dio + retrofit | 25.20 ms | 2.0% | 25 / 25.5 / 25.2 |
| listItems 10 000 items (938 KB), p50 | package:http | 12.70 ms | 4.7% | 13.1 / 12.701 / 12.5 |
| getItem (~110 B), p50 | Axiom | 2.50 ms | 8.0% | 2.701 / 2.5 / 2.5 |
| getItem (~110 B), p50 | dio + retrofit | 1.70 ms | 5.8% | 1.8 / 1.701 / 1.701 |
| getItem (~110 B), p50 | package:http | 1.60 ms | 6.2% | 1.699 / 1.6 / 1.601 |
| listItems 1 000 items (91 KB), p50 | Axiom | 3.30 ms | 0.1% | 3.301 / 3.299 / 3.3 |
| listItems 1 000 items (91 KB), p50 | dio + retrofit | 3.30 ms | 0.0% | 3.3 / 3.3 / 3.3 |
| listItems 1 000 items (91 KB), p50 | dio + compute() decode | 3.30 ms | 3.0% | 3.4 / 3.301 / 3.3 |
| listItems 1 000 items (91 KB), p50 | package:http | 2.90 ms | 0.0% | 2.901 / 2.9 / 2.9 |
| listItems 10 000 items (938 KB), p50 | Axiom | 15.40 ms | 4.6% | 15.399 / 15.4 / 16.1 |
| listItems 10 000 items (938 KB), p50 | dio + retrofit | 19.30 ms | 9.8% | 19.301 / 19.7 / 17.8 |
| listItems 10 000 items (938 KB), p50 | dio + compute() decode | 17.60 ms | 1.1% | 17.601 / 17.5 / 17.7 |
| listItems 10 000 items (938 KB), p50 | package:http | 13.00 ms | 2.3% | 12.9 / 13 / 13.2 |
| getItem (~110 B), p50 (HTTP/2 over TLS) | dio + retrofit | 2.00 ms | 9.9% | 2.199 / 2 / 2 |
| getItem (~110 B), p50 (HTTP/2 over TLS) | package:http | 2.00 ms | 5.0% | 2 / 2 / 1.9 |
| listItems 1 000 items (91 KB), p50 (HTTP/2 over TLS) | Axiom | 5.20 ms | 5.8% | 5.5 / 5.199 / 5.2 |
| listItems 1 000 items (91 KB), p50 (HTTP/2 over TLS) | dio + retrofit | 4.40 ms | 2.3% | 4.5 / 4.401 / 4.4 |
| listItems 1 000 items (91 KB), p50 (HTTP/2 over TLS) | dio + compute() decode | 4.50 ms | 0.0% | 4.5 / 4.5 / 4.5 |
| listItems 1 000 items (91 KB), p50 (HTTP/2 over TLS) | package:http | 4.00 ms | 0.0% | 4 / 4 / 4 |
| listItems 10 000 items (938 KB), p50 (HTTP/2 over TLS) | Axiom | 26.20 ms | 1.1% | 26.199 / 26.201 / 25.9 |
| listItems 10 000 items (938 KB), p50 (HTTP/2 over TLS) | dio + retrofit | 29.60 ms | 8.4% | 31.201 / 28.7 / 29.6 |
| listItems 10 000 items (938 KB), p50 (HTTP/2 over TLS) | dio + compute() decode | 27.00 ms | 0.7% | 27 / 26.9 / 27.1 |
| listItems 10 000 items (938 KB), p50 (HTTP/2 over TLS) | package:http | 23.50 ms | 1.7% | 23.399 / 23.799 / 23.5 |
| 20 parallel getItem calls, wall time, p50 | Axiom | 31.80 ms | 9.4% | 34.5 / 31.799 / 31.5 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | Axiom | 40.30 ms | 4.0% | 40.299 / 40.4 / 38.8 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | dio + retrofit | 47.40 ms | 4.9% | 46.601 / 47.4 / 48.9 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | dio + compute() decode | 43.10 ms | 1.2% | 43 / 43.1 / 43.5 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | package:http | 35.90 ms | 2.5% | 35.1 / 36 / 35.901 |
| 20 parallel getItem calls, wall time, p50 (HTTP/2 over TLS) | dio + retrofit | 17.40 ms | 2.9% | 17.2 / 17.4 / 17.7 |
| 20 parallel getItem calls, wall time, p50 (HTTP/2 over TLS) | package:http | 15.30 ms | 9.1% | 16.599 / 15.3 / 15.2 |
| 20 parallel listItems(~1 000) calls, wall time, p50 (HTTP/2 over TLS) | package:http | 55.80 ms | 4.1% | 56.299 / 55.799 / 54 |
| repeat call after caching, 1 000 items, p50 | Axiom | 3.50 ms | 5.7% | 3.5 / 3.5 / 3.7 |
| first data with the server unreachable, 1 000 items, p50 | Axiom | 3.40 ms | 5.9% | 3.4 / 3.401 / 3.599 |
| repeat call after caching, 1 000 items, p50 | dio + dio_cache_interceptor | 4.80 ms | 2.1% | 4.701 / 4.799 / 4.8 |
| Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) | idle (no request) | 4.40 ms | 0.0% | 4.401 / 4.401 / 4.401 |
| Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) | Axiom | 11.70 ms | 4.3% | 11.699 / 11.199 / 11.701 |
| Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) | dio + compute() decode | 14.00 ms | 4.3% | 14 / 14.5 / 13.899 |
| Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) | package:http | 9.90 ms | 6.1% | 10.4 / 9.9 / 9.8 |
| Time to first item, 10 000 items, p50 | dio, NDJSON stream | 24.20 ms | 0.4% | 24.199 / 24.199 / 24.3 |
| Time to first item, 10 000 items, p50 (HTTP/2 over TLS) | package:http, NDJSON stream | 10.90 ms | 8.3% | 10.9 / 10.299 / 11.2 |
| Time to first item, 10 000 items, p50 (HTTP/2 over TLS) | dio, NDJSON stream | 33.50 ms | 3.9% | 33.5 / 34.399 / 33.1 |
| cache hit, 1 000 items, repeat call, p50 | Axiom | 3.50 ms | 5.7% | 3.599 / 3.401 / 3.5 |
| cache hit, 1 000 items, repeat call, p50 | dio + dio_cache_interceptor | 24.70 ms | 3.2% | 24.1 / 24.699 / 24.899 |
| Decode only, 10,000 items, p50 (main isolate, no network) | Axiom generated models | 8.70 ms | 2.3% | 8.799 / 8.599 / 8.699 |
| Decode only, 10,000 items, p50 (main isolate, no network) | json_serializable | 13.20 ms | 1.5% | 13.401 / 13.2 / 13.199 |
| Decode only, 10,000 items, p50 (main isolate, no network) | manual fromJson | 9.50 ms | 7.4% | 9.799 / 9.5 / 9.1 |

Not stable (spread above 10%, not published as a number): Cold start, runtime/client init (median of 5 launches) dio + retrofit (25%); Cold start, runtime/client init (median of 5 launches) package:http (n/a); getItem (~110 B), p50 Axiom (11%); getItem (~110 B), p95 Axiom (19%); getItem (~110 B), p50 dio + retrofit (11%); getItem (~110 B), p50 package:http (12%); getItem (~110 B), p95 package:http (13%); createItem (POST), p50 Axiom (15%); createItem (POST), p50 dio + retrofit (21%); createItem (POST), p95 dio + retrofit (23%); createItem (POST), p50 package:http (18%); createItem (POST), p95 package:http (26%); listItems 1 000 items (91 KB), p95 dio + retrofit (10%); listItems 10 000 items (938 KB), p95 package:http (11%); getItem (~110 B), p50 (HTTP/2 over TLS) Axiom (12%); 20 parallel getItem calls, wall time, p50 dio + retrofit (13%); 20 parallel getItem calls, wall time, p50 package:http (23%); 20 parallel getItem calls, wall time, p50 (HTTP/2 over TLS) Axiom (22%); 20 parallel listItems(~1 000) calls, wall time, p50 (HTTP/2 over TLS) Axiom (12%); 20 parallel listItems(~1 000) calls, wall time, p50 (HTTP/2 over TLS) dio + retrofit (86%); 20 parallel listItems(~1 000) calls, wall time, p50 (HTTP/2 over TLS) dio + compute() decode (22%); first data with the server unreachable, 1 000 items, p50 dio + dio_cache_interceptor (22%); repeat call after caching, 1 000 items, p50 package:http (23%); Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) dio + retrofit (17%); Time to first item, 10 000 items, p50 package:http, NDJSON stream (20%); cache hit, 1 000 items, repeat call, p95 Axiom (11%); cache hit, 1 000 items, repeat call, p95 dio + dio_cache_interceptor (13%); Decode only, 1,000 items, p50 (main isolate, no network) jsonDecode only (25%); Decode only, 1,000 items, p50 (main isolate, no network) Axiom generated models (30%); Decode only, 1,000 items, p50 (main isolate, no network) json_serializable (20%); Decode only, 1,000 items, p50 (main isolate, no network) manual fromJson (22%); Decode only, 10,000 items, p50 (main isolate, no network) jsonDecode only (12%); WebSocket echo, 1 000 sequential round trips web_socket_channel (13%); WebSocket echo, 1 000 sequential round trips Axiom (68%).


### linux-vm (2026-11-20)

Machine: CPU model not reported (gVisor), 4 vCPU, 32.0 GB RAM, Debian GNU/Linux 12 (bookworm) (kernel 4.19.0-gvisor), gVisor sandbox / container (shared host). Flutter 3.32.0 • channel stable • https://github.com/flutter/flutter.git. Axiom CLI axiom 0.156.0. SDK commit `6a48226 (axiom-sdk flutter/perf, BENCH_GO)`. Browser: Google Chrome 158.0.8127.36.

- Web numbers: headless Chrome on a 4 vCPU Linux container (no GPU), release build (dart2js), server on 127.0.0.1. Not a physical device.
- All three clients call the same local Dart server (api/server); see README for method.
- Native column: Dart VM in flutter_tester (JIT) on the same Linux x86_64 container, host runtime library lean/linux-x64; not a phone.

#### App benchmarks: web, headless Chrome, release build, 3 full runs (not a physical device)

Each value is the median of the 3 run medians; spread = (max - min) / median of the run medians. Only metrics with spread <= 10% are listed (53 of 77). Time: lower is better; round trips/s: higher is better.

| Measurement | Client | Median | Spread | Run medians |
| --- | --- | --- | --- | --- |
| Cold start, time to first data (median of 5 launches) | dio + retrofit | 36.20 ms | 3.9% | 36.2 / 35.9 / 37.3 |
| Cold start, runtime/client init (median of 5 launches) | dio + retrofit | 5.00 ms | 10.0% | 5 / 4.9 / 5.4 |
| Cold start, time to first data (median of 5 launches) | package:http | 17.70 ms | 5.6% | 18.4 / 17.7 / 17.4 |
| getItem (~110 B), p50 | Axiom | 1.04 ms | 2.5% | 1.036 / 1.062 / 1.045 |
| getItem (~110 B), p95 | Axiom | 1.71 ms | 3.7% | 1.712 / 1.67 / 1.734 |
| getItem (~110 B), p50 | dio + retrofit | 1.34 ms | 7.1% | 1.337 / 1.315 / 1.41 |
| getItem (~110 B), p50 | package:http | 0.76 ms | 5.3% | 0.725 / 0.755 / 0.765 |
| createItem (POST), p50 | Axiom | 0.66 ms | 4.1% | 0.661 / 0.653 / 0.68 |
| createItem (POST), p50 | dio + retrofit | 1.26 ms | 6.8% | 1.258 / 1.255 / 1.34 |
| createItem (POST), p50 | package:http | 0.70 ms | 1.9% | 0.696 / 0.694 / 0.707 |
| createItem (POST), p95 | package:http | 1.06 ms | 1.5% | 1.057 / 1.047 / 1.063 |
| listItems 1 000 items (91 KB), p50 | Axiom | 1.76 ms | 2.0% | 1.737 / 1.764 / 1.773 |
| listItems 1 000 items (91 KB), p95 | Axiom | 2.30 ms | 9.3% | 2.233 / 2.446 / 2.296 |
| listItems 1 000 items (91 KB), p50 | dio + retrofit | 2.46 ms | 5.0% | 2.53 / 2.458 / 2.407 |
| listItems 1 000 items (91 KB), p95 | dio + retrofit | 3.32 ms | 6.1% | 3.16 / 3.363 / 3.324 |
| listItems 1 000 items (91 KB), p50 | package:http | 1.84 ms | 6.9% | 1.954 / 1.843 / 1.826 |
| listItems 10 000 items (938 KB), p50 | Axiom | 21.41 ms | 3.5% | 21.563 / 20.824 / 21.405 |
| listItems 10 000 items (938 KB), p95 | Axiom | 28.23 ms | 1.6% | 28.231 / 27.969 / 28.415 |
| listItems 10 000 items (938 KB), p50 | dio + retrofit | 24.58 ms | 6.6% | 24.58 / 23.275 / 24.904 |
| listItems 10 000 items (938 KB), p95 | dio + retrofit | 33.28 ms | 6.8% | 33.28 / 31.771 / 34.029 |
| listItems 10 000 items (938 KB), p50 | package:http | 13.99 ms | 4.7% | 13.848 / 13.994 / 14.512 |
| listItems 10 000 items (938 KB), p95 | package:http | 21.59 ms | 6.6% | 21.586 / 21.464 / 22.882 |
| listItems 1 000 items (91 KB), p50 | Axiom | 1.81 ms | 4.7% | 1.865 / 1.78 / 1.807 |
| listItems 1 000 items (91 KB), p50 | dio + retrofit | 2.47 ms | 2.4% | 2.435 / 2.469 / 2.494 |
| listItems 1 000 items (91 KB), p50 | dio + compute() decode | 2.45 ms | 4.4% | 2.483 / 2.375 / 2.45 |
| listItems 1 000 items (91 KB), p50 | package:http | 1.87 ms | 4.4% | 1.896 / 1.871 / 1.813 |
| listItems 10 000 items (938 KB), p50 | Axiom | 21.02 ms | 2.4% | 20.642 / 21.025 / 21.145 |
| listItems 10 000 items (938 KB), p50 | dio + retrofit | 23.46 ms | 2.1% | 23.739 / 23.246 / 23.461 |
| listItems 10 000 items (938 KB), p50 | dio + compute() decode | 18.86 ms | 5.5% | 18.845 / 19.875 / 18.86 |
| listItems 10 000 items (938 KB), p50 (HTTP/2 over TLS) | dio + dio_http2_adapter | 61.95 ms | 9.6% | 67.351 / 61.38 / 61.955 |
| 20 parallel getItem calls, wall time, p50 | Axiom | 11.92 ms | 2.8% | 11.782 / 11.918 / 12.112 |
| 20 parallel getItem calls, wall time, p50 | dio + retrofit | 14.01 ms | 4.1% | 13.861 / 14.005 / 14.429 |
| 20 parallel getItem calls, wall time, p50 | package:http | 10.81 ms | 2.6% | 10.673 / 10.954 / 10.807 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | Axiom | 35.66 ms | 6.0% | 36.203 / 35.657 / 34.076 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | dio + retrofit | 46.81 ms | 8.9% | 44.093 / 46.81 / 48.261 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | dio + compute() decode | 37.20 ms | 6.1% | 35.982 / 37.202 / 38.249 |
| 20 parallel listItems(~1 000) calls, wall time, p50 | package:http | 53.28 ms | 4.7% | 51.768 / 54.277 / 53.281 |
| repeat call after caching, 1 000 items, p50 | Axiom | 1.55 ms | 8.8% | 1.507 / 1.644 / 1.552 |
| first data with the server unreachable, 1 000 items, p50 | Axiom | 1.50 ms | 4.7% | 1.453 / 1.523 / 1.495 |
| repeat call after caching, 1 000 items, p50 | dio + dio_cache_interceptor | 4.53 ms | 5.3% | 4.532 / 4.626 / 4.385 |
| first data with the server unreachable, 1 000 items, p50 | dio + dio_cache_interceptor | 2.69 ms | 7.6% | 2.695 / 2.806 / 2.601 |
| repeat call after caching, 1 000 items, p50 | package:http | 1.88 ms | 2.6% | 1.919 / 1.879 / 1.87 |
| Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) | idle (no request) | 2.12 ms | 2.7% | 2.117 / 2.171 / 2.114 |
| Time to first item, 10 000 items, p50 | package:http, NDJSON stream | 2.21 ms | 2.8% | 2.19 / 2.252 / 2.207 |
| cache hit, 1 000 items, repeat call, p50 | dio + dio_cache_interceptor | 1.45 ms | 5.4% | 1.448 / 1.465 / 1.387 |
| Decode only, 1,000 items, p50 (main isolate, no network) | jsonDecode only | 0.72 ms | 4.6% | 0.717 / 0.725 / 0.692 |
| Decode only, 1,000 items, p50 (main isolate, no network) | Axiom generated models | 0.85 ms | 7.9% | 0.881 / 0.849 / 0.814 |
| Decode only, 1,000 items, p50 (main isolate, no network) | json_serializable | 0.90 ms | 4.3% | 0.917 / 0.902 / 0.878 |
| Decode only, 1,000 items, p50 (main isolate, no network) | manual fromJson | 0.80 ms | 5.4% | 0.803 / 0.84 / 0.797 |
| Decode only, 10,000 items, p50 (main isolate, no network) | jsonDecode only | 10.32 ms | 6.5% | 10.815 / 10.323 / 10.14 |
| Decode only, 10,000 items, p50 (main isolate, no network) | Axiom generated models | 10.83 ms | 4.2% | 11.254 / 10.827 / 10.796 |
| Decode only, 10,000 items, p50 (main isolate, no network) | json_serializable | 10.87 ms | 3.1% | 10.745 / 11.081 / 10.871 |
| Decode only, 10,000 items, p50 (main isolate, no network) | manual fromJson | 11.17 ms | 1.1% | 11.187 / 11.166 / 11.068 |

Not stable (spread above 10%, not published as a number): Cold start, time to first data (median of 5 launches) Axiom (13%); Cold start, runtime/client init (median of 5 launches) Axiom (15%); Cold start, runtime/client init (median of 5 launches) package:http (14%); getItem (~110 B), p95 dio + retrofit (15%); getItem (~110 B), p95 package:http (18%); createItem (POST), p95 Axiom (15%); createItem (POST), p95 dio + retrofit (12%); listItems 1 000 items (91 KB), p95 package:http (19%); getItem (~110 B), p50 Axiom (15%); getItem (~110 B), p50 dio + retrofit (17%); getItem (~110 B), p50 package:http (10%); listItems 10 000 items (938 KB), p50 package:http (18%); getItem (~110 B), p50 (HTTP/2 over TLS) dio + dio_http2_adapter (27%); listItems 1 000 items (91 KB), p50 (HTTP/2 over TLS) dio + dio_http2_adapter (10%); 20 parallel getItem calls, wall time, p50 (HTTP/2 over TLS) dio + dio_http2_adapter (30%); 20 parallel listItems(~1 000) calls, wall time, p50 (HTTP/2 over TLS) dio + dio_http2_adapter (13%); Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) Axiom (15%); Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) dio + retrofit (12%); Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) dio + compute() decode (13%); Longest UI-isolate stall while fetching + decoding 10 000 items (median of 10 calls) package:http (28%); Time to first item, 10 000 items, p50 dio, NDJSON stream (14%); cache hit, 1 000 items, repeat call, p50 Axiom (11%); cache hit, 1 000 items, repeat call, p95 Axiom (57%); cache hit, 1 000 items, repeat call, p95 dio + dio_cache_interceptor (15%).


Reproduce: see `flutter/benchmarks/README.md`.

