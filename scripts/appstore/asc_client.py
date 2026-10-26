"""Minimal App Store Connect API client: ES256 JWT auth and JSON requests (standard library + cryptography)."""

from __future__ import annotations

import base64
import json
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

API = "https://api.appstoreconnect.apple.com"


class APIError(Exception):
    def __init__(self, method: str, path: str, status: int, body: str):
        detail = body
        try:
            errors = json.loads(body).get("errors", [])
            detail = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors) or body
        except ValueError:
            pass
        super().__init__(f"{method} {path} -> {status}: {detail}")
        self.status = status


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_token(key_id: str, issuer_id: str, private_key_pem: str, now: float | None = None) -> str:
    """JWT for the API (valid 15 minutes; Apple allows at most 20)."""
    now = time.time() if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer_id, "iat": int(now), "exp": int(now) + 900, "aud": "appstoreconnect-v1"}
    signing_input = f"{_b64(json.dumps(header).encode())}.{_b64(json.dumps(payload).encode())}".encode()
    key = serialization.load_pem_private_key(private_key_pem.encode(), password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise TypeError("ASC_KEY_P8 is not an EC private key")
    r, s = decode_dss_signature(key.sign(signing_input, ec.ECDSA(hashes.SHA256())))
    signature = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return f"{signing_input.decode()}.{_b64(signature)}"


class Client:
    def __init__(self, key_id: str, issuer_id: str, private_key_pem: str):
        self._credentials = (key_id, issuer_id, private_key_pem)
        self._token = ""
        self._token_time = 0.0

    def _auth(self) -> str:
        if time.time() - self._token_time > 600:
            self._token = make_token(*self._credentials)
            self._token_time = time.time()
        return self._token

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(API + path, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self._auth()}")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                text = response.read().decode()
        except urllib.error.HTTPError as error:
            raise APIError(method, path, error.code, error.read().decode()) from None
        return json.loads(text) if text else {}

    def get(self, path: str) -> dict:
        return self.request("GET", path)

    def post(self, path: str, body: dict) -> dict:
        return self.request("POST", path, body)

    def patch(self, path: str, body: dict) -> dict:
        return self.request("PATCH", path, body)

    def delete(self, path: str) -> dict:
        return self.request("DELETE", path)

    def upload(self, operation: dict, chunk: bytes) -> None:
        """One upload operation of an asset reservation (pre-signed URL; no API token)."""
        request = urllib.request.Request(operation["url"], data=chunk, method=operation["method"])
        for header in operation.get("requestHeaders", []):
            request.add_header(header["name"], header["value"])
        with urllib.request.urlopen(request, timeout=120):
            pass
