# Native binding tests (host)

`native_runtime_test.dart` drives the real dart:ffi binding (`runtime_io.dart`)
against a host build of the runtime and the fixture backend. Skipped unless
`AXIOM_RUNTIME_LIB` is set (it is also the library path override the binding
honours, only when set).

```sh
# 1. host runtime (any axiom-runtime checkout; flutter/r adds the optional exports)
(cd axiom-runtime && cargo build --release --lib)      # -> target/release/libaxiom_runtime.so (.dylib on macOS)
# 2. fixture backend on 127.0.0.1:8791
flutter/fixtures/backend/run.sh 8791 &
# 3. tests
cd flutter/axiom_flutter
AXIOM_RUNTIME_LIB=/abs/path/libaxiom_runtime.so \
AXIOM_FIXTURE_CONTRACT=../integration_app/assets/axiom/fixture.axiom \
flutter test test/native/native_runtime_test.dart
```

The "slow" namespace points at a loopback socket that accepts and never
answers, so cancellation, timeout and reset tests have a request in flight.
