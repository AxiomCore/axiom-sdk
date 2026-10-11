# Local validation and release

Builds, checks and artifact uploads are owned by the local release cycle.
GitHub Actions is reserved for SDK publication; push, pull-request, scheduled
and release-tag CI jobs are disabled.

Run release operations from the sibling private `Axiom-release-plane` checkout:

```sh
just release containers
just release web
```

Useful repository checks:

```sh
python3 scripts/check-public-boundary.py
python3.12 flutter/axiom_flutter/test/native/run_response_ownership.py
```

`former-github-actions/` preserves the previous command recipes for reference;
these files are outside GitHub's workflow directory and cannot start Actions.
Setup steps and GitHub expressions in those recipes are historical, not a
local execution interface. Use the commands above and the controller's operator guide. Native/editor acceptance on this Mac covers macOS ARM64;
Windows and other host-platform qualification must run on those platforms.
Upstream Lynx qualification remains available through the private controller's
qualification scripts when evaluating a new engine version.
