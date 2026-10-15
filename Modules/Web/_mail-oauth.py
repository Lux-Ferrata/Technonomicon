"""Google OAuth2 tokens for aerc (IMAP/SMTP with OAUTHBEARER).

    mail-oauth login <address>   browser login once; keeps the refresh token
    mail-oauth token <address>   prints a valid access token (aerc's cred-cmd)

The client ID/secret are the shared Google OAuth client (sops
google-oauth-client-id / -secret, in /run/secrets). The refresh token lives
in ~/.local/state/mail-oauth/<address> (0600, Kvasir only); access tokens are
cached in $XDG_RUNTIME_DIR until a minute before they expire.
"""
import base64
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

AUTH = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN = "https://oauth2.googleapis.com/token"
SCOPE = "https://mail.google.com/"

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "mail-oauth"
CACHE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "mail-oauth"


def client():
    return {k: Path(f"/run/secrets/google-oauth-{k.replace('_', '-')}").read_text().strip()
            for k in ("client_id", "client_secret")}


def post(params):
    data = urllib.parse.urlencode(params).encode()
    with urllib.request.urlopen(TOKEN, data) as r:
        return json.load(r)


def write_private(path, text):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(text)


def login(address):
    got = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            got.update({k: v[0] for k, v in q.items()})
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Signed in; you can close this tab.")

        def log_message(self, format, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = f"http://127.0.0.1:{server.server_port}/"
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    c = client()
    url = AUTH + "?" + urllib.parse.urlencode({
        "client_id": c["client_id"], "redirect_uri": redirect,
        "response_type": "code", "scope": SCOPE, "login_hint": address,
        "access_type": "offline", "prompt": "consent", "state": state,
        "code_challenge": challenge, "code_challenge_method": "S256",
    })
    print(f"Opening the Google login for {address}:\n{url}")
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    while "code" not in got and "error" not in got:
        server.handle_request()
    if got.get("state") != state or "code" not in got:
        sys.exit(f"login failed: {got.get('error', 'state mismatch')}")
    tok = post({**c, "code": got["code"], "code_verifier": verifier,
                "grant_type": "authorization_code", "redirect_uri": redirect})
    write_private(STATE / address, tok["refresh_token"])
    print(f"saved the refresh token for {address}")


def token(address):
    cached = CACHE / address
    try:
        t = json.loads(cached.read_text())
        if t["expires"] > time.time() + 60:
            print(t["access_token"])
            return
    except (OSError, ValueError, KeyError):
        pass
    try:
        refresh = (STATE / address).read_text().strip()
    except FileNotFoundError:
        sys.exit(f"no login for {address}: run `mail-oauth login {address}`")
    tok = post({**client(), "refresh_token": refresh, "grant_type": "refresh_token"})
    write_private(cached, json.dumps({"access_token": tok["access_token"],
                                      "expires": time.time() + tok["expires_in"]}))
    print(tok["access_token"])


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("login", "token"):
        sys.exit(__doc__)
    {"login": login, "token": token}[sys.argv[1]](sys.argv[2])
