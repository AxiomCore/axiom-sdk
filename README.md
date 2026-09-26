# Axiom SDKs

Public client SDK source for AxiomCore. Each package is versioned and released independently; consult its package README and changelog for the supported integration path.

| Path | Package | Purpose |
| --- | --- | --- |
| [`flutter/axiom_flutter`](flutter/axiom_flutter/README.md) | [`axiom_flutter`](https://pub.dev/packages/axiom_flutter) | Flutter runtime bindings |
| [`flutter/axiom_flutter_generator`](flutter/axiom_flutter_generator/README.md) | [`axiom_flutter_generator`](https://pub.dev/packages/axiom_flutter_generator) | Dart client generation |
| [`swift`](swift/Package.swift) | Swift package source | Apple client integration |

The ATMX web and React packages are maintained in separate repositories. Published package archives and platform release artifacts are mirrored to [AxiomCore Releases](https://github.com/AxiomCore/AxiomCore/releases). Release orchestration and operator notes are kept in private repositories; they are not part of this SDK source tree.

For Flutter changes, run `dart analyze` and the package tests from the affected package directory. Native builds additionally require the platform toolchain described by that package. Do not commit local build outputs, credentials, `.DS_Store`, or `.summary_files`.
