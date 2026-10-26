"""Offline tests for metadata validation, the API token and the sync plan (no network)."""

import base64
import json
import struct
import sys
import tempfile
import textwrap
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from asc_client import make_token
from config import ConfigError, load
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import (
    encode_dss_signature,
)
from sync import Syncer

BASE = """
app:
  bundle_id: com.example.app
  primary_locale: ja
  content_rights: DOES_NOT_USE_THIRD_PARTY_CONTENT
  categories: {primary: GAMES, primary_subcategories: [GAMES_SIMULATION]}
version: {version_string: "1.0.0", copyright: "2026 Example", release_type: MANUAL}
localizations:
  ja:
    name: テスト
    subtitle: サブ
    privacy_policy_url: https://example.com/privacy
    support_url: https://example.com/support
    keywords: a,b
    description: 説明
    whats_new: 新機能
age_rating: {violenceRealistic: NONE, gambling: false}
review:
  contact_email: ${REVIEW_EMAIL}
  notes: メモ
"""


def png(width, height):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IEND", b"")


class Workspace:
    def __init__(self, text, files=None):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.path = self.root / "metadata.yml"
        self.path.write_text(textwrap.dedent(text), encoding="utf-8")
        for name, data in (files or {}).items():
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.workspaces = []
        self.addCleanup(lambda: [ws.dir.cleanup() for ws in self.workspaces])

    def track(self, workspace):
        self.workspaces.append(workspace)
        return workspace

    def test_valid_file_resolves_secrets_from_the_environment(self):
        ws = self.track(Workspace(BASE))
        meta = load(ws.path, ws.root, env={"REVIEW_EMAIL": "a@example.com"})
        self.assertEqual(meta.review["contact_email"], "a@example.com")
        self.assertEqual(meta.localizations["ja"]["name"], "テスト")

    def test_strict_mode_reports_todos_missing_secrets_and_limits(self):
        text = BASE.replace("name: テスト", "name: " + "あ" * 31).replace(
            "support_url: https://example.com/support", 'support_url: "TODO: later"'
        )
        ws = self.track(Workspace(text))
        with self.assertRaises(ConfigError) as caught:
            load(ws.path, ws.root, env={})
        problems = "\n".join(caught.exception.problems)
        self.assertIn("name: 31 characters (max 30)", problems)
        self.assertIn("support_url: still a TODO placeholder", problems)
        self.assertIn("REVIEW_EMAIL is not set", problems)

    def test_lenient_mode_allows_todos_for_pull_requests(self):
        ws = self.track(
            Workspace(BASE.replace("support_url: https://example.com/support", 'support_url: "TODO: later"'))
        )
        meta = load(ws.path, ws.root, env={}, strict=False)
        self.assertEqual(meta.bundle_id, "com.example.app")

    def test_http_urls_and_bad_versions_are_rejected(self):
        ws = self.track(
            Workspace(
                BASE.replace("https://example.com/privacy", "http://example.com/privacy").replace('"1.0.0"', '"one"')
            )
        )
        with self.assertRaises(ConfigError) as caught:
            load(ws.path, ws.root, env={"REVIEW_EMAIL": "a@example.com"})
        problems = "\n".join(caught.exception.problems)
        self.assertIn("privacy_policy_url: must be an https:// URL", problems)
        self.assertIn("version_string must look like", problems)

    def test_screenshot_sizes_are_checked(self):
        text = BASE + "screenshots:\n  ja:\n    APP_IPHONE_67: shots\n"
        ws = self.track(Workspace(text, {"shots/01.png": png(1320, 2868), "shots/02.png": png(1000, 1000)}))
        with self.assertRaises(ConfigError) as caught:
            load(ws.path, ws.root, env={"REVIEW_EMAIL": "a@example.com"})
        self.assertIn("shots/02.png: size (1000, 1000)", "\n".join(caught.exception.problems))


class TokenTests(unittest.TestCase):
    def test_token_is_a_verifiable_es256_jwt(self):
        key = ec.generate_private_key(ec.SECP256R1())
        pem = key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
        ).decode()
        token = make_token("KEY123", "issuer-1", pem, now=1_000)
        header, payload, signature = token.split(".")

        def decode(part):
            return base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))

        self.assertEqual(json.loads(decode(header)), {"alg": "ES256", "kid": "KEY123", "typ": "JWT"})
        claims = json.loads(decode(payload))
        self.assertEqual(
            (claims["iss"], claims["aud"], claims["exp"] - claims["iat"]), ("issuer-1", "appstoreconnect-v1", 900)
        )
        raw = decode(signature)
        der = encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big"))
        key.public_key().verify(der, f"{header}.{payload}".encode(), ec.ECDSA(hashes.SHA256()))


