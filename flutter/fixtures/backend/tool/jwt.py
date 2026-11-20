"""Fixture-only HS256 helpers: patch deployment.json and mint the fixed test token."""
import base64, hashlib, hmac, json, sys

SECRET = "axiom-fixture-hs256-secret-not-for-production-0001"
ISSUER = "https://fixture.axiomcore.local"
AUDIENCE = "axiom-fixture"
EXP = 4102444800  # 2100-01-01


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token(subject: str = "fixture-user") -> str:
    header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    claims = {"iss": ISSUER, "aud": AUDIENCE, "sub": subject, "exp": EXP, "iat": 1763640000}
    body = b64(json.dumps(claims, separators=(",", ":")).encode())
    sig = hmac.new(SECRET.encode(), f"{header}.{body}".encode(), hashlib.sha256).digest()
    return f"{header}.{body}.{b64(sig)}"


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "token":
        print(token())
    elif cmd == "secret":
        print(SECRET)
    elif cmd == "patch":
        path = sys.argv[2]
        d = json.load(open(path))
        d["authentication"] = {"kind": "jwt", "issuer": ISSUER, "audience": AUDIENCE,
                               "algorithm": "HS256", "keyEnv": "AXIOM_FIXTURE_JWT_SECRET"}
        json.dump(d, open(path, "w"), indent=2)
