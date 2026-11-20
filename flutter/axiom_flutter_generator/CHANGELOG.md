## 0.150.1 - 2026-11-21

Regenerate your client after upgrading to `axiom_flutter` 0.150.1.

Changed
- Faster generated decoders: `String`/`bool` fields decode with an inline
  cast instead of a helper call, optional fields read the JSON map once, and
  lists are created with their final length (`List.generate`, still
  growable); `fromJson` reads the decoded map directly instead of through a
  `cast` view. Model build time for 10 000 items: about 3.4 ms -> 2.0 ms
  (Dart VM AOT). The output API is unchanged.

Known limits
- Validation policy and binary codec options are not generator options in
  this release.

## 0.150.0 - 2026-11-21

Rewritten on the `axiom_flutter` 0.150.0 API. Regenerate your client after
upgrading.

Fixed
- Names that collide after camel-casing (`user_id` and `userId`), or with
  reserved words and generated members, get a deterministic suffix; JSON keys
  are unchanged. Colliding contract type names stop generation with an error.
- Unknown enum values keep their wire value: a model sends it back unchanged,
  and `unknown.toJson()` throws instead of sending `"unknown"`.
- Model RPCs (`rpcs` on a model) are generated again as extension methods.
- `dart:typed_data` is imported only when used; generated files analyze
  cleanly with `flutter_lints`.
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

Breaking changes
- Generated code needs `axiom_flutter` 0.150.0.
- Enums have an `unknown` value and camelCase Dart names (the wire value is
  kept), so an exhaustive `switch` must handle `unknown`. Decoding an unknown
  value no longer throws.
- Names that collided before now get a numeric suffix (`user_id` next to
  `userId` becomes `userId2`), and colliding contract type names stop
  generation with an error.

Known limits
- Web (dart2js): 64-bit integers above 2^53 lose precision.
- `--variant` is passed to the runtime; generation for a managed variant that
  leaves out endpoints is not covered by a run (CLI 0.156.0 cannot build one).

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