class FakeClient:
    """Answers the reads the syncer makes from a canned state and records writes."""

    def __init__(self, live_version=False):
        self.writes = []
        self.live_version = live_version

    def get(self, path):
        if path.startswith("/v1/apps?"):
            return {"data": [{"id": "app1", "attributes": {"contentRightsDeclaration": None}}]}
        if path == "/v1/apps/app1/appInfos":
            return {"data": [{"id": "info1", "attributes": {"state": "PREPARE_FOR_SUBMISSION"}}]}
        if path.startswith("/v1/appInfos/info1?include"):
            return {"data": {"relationships": {"primaryCategory": {"data": {"id": "GAMES"}}}}}
        if path == "/v1/appInfos/info1/appInfoLocalizations":
            return {"data": [{"id": "ail1", "attributes": {"locale": "ja", "name": "テスト", "subtitle": "古い"}}]}
        if path == "/v1/appInfos/info1/ageRatingDeclaration":
            return {"data": {"id": "age1", "attributes": {"violenceRealistic": "NONE", "gambling": None}}}
        if path.startswith("/v1/apps/app1/appStoreVersions"):
            versions = [
                {
                    "id": "v1",
                    "attributes": {
                        "appStoreState": "PREPARE_FOR_SUBMISSION",
                        "versionString": "1.0.0",
                        "copyright": "2026 Example",
                        "releaseType": "MANUAL",
                    },
                }
            ]
            if self.live_version:
                versions.append({"id": "v0", "attributes": {"appStoreState": "READY_FOR_SALE"}})
            return {"data": versions}
        if path == "/v1/appStoreVersions/v1/appStoreVersionLocalizations":
            return {"data": []}
        if path == "/v1/appStoreVersions/v1/appStoreReviewDetail":
            return {"data": None}
        raise AssertionError(f"unexpected GET {path}")

    def post(self, path, body):
        self.writes.append(("POST", path, body))
        return {"data": {"id": f"new{len(self.writes)}", "attributes": {}}}

    def patch(self, path, body):
        self.writes.append(("PATCH", path, body))
        return {}

    def delete(self, path):
        self.writes.append(("DELETE", path, None))
        return {}


class SyncTests(unittest.TestCase):
    def metadata(self):
        ws = Workspace(BASE)
        self.addCleanup(ws.dir.cleanup)
        return load(ws.path, ws.root, env={"REVIEW_EMAIL": "a@example.com"})

    def test_plan_writes_nothing_and_lists_only_differences(self):
        client = FakeClient()
        lines = []
        changes = Syncer(client, self.metadata(), apply=False, log=lines.append).run()
        self.assertEqual(client.writes, [])
        text = "\n".join(lines)
        self.assertIn("update app: contentRightsDeclaration", text)
        self.assertIn("update categories: primarySubcategoryOne=GAMES_SIMULATION", text)
        self.assertIn("update app info [ja]: subtitle='サブ'", text)
        self.assertNotIn("name=", text.split("app info [ja]")[1].splitlines()[0])  # unchanged name not sent
        self.assertIn("update age rating: gambling=", text)
        self.assertIn("create version text [ja]", text)
        self.assertIn("create review information: contactEmail=***", text)  # secrets are masked
        self.assertEqual(changes, 6)

    def test_apply_creates_localization_without_whats_new_on_first_release(self):
        client = FakeClient()
        Syncer(client, self.metadata(), apply=True, log=lambda _: None).run()
        created = next(b for _, p, b in client.writes if p == "/v1/appStoreVersionLocalizations")
        attributes = created["data"]["attributes"]
        self.assertEqual(attributes["locale"], "ja")
        self.assertNotIn("whatsNew", attributes)
        self.assertEqual(created["data"]["relationships"]["appStoreVersion"]["data"]["id"], "v1")

    def test_whats_new_is_sent_once_the_app_is_live_and_submit_is_explicit(self):
        client = FakeClient(live_version=True)
        Syncer(client, self.metadata(), apply=True, log=lambda _: None).run()
        created = next(b for _, p, b in client.writes if p == "/v1/appStoreVersionLocalizations")
        self.assertEqual(created["data"]["attributes"]["whatsNew"], "新機能")
        self.assertFalse(any("reviewSubmissions" in p for _, p, _ in client.writes))

        submitting = FakeClient(live_version=True)
        Syncer(submitting, self.metadata(), apply=True, log=lambda _: None).run(submit=True)
        final = submitting.writes[-1]
        self.assertEqual(final[0], "PATCH")
        self.assertTrue(final[2]["data"]["attributes"]["submitted"])


class CollectScreenshotsTests(unittest.TestCase):
    def test_only_appstore_attachments_are_copied_in_order(self):
        from collect_screenshots import collect

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            export = root / "export"
            export.mkdir()
            (export / "a.png").write_bytes(png(1320, 2868))
            (export / "b.png").write_bytes(png(1320, 2868))
            (export / "c.png").write_bytes(png(1, 1))
            manifest = [
                {
                    "attachments": [
                        {"exportedFileName": "b.png", "suggestedHumanReadableName": "appstore-02-quests_0_X.png"},
                        {"exportedFileName": "a.png", "suggestedHumanReadableName": "appstore-01-island_0_Y.png"},
                        {"exportedFileName": "c.png", "suggestedHumanReadableName": "07-field-guide_0_Z.png"},
                    ]
                }
            ]
            (export / "manifest.json").write_text(json.dumps(manifest))
            target = root / "shots"
            target.mkdir()
            (target / "old.png").write_bytes(b"stale")
            copied = collect(export, target)
            self.assertEqual([p.name for p in copied], ["01-island.png", "02-quests.png"])
            self.assertEqual(sorted(p.name for p in target.iterdir()), ["01-island.png", "02-quests.png"])


if __name__ == "__main__":
    unittest.main()
