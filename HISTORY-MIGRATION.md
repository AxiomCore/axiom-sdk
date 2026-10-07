# Public history migration — 7 October 2026

Generated `.summary_files` source captures were removed from maintained branches and tags. Public SDK code, runtime bytes, package versions, dependency locks and licenses are preserved. Source ref IDs changed; use a fresh clone and replay reviewed local work instead of merging old histories or pushing old tags. Existing published package bytes are unchanged.

The public-source CI check detects reintroduction of selected internal/generated paths anywhere in reachable history. Review source exports before pushing; CI detection does not recall bytes already copied elsewhere. Native/Wasm and browser code shipped to clients remain inspectable. Previously downloaded or cached history cannot be recalled.
