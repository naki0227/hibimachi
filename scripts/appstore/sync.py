"""Applies Metadata to App Store Connect. Every write goes through `_write`, so a plan (dry run) shows exactly
what apply would change; only attributes that differ from what is already there are sent."""

from __future__ import annotations

import hashlib
from collections.abc import Callable
from urllib.parse import quote

from config import Metadata

APP_INFO_LOCALIZATION = {
    "name": "name",
    "subtitle": "subtitle",
    "privacy_policy_url": "privacyPolicyUrl",
    "privacy_choices_url": "privacyChoicesUrl",
}
VERSION_LOCALIZATION = {
    "description": "description",
    "keywords": "keywords",
    "promotional_text": "promotionalText",
    "support_url": "supportUrl",
    "marketing_url": "marketingUrl",
    "whats_new": "whatsNew",
}
REVIEW_DETAIL = {
    "contact_first_name": "contactFirstName",
    "contact_last_name": "contactLastName",
    "contact_phone": "contactPhone",
    "contact_email": "contactEmail",
    "demo_account_required": "demoAccountRequired",
    "demo_account_name": "demoAccountName",
    "demo_account_password": "demoAccountPassword",
    "notes": "notes",
}
BETA_LOCALIZATION = {
    "description": "description",
    "feedback_email": "feedbackEmail",
    "marketing_url": "marketingUrl",
    "privacy_policy_url": "privacyPolicyUrl",
}
LIVE_STATES = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE"}
SECRET_ATTRIBUTES = {"demoAccountPassword", "contactPhone", "contactEmail"}


class SyncError(Exception):
    pass


