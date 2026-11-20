# axiom_flutter_generator

Generates a typed Dart client for [`axiom_flutter`](https://pub.dev/packages/axiom_flutter)
from an Axiom contract (`.axiom` file).

It is a command-line tool. The `axiom` CLI runs it for you during
`axiom pull --framework flutter`, as
`dart run axiom_flutter_generator:generate`. It is not a `build_runner`
builder, and you do not write any configuration for it by hand.

## Install

```yaml
dev_dependencies:
  axiom_flutter_generator: ^0.150.0
```

Keep it on the same minor version as `axiom_flutter`.

## Usage

Most projects only run:

```sh
axiom pull path/to/backend.axiom --framework flutter --name todos --out lib/axiom_generated
```

`axiom pull` copies the contract to `assets/axiom/todos.axiom`, records it in
`AxiomDeps.toml` (with its SHA-256), runs `dart pub get`, then runs the
generator. To regenerate after editing `AxiomDeps.toml`, run `axiom pull`
again, or call the generator directly from the project root:

```sh
dart run axiom_flutter_generator:generate --config AxiomDeps.toml --out axiom_generated
```

### Flags

| Flag | Meaning |
| --- | --- |
| `--config <path>` | `AxiomDeps.toml` to read. Required unless `--contract` is given. |
| `--out <dir>` | Output folder under `lib/`. Default `axiom_generated`. |
| `--project-root <path>` | Flutter project root (where `pubspec.yaml` is). Default: current folder. |
| `--base-url <url>` | Default base URL written into the generated config. |
| `--variant <name>` | Emit only the endpoints of this contract variant. |
| `--namespace <name>` | Apply `--base-url`, `--signature`, `--public-key`, `--sha256` to this contract only. |
| `--signature <b64>` | Contract signature. |
| `--public-key <b64>` | Public key that verifies the signature. |
| `--sha256 <hex>` | Contract SHA-256. Computed from the asset when omitted. |
| `--contract <file>` | Generate from this `.axiom` file instead of `AxiomDeps.toml` (needs `--namespace`). |
| `--out-dir <path>` | Absolute output folder; overrides `--project-root` and `--out`. |
| `--[no-]format` | Run `dart format` on the output. Default on. |
| `-h`, `--help` | Print the flags. |

### `AxiomDeps.toml`

One table per contract. The table name is the namespace used in Dart.

```toml
framework = "flutter"

[contracts.todos]
source = "../backend/backend.axiom"   # where axiom pull got it
base_url = "https://api.example.com"  # optional
variant = "mobile"                    # optional
sha256 = "..."                        # written by axiom pull
signature = "..."                     # optional, base64
public_key = "..."                    # optional, base64
```

Flags override these keys. The contract is looked up in this order:
`assets/axiom/<name>.axiom`, then `source`, then
`~/.axiom/contracts/<name>/contract.axiom`.

## What it generates

```
lib/axiom_generated/
  axiom_sdk.dart   AxiomSdk entry point, AxiomDefaultConfig, one module per contract
  models.dart      models, enums, unions, failures, validators
```

Both files start with `// GENERATED CODE - DO NOT EDIT.`, the generator
version, and the contract id and schema hash. Output is deterministic: the
same contract gives the same bytes.

`axiom_sdk.dart`:

- `AxiomSdk.create({config, environment, baseUrlOverrides, assetLoader})`
  starts the runtime and loads every contract. `AxiomSdk.fromRuntime(runtime)`
  wraps a runtime you set up yourself (tests).
- `AxiomDefaultConfig.config`: base URL, asset path, signature and public
  key per contract. Release builds also pass the SHA-256 for a locked load.
- One module per contract (`sdk.todos`), with one method per endpoint:
  - queries and commands return `AxiomQuery<T>`; path, query, header and body
    parameters become named Dart parameters; every method takes
    `AxiomCallOptions? options`
  - SSE and chunked endpoints return `Stream<T>`
  - WebSocket endpoints return `AxiomChannel<Receive, Send>` with the
    contract's reconnect policy
  - commands with `invalidates` refetch the matching active queries on
    success; idempotent commands take an `idempotencyKey`
- `endpointIds`, `cacheIdentities` and `authMethods` constants per module.
- Model RPCs (`rpcs` on a model) become extension methods on the model,
  e.g. `person.getContacts(sdk.rpc, limit: 10)`, which call the mapped
  endpoint with the request built by the RPC resolver.
- `sdk.<ns>.axiom`: tokens (`setAuthToken`, `setNamespaceToken`) and
  `invalidateAll()` for the namespace.

`models.dart`:

- a class per model with `fromJson`, `toJson`, `==`, `hashCode`, `copyWith`
  and `toString`
- Dart enums with an `unknown` value for values added on the server later.
  A model keeps the original wire value of such a field and sends it back
  unchanged; `unknown.toJson()` on its own throws instead of inventing a value
- sealed classes for unions
- `DateTime` for timestamps, `Uint8List` for bytes (base64 on the wire)
- a class per contract `failure`, a sealed `<Endpoint>Errors` type and
  `error.when<Endpoint>(...)` matchers on `AxiomError`
- `<Model>Validators` with one `String? Function(String?)` per field rule,
  usable as a `TextFormField` validator

Names: a Dart name that two contract names map to (`user_id` and `userId`),
or that clashes with a reserved word or a generated member (`toJson`,
`copyWith`, `hashCode`, `axiom`, ...), gets a `$` prefix or a numeric suffix
(`userId2`). A name that is already valid as written keeps it. JSON keys are
never renamed. Two contract types or namespaces that map to the same Dart
class name stop generation with an error.

`int64` fields map to `int`. On the web `jsonDecode` rounds integers above
2^53 (snowflake IDs, for example) without an error, so send such values as
strings in the contract.

The generated files analyze cleanly with `flutter_lints`. You can still
exclude them from analysis:

```yaml
analyzer:
  exclude:
    - lib/axiom_generated/**
```

## Development

```sh
dart test                      # golden tests
UPDATE_GOLDENS=1 dart test     # accept new output
```

## License

MIT
