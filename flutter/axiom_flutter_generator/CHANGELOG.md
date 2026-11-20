## 0.150.0 - 2026-11-21

Rewritten on the `axiom_flutter` 0.150.0 API. Regenerate your client after
upgrading.

Fixed
- Several body fields are encoded as one JSON object; a single body
  parameter as its raw JSON value.
- Bytes are encoded and decoded as base64.
- Header parameters are sent as headers.
- Stream endpoints decode SSE and NDJSON frames.
- Output is deterministic and has a `// GENERATED CODE` header with the
  generator version and contract schema hash. No `print`, no imports of
  `axiom_flutter` internals.
- The contract SHA-256 from `AxiomDeps.toml` is passed to the runtime in
  release builds (locked load).

Added
- `AxiomSdk.create({config, environment, baseUrlOverrides, assetLoader})` on
  top of `AxiomRuntime.initialize`, and `AxiomSdk.fromRuntime` for tests.
- Base URL from `--base-url` or `base_url` in `AxiomDeps.toml`.
- Dart enums with an `unknown` fallback, sealed unions, `DateTime`,
  `Uint8List`, value equality, `copyWith`, `toString`.
- Typed failures: a class per contract failure, `<Endpoint>Errors`,
  `error.when<Endpoint>(...)`, `error.contractFailure`.
- `Stream<T>` methods for SSE and chunked endpoints, `AxiomChannel` methods
  for WebSocket endpoints.
- `options: AxiomCallOptions?` on every method.
- Mutations refetch the active queries of the cache identities they
  invalidate; `idempotencyKey` parameter for idempotent commands.
- `<Model>Validators` from contract field rules.
- `endpointIds`, `cacheIdentities` and `authMethods` constants.
- Flags `--variant`, `--namespace`, `--signature`, `--public-key`,
  `--sha256`, `--contract`, `--out-dir`, `--[no-]format`.
- Golden tests.

## 0.146.6

- Feature: Add sdk-flutter-generator improvements in 0.146.6.

## 0.146.5

- Feature: Add sdk-flutter-generator improvements in 0.146.5.

## 0.146.4

- Feature: Add sdk flutter generator improvements in 0.146.4.

## 0.146.3

- Feature: Add sdk flutter generator improvements in 0.146.3.

## 0.146.2

- Feature: Add sdk flutter generator improvements in 0.146.2.

## 0.146.1

- Feature: Add sdk flutter generator improvements in 0.146.1.

## 0.146.0

- Feature: Add sdk flutter generator improvements in 0.146.0.

## 0.0.3

- Fixed type inference issue in ModelWriter when mapping List values.

## 0.0.2

- Fixed type inference issue in ModelWriter when mapping List values.

## 0.0.1

- Initial version.