class Syncer:
    def __init__(self, client, metadata: Metadata, apply: bool, log: Callable[[str], None] = print):
        self.client = client
        self.meta = metadata
        self.apply = apply
        self.log = log
        self.changes = 0

    # MARK: plumbing

    def _write(self, method: str, path: str, body: dict | None, summary: str) -> dict:
        self.changes += 1
        self.log(("APPLY " if self.apply else "PLAN  ") + summary)
        if not self.apply:
            return {"data": {"id": f"planned-{self.changes}", "attributes": {}}}
        if method == "DELETE":
            return self.client.delete(path)
        return self.client.post(path, body) if method == "POST" else self.client.patch(path, body)

    @staticmethod
    def _wanted(fields: dict, mapping: dict) -> dict:
        return {api: fields[key] for key, api in mapping.items() if key in fields and fields[key] is not None}

    @staticmethod
    def _diff(current: dict, wanted: dict) -> dict:
        return {key: value for key, value in wanted.items() if current.get(key) != value}

    @staticmethod
    def _describe(attributes: dict) -> str:
        return ", ".join(
            f"{key}=***" if key in SECRET_ATTRIBUTES else f"{key}={str(value)[:40]!r}"
            for key, value in attributes.items()
        )

    def _upsert(self, kind: str, existing: dict | None, wanted: dict, create_body: dict | None, label: str):
        if existing is None:
            if not wanted:
                return None
            return self._write("POST", f"/v1/{kind}", create_body, f"create {label}: {self._describe(wanted)}")
        changed = self._diff(existing.get("attributes", {}), wanted)
        if changed:
            body = {"data": {"type": kind, "id": existing["id"], "attributes": changed}}
            self._write("PATCH", f"/v1/{kind}/{existing['id']}", body, f"update {label}: {self._describe(changed)}")
        return {"data": existing}

    # MARK: steps

    def run(self, screenshots: bool = False, build: str | None = None, submit: bool = False) -> int:
        app = self.find_app()
        self.sync_app(app)
        info = self.editable_app_info(app["id"])
        self.sync_categories(info)
        self.sync_app_info_localizations(info)
        self.sync_age_rating(info)
        version, first_release = self.ensure_version(app["id"])
        localizations = self.sync_version_localizations(version, first_release)
        self.sync_review_detail(version)
        self.sync_testflight(app["id"])
        if screenshots:
            self.sync_screenshots(localizations)
        if build:
            self.attach_build(app["id"], version, build)
        if submit:
            self.submit(app["id"], version)
        self.log(f"{self.changes} change(s) {'applied' if self.apply else 'planned'}")
        return self.changes

    def find_app(self) -> dict:
        apps = self.client.get(f"/v1/apps?filter[bundleId]={quote(self.meta.bundle_id)}").get("data", [])
        if not apps:
            raise SyncError(
                f"No app with bundle ID {self.meta.bundle_id} in App Store Connect. Create it there first "
                "(My Apps > + > New App); the API cannot create apps."
            )
        return apps[0]

    def sync_app(self, app: dict) -> None:
        wanted = {"contentRightsDeclaration": self.meta.content_rights} if self.meta.content_rights else {}
        self._upsert("apps", app, wanted, None, "app")

    def editable_app_info(self, app_id: str) -> dict:
        infos = self.client.get(f"/v1/apps/{app_id}/appInfos").get("data", [])
        for info in infos:
            attributes = info.get("attributes", {})
            if (attributes.get("state") or attributes.get("appStoreState")) not in LIVE_STATES:
                return info
        if not infos:
            raise SyncError("The app has no app info record")
        return infos[0]

    def sync_categories(self, info: dict) -> None:
        categories = self.meta.categories
        relationships = {}
        subcategories = categories.get("primary_subcategories") or []
        pairs = [
            ("primaryCategory", categories.get("primary")),
            ("primarySubcategoryOne", subcategories[0] if len(subcategories) > 0 else None),
            ("primarySubcategoryTwo", subcategories[1] if len(subcategories) > 1 else None),
            ("secondaryCategory", categories.get("secondary")),
        ]
        for name, value in pairs:
            if value:
                relationships[name] = {"data": {"type": "appCategories", "id": value}}
        if not relationships:
            return
        current = (
            self.client.get(
                f"/v1/appInfos/{info['id']}?include=primaryCategory,primarySubcategoryOne,primarySubcategoryTwo,"
                "secondaryCategory"
            )
            .get("data", {})
            .get("relationships", {})
        )
        changed = {
            name: rel
            for name, rel in relationships.items()
            if (current.get(name, {}).get("data") or {}).get("id") != rel["data"]["id"]
        }
        if changed:
            body = {"data": {"type": "appInfos", "id": info["id"], "relationships": changed}}
            summary = ", ".join(f"{name}={rel['data']['id']}" for name, rel in changed.items())
            self._write("PATCH", f"/v1/appInfos/{info['id']}", body, f"update categories: {summary}")

    def sync_app_info_localizations(self, info: dict) -> None:
        existing = {
            item["attributes"]["locale"]: item
            for item in self.client.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations").get("data", [])
        }
        for locale, fields in self.meta.localizations.items():
            wanted = self._wanted(fields, APP_INFO_LOCALIZATION)
            self._upsert(
                "appInfoLocalizations",
                existing.get(locale),
                wanted,
                {
                    "data": {
                        "type": "appInfoLocalizations",
                        "attributes": {"locale": locale, **wanted},
                        "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}},
                    }
                },
                f"app info [{locale}]",
            )

    def sync_age_rating(self, info: dict) -> None:
        if not self.meta.age_rating:
            return
        declaration = self.client.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration").get("data")
        if declaration is None:
            raise SyncError("The app info has no age rating declaration")
        self._upsert("ageRatingDeclarations", declaration, dict(self.meta.age_rating), None, "age rating")

    def ensure_version(self, app_id: str) -> tuple[dict, bool]:
        """Returns the editable version (creating it if needed) and whether this is the app's first release."""
        wanted_string = str(self.meta.version["version_string"])
        versions = self.client.get(f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=50").get("data", [])
        first_release = not any(v["attributes"].get("appStoreState") in LIVE_STATES for v in versions)
        attributes = {"versionString": wanted_string}
        for key, api in (("copyright", "copyright"), ("release_type", "releaseType")):
            if self.meta.version.get(key):
                attributes[api] = self.meta.version[key]
        editable = [
            v
            for v in versions
            if v["attributes"].get("appStoreState")
            in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")
        ]
        if editable:
            version = editable[0]
            self._upsert("appStoreVersions", version, attributes, None, f"version {wanted_string}")
            return version, first_release
        created = self._write(
            "POST",
            "/v1/appStoreVersions",
            {
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {"platform": "IOS", **attributes},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
            f"create version {wanted_string}",
        )
        return created["data"], first_release

    def sync_version_localizations(self, version: dict, first_release: bool) -> dict[str, dict]:
        existing = {}
        if not version["id"].startswith("planned-"):
            existing = {
                item["attributes"]["locale"]: item
                for item in self.client.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations").get(
                    "data", []
                )
            }
        result = {}
        for locale, fields in self.meta.localizations.items():
            wanted = self._wanted(fields, VERSION_LOCALIZATION)
            if first_release:
                # "What's New" cannot be set on an app's first version.
                wanted.pop("whatsNew", None)
            response = self._upsert(
                "appStoreVersionLocalizations",
                existing.get(locale),
                wanted,
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "attributes": {"locale": locale, **wanted},
                        "relationships": {
                            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}
                        },
                    }
                },
                f"version text [{locale}]",
            )
            if response:
                result[locale] = response["data"]
        return result

    def sync_review_detail(self, version: dict) -> None:
        wanted = self._wanted(self.meta.review, REVIEW_DETAIL)
        if not wanted:
            return
        current = None
        if not version["id"].startswith("planned-"):
            current = self.client.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
        self._upsert(
            "appStoreReviewDetails",
            current,
            wanted,
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": wanted,
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}},
                }
            },
            "review information",
        )

    def sync_testflight(self, app_id: str) -> None:
        beta = self.meta.testflight
        if not beta:
            return
        existing = {
            item["attributes"]["locale"]: item
            for item in self.client.get(f"/v1/apps/{app_id}/betaAppLocalizations").get("data", [])
        }
        for locale, fields in (beta.get("localizations") or {}).items():
            wanted = self._wanted(fields, BETA_LOCALIZATION)
            self._upsert(
                "betaAppLocalizations",
                existing.get(locale),
                wanted,
                {
                    "data": {
                        "type": "betaAppLocalizations",
                        "attributes": {"locale": locale, **wanted},
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                    }
                },
                f"TestFlight text [{locale}]",
            )
        review = self._wanted(beta.get("review") or {}, REVIEW_DETAIL)
        if review:
            current = self.client.get(f"/v1/apps/{app_id}/betaAppReviewDetail").get("data")
            if current is not None:
                self._upsert("betaAppReviewDetails", current, review, None, "TestFlight review information")

    def sync_screenshots(self, localizations: dict[str, dict]) -> None:
        """Replaces each configured set with the local files, in file-name order."""
        for locale, sets in self.meta.screenshots.items():
            localization = localizations.get(locale)
            if localization is None:
                raise SyncError(f"screenshots.{locale}: no version localization for that locale")
            existing_sets = {}
            if not localization["id"].startswith("planned-"):
                existing_sets = {
                    item["attributes"]["screenshotDisplayType"]: item
                    for item in self.client.get(
                        f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets"
                    ).get("data", [])
                }
            for display_type, files in sets.items():
                if not files:
                    continue
                screenshot_set = existing_sets.get(display_type)
                if screenshot_set is None:
                    screenshot_set = self._write(
                        "POST",
                        "/v1/appScreenshotSets",
                        {
                            "data": {
                                "type": "appScreenshotSets",
                                "attributes": {"screenshotDisplayType": display_type},
                                "relationships": {
                                    "appStoreVersionLocalization": {
                                        "data": {"type": "appStoreVersionLocalizations", "id": localization["id"]}
                                    }
                                },
                            }
                        },
                        f"create screenshot set {display_type} [{locale}]",
                    )["data"]
                else:
                    for old in self.client.get(f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots").get(
                        "data", []
                    ):
                        self._write(
                            "DELETE",
                            f"/v1/appScreenshots/{old['id']}",
                            None,
                            f"delete old screenshot {old['attributes'].get('fileName')} [{locale}]",
                        )
                for file in files:
                    self._upload_screenshot(screenshot_set["id"], file, locale)

    def _upload_screenshot(self, set_id: str, file, locale: str) -> None:
        data = file.read_bytes()
        reservation = self._write(
            "POST",
            "/v1/appScreenshots",
            {
                "data": {
                    "type": "appScreenshots",
                    "attributes": {"fileName": file.name, "fileSize": len(data)},
                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
                }
            },
            f"upload screenshot {file.name} [{locale}]",
        )
        if not self.apply:
            return
        screenshot = reservation["data"]
        for operation in screenshot["attributes"].get("uploadOperations") or []:
            start, length = operation["offset"], operation["length"]
            self.client.upload(operation, data[start : start + length])
        self.client.patch(
            f"/v1/appScreenshots/{screenshot['id']}",
            {
                "data": {
                    "type": "appScreenshots",
                    "id": screenshot["id"],
                    "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
                }
            },
        )

    def attach_build(self, app_id: str, version: dict, build_number: str) -> None:
        builds = self.client.get(
            f"/v1/builds?filter[app]={app_id}&filter[version]={quote(build_number)}"
            f"&filter[preReleaseVersion.version]={quote(str(self.meta.version['version_string']))}"
        ).get("data", [])
        if not builds:
            raise SyncError(
                f"Build {build_number} of version {self.meta.version['version_string']} was not found "
                "(is it uploaded and processed?)"
            )
        self._write(
            "PATCH",
            f"/v1/appStoreVersions/{version['id']}/relationships/build",
            {"data": {"type": "builds", "id": builds[0]["id"]}},
            f"select build {build_number}",
        )

    def submit(self, app_id: str, version: dict) -> None:
        submission = self._write(
            "POST",
            "/v1/reviewSubmissions",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
            "create review submission",
        )["data"]
        self._write(
            "POST",
            "/v1/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}},
                    },
                }
            },
            "add version to the submission",
        )
        self._write(
            "PATCH",
            f"/v1/reviewSubmissions/{submission['id']}",
            {"data": {"type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}},
            "SUBMIT FOR REVIEW",
        )
