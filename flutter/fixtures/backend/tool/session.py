"""Fixture-only cookie-session helpers for the WebSocket-on-web instance (FIXTURE_AUTH=session).

Browsers cannot put Authorization on a WebSocket upgrade, but they do send cookies, and the
server's Session provider reads the cookie on GET (the upgrade) without a CSRF proof.
  session.py token [origin]        the session value for a page origin (checks_g.dart derives it too)
  session.py patch deployment.json registry.json
"""
import hashlib, json, os, sys

COOKIE = "axiom_fixture_session"
# The server demands a CSRF proof on every non-GET request, and it sees the WebSocket upgrade as
# method WS. A browser cannot add a header to the upgrade, and the CLI forbids `origin` as the CSRF
# header, so the fixture names `sec-websocket-extensions`, whose value every Chromium browser sends
# verbatim ("permessage-deflate; client_max_window_bits"; Firefox and Safari send
# "permessage-deflate"). One session per (browser family, origin). This defeats the CSRF check and
# is FIXTURE ONLY: it exists to prove the WebSocket path on web. Product finding: cookie-session
# WebSockets cannot carry a real CSRF proof from a browser.
EXTENSIONS = {"chromium": "permessage-deflate; client_max_window_bits", "other": "permessage-deflate"}
ORIGINS = ["http://127.0.0.1:8792", "http://localhost:8792", "http://127.0.0.1:8802", "http://localhost:8802"]


def sha(v: str) -> str:
    return hashlib.sha256(v.encode()).hexdigest()


def token(origin: str, family: str = "chromium") -> str:
    """Session value for a page served from [origin] (checks_g.dart computes the same)."""
    return "fixture-session-" + sha(family + " " + origin)[:16]


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "token":
        print(token(sys.argv[2] if len(sys.argv) > 2 else ORIGINS[0]))
    elif cmd == "patch":
        deployment, registry = sys.argv[2], sys.argv[3]
        d = json.load(open(deployment))
        d["authentication"] = {"kind": "session", "cookie": COOKIE, "registryFileEnv": "AXIOM_FIXTURE_SESSION_REGISTRY",
                               "csrfHeader": "sec-websocket-extensions", "origins": ORIGINS}
        json.dump(d, open(deployment, "w"), indent=2)
        fd = os.open(registry, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump({sha(token(o, fam)): {"principal": {"subject": "fixture-user"}, "expiresUnixSeconds": 4102444800,
                                            "csrfSha256": sha(ext)}
                       for o in ORIGINS for fam, ext in EXTENSIONS.items()}, f)
        os.chmod(registry, 0o600)
