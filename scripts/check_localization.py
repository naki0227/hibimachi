"""Checks that every Japanese UI string in the app and widget is localizable and translated.

Japanese is the source language, so a Japanese literal is the lookup key. A literal is only looked up when it
sits where SwiftUI takes a LocalizedStringKey (Text, Label, Button, ...) or inside String(localized:);
anywhere else it would show Japanese to every player. This script fails when a literal is somewhere else, or
when its key has no English translation in Shared/Localizable.xcstrings.

  python3 scripts/check_localization.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ["Hibimachi", "HibimachiWidget", "Shared"]
CATALOG = ROOT / "Shared" / "Localizable.xcstrings"
TARGET_LANGUAGE = "en"

JAPANESE = re.compile(r"[぀-ヿ一-鿿]")
# A string literal, allowing one level of \( ... ) interpolation (nested parentheses inside it are fine).
LITERAL = re.compile(r'"((?:[^"\\\n]|\\\((?:[^()]|\([^()]*\))*\)|\\.)*)"')
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
FORMAT_SPECIFIER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f)")

# Text immediately before a literal that makes it a LocalizedStringKey / LocalizedStringResource.
LOCALIZED_CONTEXTS = re.compile(
    r"(?:String\(localized:|LocalizedStringKey\(|LocalizedStringResource\(|"
    r"\bText\(|\bLabel\(|\bButton\(|\bToggle\(|"
    r"\.accessibilityLabel\(|\.accessibilityHint\(|\.accessibilityValue\(|"
    r"\.configurationDisplayName\(|\.description\(|"
    r"GamePanel\(title:|GameTextField\(placeholder:|\btitle:|\bmessage:|\blabel:|"
    r"@Parameter\(title:|LocalizedStringResource \{|"
    r"\brow\(|\baction\(|\barrow\(\"[^\"]*\",)\s*$"
)


def placeholder_key(text: str) -> str:
    """Interpolations and format specifiers both become "{}" so source and catalog keys compare."""
    return FORMAT_SPECIFIER.sub("{}", INTERPOLATION.sub("{}", text))


def unescape(literal: str) -> str:
    """The text a Swift literal stands for, as it appears in catalog keys."""
    return literal.replace("\\n", "\n").replace('\\"', '"')


def strip_comment(line: str) -> str:
    stripped = line.lstrip()
    if stripped.startswith("//"):
        return ""
    return line


def scan(root: Path = ROOT, sources: list[str] = SOURCES) -> tuple[dict[str, list[str]], list[str]]:
    """Returns (normalized key -> places used, problems) for every Japanese literal under `sources`."""
    keys: dict[str, list[str]] = {}
    problems: list[str] = []
    for folder in sources:
        for path in sorted((root / folder).rglob("*.swift")):
            for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                line = strip_comment(raw)
                for match in LITERAL.finditer(line):
                    body = match.group(1)
                    if not JAPANESE.search(body):
                        continue
                    place = f"{path.relative_to(root)}:{number}"
                    before = line[: match.start()]
                    # A ternary inside a localized call keeps String(localized:) explicit on both sides.
                    if not LOCALIZED_CONTEXTS.search(before):
                        problems.append(f"{place}: not localizable here: \"{body}\"")
                    keys.setdefault(placeholder_key(unescape(body)), []).append(place)
    return keys, problems


def translations(catalog: Path = CATALOG, language: str = TARGET_LANGUAGE) -> dict[str, str]:
    """Normalized key -> translated value for every key that has a translated (non-empty) unit."""
    data = json.loads(catalog.read_text(encoding="utf-8"))
    result = {}
    for key, entry in data.get("strings", {}).items():
        unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
        if unit.get("state") == "translated" and unit.get("value"):
            result[placeholder_key(key)] = unit["value"]
    return result


def check(root: Path = ROOT, catalog: Path = CATALOG) -> list[str]:
    keys, problems = scan(root)
    translated = translations(catalog)
    for key, places in sorted(keys.items()):
        if key not in translated:
            problems.append(f"{places[0]}: no {TARGET_LANGUAGE} translation for \"{key}\"")
        elif placeholder_key(translated[key]).count("{}") != key.count("{}"):
            problems.append(f"{places[0]}: placeholder count differs in translation of \"{key}\"")
    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        print(f"{len(problems)} localization problem(s)", file=sys.stderr)
        return 1
    print("localization: every Japanese string is localizable and translated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
