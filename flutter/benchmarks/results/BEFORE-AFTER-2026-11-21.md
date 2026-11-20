#### Before/after: linux-chrome-idle 2026-11-20 (`6cd7d9f (origin/flutter/parity) + benchmark-only changes on flutter/l2`) vs linux-chrome-idle 2026-11-20 (`6a48226 (axiom-sdk flutter/perf, BENCH_GO)`)

Medians of the run medians (ms; ws: round trips/s). A change is only meaningful when both sides are stable (spread <= 10%).

| Measurement | Client | Before | After | Change | Both stable |
| --- | --- | --- | --- | --- | --- |
| Cold start, time to first data (median of 5 launches) | Axiom | 261.6 | 259.4 | -1% | yes |
| Cold start, runtime/client init (median of 5 launches) | Axiom | 250.8 | 247.4 | -1% | yes |
| Cold start, time to first data (median of 5 launches) | dio + retrofit | 221.2 | 219.4 | -1% | yes |
| Cold start, runtime/client init (median of 5 launches) | dio + retrofit | 0.3 | 0.4 | +33% | no (33.3% / 25.0%) |
| Cold start, time to first data (median of 5 launches) | package:http | 218.9 | 215 | -2% | yes |
| Cold start, runtime/client init (median of 5 launches) | package:http | 0 | 0 | – | no (None% / None%) |
| getItem (~110 B), p50 | Axiom | 2.8 | 2.701 | -4% | no (14.4% / 11.1%) |
| getItem (~110 B), p95 | Axiom | 3.601 | 3.701 | +3% | no (27.8% / 18.9%) |
| getItem (~110 B), p50 | dio + retrofit | 1.901 | 1.801 | -5% | no (15.8% / 11.1%) |
| getItem (~110 B), p95 | dio + retrofit | 2.4 | 2.5 | +4% | yes |
| getItem (~110 B), p50 | package:http | 1.8 | 1.701 | -5% | no (11.2% / 11.8%) |
| getItem (~110 B), p95 | package:http | 2.2 | 2.299 | +4% | no (9.1% / 13.1%) |
| createItem (POST), p50 | Axiom | 2.099 | 2 | -5% | no (9.5% / 15.0%) |
| createItem (POST), p95 | Axiom | 2.401 | 2.5 | +4% | no (12.5% / 8.0%) |
| createItem (POST), p50 | dio + retrofit | 2 | 1.899 | -5% | no (10.0% / 21.1%) |
| createItem (POST), p95 | dio + retrofit | 2.401 | 2.201 | -8% | no (8.4% / 22.6%) |
| createItem (POST), p50 | package:http | 1.801 | 1.699 | -6% | no (11.0% / 17.7%) |
| createItem (POST), p95 | package:http | 2.3 | 1.901 | -17% | no (0.0% / 26.3%) |
| listItems 1 000 items (91 KB), p50 | Axiom | 5.301 | 3.4 | -36% | yes |
| listItems 1 000 items (91 KB), p95 | Axiom | 6.4 | 4.1 | -36% | yes |
| listItems 1 000 items (91 KB), p50 | dio + retrofit | 3.4 | 3.4 | +0% | yes |
| listItems 1 000 items (91 KB), p95 | dio + retrofit | 7.2 | 7 | -3% | no (9.7% / 10.0%) |
| listItems 1 000 items (91 KB), p50 | package:http | 3.099 | 2.9 | -6% | yes |
| listItems 1 000 items (91 KB), p95 | package:http | 3.6 | 3.6 | +0% | yes |
| listItems 10 000 items (938 KB), p50 | Axiom | 33.201 | 15.4 | -54% | yes |
| listItems 10 000 items (938 KB), p95 | Axiom | 40.699 | 17.2 | -58% | no (12.0% / 4.6%) |
| listItems 10 000 items (938 KB), p50 | dio + retrofit | 18.6 | 18.301 | -2% | yes |
| listItems 10 000 items (938 KB), p95 | dio + retrofit | 26.9 | 25.2 | -6% | no (12.3% / 2.0%) |
| listItems 10 000 items (938 KB), p50 | package:http | 13.199 | 12.701 | -4% | yes |
| listItems 10 000 items (938 KB), p95 | package:http | 16 | 14.301 | -11% | no (13.7% / 11.2%) |
| cache hit, 1 000 items, repeat call, p50 | Axiom | 5 | 3.5 | -30% | yes |
| cache hit, 1 000 items, repeat call, p95 | Axiom | 7.199 | 4.4 | -39% | no (15.3% / 11.3%) |
| cache hit, 1 000 items, repeat call, p50 | dio + dio_cache_interceptor | 26.4 | 24.699 | -6% | yes |
| cache hit, 1 000 items, repeat call, p95 | dio + dio_cache_interceptor | 29 | 29 | +0% | no (3.1% / 12.8%) |
| Decode only, 1,000 items, p50 (main isolate, no network) | jsonDecode only | 0.701 | 0.4 | -43% | no (128.2% / 24.8%) |
| Decode only, 1,000 items, p50 (main isolate, no network) | Axiom generated models | 1.2 | 1 | -17% | no (158.3% / 30.0%) |
| Decode only, 1,000 items, p50 (main isolate, no network) | json_serializable | 1.601 | 1.5 | -6% | no (75.0% / 20.0%) |
| Decode only, 1,000 items, p50 (main isolate, no network) | manual fromJson | 1.6 | 0.9 | -44% | no (49.9% / 22.2%) |
| Decode only, 10,000 items, p50 (main isolate, no network) | jsonDecode only | 4.1 | 4.201 | +2% | no (4.9% / 11.9%) |
| Decode only, 10,000 items, p50 (main isolate, no network) | Axiom generated models | 10.8 | 8.699 | -19% | yes |
| Decode only, 10,000 items, p50 (main isolate, no network) | json_serializable | 12.5 | 13.2 | +6% | yes |
| Decode only, 10,000 items, p50 (main isolate, no network) | manual fromJson | 9.5 | 9.5 | +0% | yes |
| WebSocket echo, 1 000 sequential round trips | web_socket_channel | 4522.86 | 4336.53 | -4% | no (13.0% / 12.6%) |
| WebSocket echo, 1 000 sequential round trips | Axiom | 3560 | 2692.51 | -24% | no (55.3% / 67.6%) |

