#!/usr/bin/env python3
"""Hanging HTTP endpoint for the integration checks (cancel, timeout, reset).

Accepts every connection, reads the request and never answers it, so a
request stays in flight until the client cancels or times out. CORS
preflights (OPTIONS) are answered, so browsers send the real request.
Python 3 standard library only.

  python3 -I flutter/fixtures/tool/hang.py [port]     # default 8806, or $HANG_PORT
  # then run the app with --dart-define=FIXTURE_HANG_URL=http://127.0.0.1:8806
  # (Android emulator: http://10.0.2.2:8806)
"""
import os
import socket
import sys
import threading

HOST = os.environ.get("HANG_HOST", "127.0.0.1")
PORT = int(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("HANG_PORT", "8806"))


def read_head(conn):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            return None
        data += chunk
        if len(data) > 65536:
            return None
    return data.split(b"\r\n\r\n", 1)[0].decode("latin-1")


def handle(conn):
    try:
        while True:
            head = read_head(conn)
            if head is None:
                return
            lines = head.split("\r\n")
            method = lines[0].split(" ", 1)[0].upper()
            headers = {}
            for line in lines[1:]:
                if ":" in line:
                    k, v = line.split(":", 1)
                    headers[k.strip().lower()] = v.strip()
            if method != "OPTIONS":
                # Hold the connection until the client goes away.
                while conn.recv(4096):
                    pass
                return
            origin = headers.get("origin", "*")
            allow_headers = headers.get("access-control-request-headers", "*")
            body = (
                "HTTP/1.1 204 No Content\r\n"
                f"Access-Control-Allow-Origin: {origin}\r\n"
                "Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\n"
                f"Access-Control-Allow-Headers: {allow_headers}\r\n"
                "Access-Control-Allow-Credentials: true\r\n"
                "Access-Control-Max-Age: 600\r\n"
                "Vary: Origin\r\n"
                "Content-Length: 0\r\n\r\n"
            )
            conn.sendall(body.encode("latin-1"))
    except OSError:
        pass
    finally:
        try:
            conn.close()
        except OSError:
            pass


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(128)
    print(f"hang server on http://{HOST}:{PORT} (never answers; OPTIONS answered)", flush=True)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
