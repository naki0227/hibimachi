"""Docs-only quality gate. Not a substitute for Swift CI or secret scanning."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md", "AGENTS.md", "CLAUDE-HANDOFF.md", "TODO.md",
    "docs/PRD.md", "docs/GAME-DESIGN.md", "docs/VISUAL-DIRECTION.md",
    "docs/ARCHITECTURE.md", "docs/DATA-MODEL.md", "docs/QUALITY-CI.md",
    "docs/ROADMAP.md", "docs/PRIVACY-AI.md", "docs/adr/0001-ios-native-spritekit.md",
    "reports/2026-10-25-planning.md",
]


def validate(root=ROOT):
    errors = []
    for path in REQUIRED:
        if not (root / path).is_file():
            errors.append(f"Missing required file: {path}")
    for path in root.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(root)
        if "\t" in text:
            errors.append(f"Tab in {relative}")
        for i, line in enumerate(text.splitlines(), 1):
            if line.rstrip() != line:
                errors.append(f"Trailing whitespace in {relative}:{i}")
        # A simple local markdown link check (ignores http/anchors).
        for dest in re.findall(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", text):
            dest = dest.split("#")[0]
            if not dest or "://" in dest or dest.startswith("mailto:"):
                continue
            if not (path.parent / dest).exists():
                errors.append(f"Broken link in {relative}: {dest}")
        # Broad accidental credential pattern check; not a comprehensive secrets scan.
        if re.search(r"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----", text):
            errors.append(f"Private key marker in {relative}")
    return errors


if __name__ == "__main__":
    failures = validate()
    for failure in failures:
        print(f"ERROR: {failure}", file=sys.stderr)
    if failures:
        raise SystemExit(1)
    print(f"Documentation validation passed ({len(REQUIRED)} required files).")
