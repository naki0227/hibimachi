"""Loads and validates appstore/metadata.yml.

The YAML mirrors App Store Connect API attribute names where Apple defines them, so a new or renamed
field can be added in the YAML without code changes (age rating answers are passed through as-is).
Values written as ${NAME} are read from the environment, so personal contact details stay in CI secrets
and out of the repository.
"""

from __future__ import annotations

import os
import re
import struct
from dataclasses import dataclass, field
from pathlib import Path

import yaml

ENV_PATTERN = re.compile(r"^\$\{([A-Z0-9_]+)\}$")
TODO_PATTERN = re.compile(r"^\s*TODO\b")

# App Store limits (characters).
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
    "whats_new": 4000,
}
URL_FIELDS = ("privacy_policy_url", "support_url", "marketing_url", "privacy_choices_url")

# Pixel sizes App Store Connect accepts per display type (portrait and landscape).
SCREENSHOT_SIZES = {
    "APP_IPHONE_67": {(1290, 2796), (1320, 2868), (2796, 1290), (2868, 1320)},
    "APP_IPHONE_65": {(1242, 2688), (1284, 2778), (2688, 1242), (2778, 1284)},
    "APP_IPHONE_61": {(1179, 2556), (1206, 2622), (2556, 1179), (2622, 1206)},
}
RELEASE_TYPES = {"MANUAL", "AFTER_APPROVAL", "SCHEDULED"}


class ConfigError(Exception):
    """All problems found, one per line."""

    def __init__(self, problems: list[str]):
        super().__init__("\n".join(problems))
        self.problems = problems


@dataclass
class Metadata:
    bundle_id: str
    primary_locale: str
    content_rights: str | None
    categories: dict
    version: dict
    localizations: dict[str, dict]
    age_rating: dict
    review: dict
    screenshots: dict[str, dict[str, list[Path]]] = field(default_factory=dict)
    testflight: dict = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)


def png_size(path: Path) -> tuple[int, int] | None:
    """Width/height from a PNG header, without an image library."""
    with path.open("rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def _resolve(value, env, problems, where, strict):
    """Replaces ${NAME} with the environment value; reports TODO placeholders."""
    if isinstance(value, dict):
        return {key: _resolve(item, env, problems, f"{where}.{key}", strict) for key, item in value.items()}
    if isinstance(value, list):
        return [_resolve(item, env, problems, f"{where}[{index}]", strict) for index, item in enumerate(value)]
    if not isinstance(value, str):
        return value
    match = ENV_PATTERN.match(value.strip())
    if match:
        name = match.group(1)
        if name in env and env[name].strip():
            return env[name].strip()
        if strict:
            problems.append(f"{where}: environment variable {name} is not set")
        return None
    if TODO_PATTERN.match(value) and strict:
        problems.append(f"{where}: still a TODO placeholder ({value.strip()})")
    return value


def load(path: Path, repo_root: Path, env=None, strict: bool = True) -> Metadata:
    """strict=True (apply/plan) turns TODOs and missing secrets into errors; False (validate in PRs) only warns."""
    env = os.environ if env is None else env
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    problems: list[str] = []
    data = _resolve(raw, env, problems, "metadata", strict)

    app = data.get("app") or {}
    version = data.get("version") or {}
    localizations = data.get("localizations") or {}
    bundle_id = app.get("bundle_id")
    primary_locale = app.get("primary_locale")
    if not bundle_id:
        problems.append("app.bundle_id is required")
    if not primary_locale:
        problems.append("app.primary_locale is required")
    elif primary_locale not in localizations:
        problems.append(f"localizations.{primary_locale} is required (the primary locale)")

    for locale, fields in localizations.items():
        for key, limit in LIMITS.items():
            text = fields.get(key)
            if isinstance(text, str) and len(text.strip()) > limit:
                problems.append(f"localizations.{locale}.{key}: {len(text.strip())} characters (max {limit})")
        for key in ("name", "description", "keywords", "support_url", "privacy_policy_url"):
            if not fields.get(key):
                problems.append(f"localizations.{locale}.{key} is required")
        for key in URL_FIELDS:
            url = fields.get(key)
            if url and not TODO_PATTERN.match(url) and not str(url).startswith("https://"):
                problems.append(f"localizations.{locale}.{key}: must be an https:// URL")

    version_string = str(version.get("version_string", ""))
    if not re.fullmatch(r"\d+\.\d+(\.\d+)?", version_string):
        problems.append("version.version_string must look like 1.0 or 1.0.0")
    else:
        marketing = _marketing_version(repo_root)
        if marketing and marketing != version_string:
            problems.append(
                f"version.version_string {version_string} differs from the app's MARKETING_VERSION {marketing}"
            )
    if version.get("release_type", "MANUAL") not in RELEASE_TYPES:
        problems.append(f"version.release_type must be one of {sorted(RELEASE_TYPES)}")

    age_rating = data.get("age_rating") or {}
    for key, value in age_rating.items():
        if not isinstance(value, (bool, str)) and value is not None:
            problems.append(f"age_rating.{key}: use a string such as NONE or true/false")

    screenshots: dict[str, dict[str, list[Path]]] = {}
    warnings: list[str] = []
    for locale, sets in (data.get("screenshots") or {}).items():
        for display_type, folder in (sets or {}).items():
            if display_type not in SCREENSHOT_SIZES:
                problems.append(f"screenshots.{locale}.{display_type}: unknown display type")
                continue
            directory = repo_root / folder
            files = sorted(p for p in directory.glob("*.png")) if directory.is_dir() else []
            if not files:
                warnings.append(f"screenshots.{locale}.{display_type}: no PNG files in {folder} (generate them first)")
            if len(files) > 10:
                problems.append(f"screenshots.{locale}.{display_type}: {len(files)} files (max 10)")
            for file in files:
                size = png_size(file)
                if size not in SCREENSHOT_SIZES[display_type]:
                    problems.append(f"{file.relative_to(repo_root)}: size {size} is not accepted for {display_type}")
            screenshots.setdefault(locale, {})[display_type] = files

    if problems:
        raise ConfigError(problems)
    return Metadata(
        bundle_id=bundle_id,
        primary_locale=primary_locale,
        content_rights=app.get("content_rights"),
        categories=app.get("categories") or {},
        version=version,
        localizations=localizations,
        age_rating=age_rating,
        review=data.get("review") or {},
        screenshots=screenshots,
        testflight=data.get("testflight") or {},
        warnings=warnings,
    )


def _marketing_version(repo_root: Path) -> str | None:
    project = repo_root / "Hibimachi.xcodeproj" / "project.pbxproj"
    if not project.exists():
        return None
    versions = set(re.findall(r"MARKETING_VERSION = ([0-9.]+);", project.read_text(encoding="utf-8")))
    return versions.pop() if len(versions) == 1 else None
