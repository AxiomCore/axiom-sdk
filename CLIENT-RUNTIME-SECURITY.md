# Client runtime and artifact guarantees

Shipped JavaScript, WebAssembly, native libraries and contract metadata can be inspected and reverse engineered. Minification and signatures do not encrypt them. Keep confidential business logic, authoritative authentication/authorization, production HMAC secrets and signing private keys on the server. Public verification keys and documented SDK adapters may be distributed.

Current contract data uses plain JSON/JCS. Historical AXOM/XOR bundles and secured XOR envelopes are retired; rebuild their authoring source with a compatible current compiler/runtime. Renaming a legacy file is not migration. Reader and package versions must match the selected consumer. Other application and extension formats retain their own version/signature validators.

A signature validates exact bytes against a selected trusted public key. A hash lock alone does not authenticate a publisher. A local unsigned fixture is a distinct compatibility mode; it cannot provide release authenticity. SDK contract-load errors must reach the caller instead of being silently ignored.

The repository source includes contract-load error propagation for Flutter IO and Web adapters. Existing registry/framework distributions are immutable and require separate versioned runtime and SDK qualification before adopting updated integrity guarantees. Use exact release hashes and a supported package/platform matrix; source changes and unit tests do not certify an older downloaded binary. Treat required startup, verification and compatibility errors as failures before sending application requests.

Do not expose local synthetic fixture logins through a public proxy. Backend endpoints must enforce authentication themselves even when a client contract also describes auth requirements.

Native response memory belongs to the C ABI until its callback releases it. Flutter IO copies data/error bytes into Dart-owned storage before releasing the native frame and sending to another isolate. The controlled ownership test poisons native storage at release, then checks 200 queued responses; it also checks startup/load error propagation. Run `python3 flutter/axiom_flutter/test/native/run_response_ownership.py` with `DART` set if needed. This test uses the production Dart IO adapter and a controlled C ABI fixture, independently of Flutter rendering and the production runtime build.
