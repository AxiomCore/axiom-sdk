Measured 2026-11-20 on a 4 vCPU Linux container: release web build in headless Chrome 158.0.8127.36, Flutter 3.32.0, local loopback server, 3 full run(s). Each value is the median of the run medians; a value whose runs differ by more than 10% is shown as not stable. These are not physical-device numbers. All clients call the same server.

| Measurement | Axiom | dio + retrofit | package:http |
| --- | --- | --- | --- |
| Cold start to first data | 259 ms | 219 ms | 215 ms |
| getItem (~110 B), p50 | not stable (11% spread) | not stable (11% spread) | not stable (12% spread) |
| List of 1 000 items (91 KB), p50 | 3.40 ms | 3.40 ms | 2.90 ms |
| List of 10 000 items (938 KB), p50 | 15.4 ms | 18.3 ms | 12.7 ms |
| 20 parallel getItem calls, all done, p50 | 31.8 ms | not stable (13% spread) | not stable (23% spread) |
| 20 parallel 1 000-item lists, all done, p50 | 40.3 ms | 47.4 ms | 35.9 ms |
| Repeat call served from cache, 1 000 items, p50 | 3.50 ms | 24.7 ms (`dio_cache_interceptor`) | not applicable |
| First data with the server unreachable, 1 000 items | 3.40 ms | not stable (22% spread) (`dio_cache_interceptor`) | fails (no cache) |
| Longest UI stall while loading 10 000 items | 11.7 ms | not stable (17% spread) | 9.90 ms |
| Time to first item, 10 000 items | 15.4 ms (no streaming call; whole list) | 24.2 ms (NDJSON stream) | not stable (20% spread) (NDJSON stream) |
| Decode only, 10 000 items, p50 | 8.70 ms | 13.2 ms (`json_serializable`) | 9.50 ms (manual `fromJson`) |

Native Dart VM on the same machine (Linux x86_64, `flutter_tester` JIT, host runtime library; a server CPU, not a phone), 3 run(s):

| Measurement | Axiom | dio + retrofit | package:http |
| --- | --- | --- | --- |
| Cold start to first data | not stable (13% spread) | 36.2 ms | 17.7 ms |
| getItem (~110 B), p50 | 1.04 ms | 1.34 ms | 0.76 ms |
| List of 1 000 items (91 KB), p50 | 1.76 ms | 2.46 ms | 1.84 ms |
| List of 10 000 items (938 KB), p50 | 21.4 ms | 24.6 ms | 14.0 ms |
| 20 parallel getItem calls, all done, p50 | 11.9 ms | 14.0 ms | 10.8 ms |
| 20 parallel 1 000-item lists, all done, p50 | 35.7 ms | 46.8 ms | 53.3 ms |
| Repeat call served from cache, 1 000 items, p50 | not stable (11% spread) | 1.45 ms (`dio_cache_interceptor`) | not applicable |
| First data with the server unreachable, 1 000 items | 1.50 ms | 2.69 ms (`dio_cache_interceptor`) | fails (no cache) |
| Longest UI stall while loading 10 000 items | not stable (15% spread) | not stable (12% spread) | not stable (28% spread) |
| Time to first item, 10 000 items | 21.4 ms (no streaming call; whole list) | not stable (14% spread) (NDJSON stream) | 2.21 ms (NDJSON stream) |
| Decode only, 10 000 items, p50 | 10.8 ms | 10.9 ms (`json_serializable`) | 11.2 ms (manual `fromJson`) |

Size added to an app:

| Target | Added to the app | Runtime installed | Runtime download (gzip -9) |
| --- | --- | --- | --- |
| Axiom (runtime bundled by axiom_flutter), Android arm64-v8a | 4.79 MB | 4.58 MB | 2.27 MB |
| Axiom (runtime bundled by axiom_flutter), Android armeabi-v7a | 3.49 MB | 3.25 MB | 1.87 MB |
| Axiom (runtime bundled by axiom_flutter), Android x86_64 | 5.65 MB | 5.44 MB | 2.39 MB |
| Axiom (runtime bundled by axiom_flutter), web | 2.12 MB (0.79 MB gzip, 0.58 MB brotli) | 2.06 MB | 0.77 MB |
| Axiom + `axiom_flutter_extensions`, Android arm64-v8a | 7.24 MB | 7.03 MB | 3.34 MB |
| Axiom + `axiom_flutter_extensions`, Android armeabi-v7a | 5.19 MB | 4.96 MB | 2.76 MB |
| Axiom + `axiom_flutter_extensions`, Android x86_64 | 8.65 MB | 8.45 MB | 3.50 MB |
| Axiom + `axiom_flutter_extensions`, web | 2.12 MB (0.79 MB gzip, 0.58 MB brotli) | 2.06 MB | 0.77 MB |

The full table, including every unstable metric, the HTTP/2 rows and the method, is in [`flutter/benchmarks`](flutter/benchmarks/README.md) and [`flutter/benchmarks/results/README-TABLE.md`](flutter/benchmarks/results/README-TABLE.md).

