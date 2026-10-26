"""Copies UI-test attachments named appstore-NN-* (from `xcresulttool export attachments`) into the folder
metadata.yml points at, named NN-*.png so App Store order follows the test.

  python3 scripts/appstore/collect_screenshots.py build/attachments appstore/screenshots/ja/iphone69
"""

import json
import shutil
import sys
from pathlib import Path


def collect(export_dir: Path, target: Path) -> list[Path]:
    manifest = json.loads((export_dir / "manifest.json").read_text())
    target.mkdir(parents=True, exist_ok=True)
    for old in target.glob("*.png"):
        old.unlink()
    copied = []
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.startswith("appstore-"):
                continue
            # "appstore-01-island_0_<uuid>.png" -> "01-island.png"
            short = name.removeprefix("appstore-").split("_")[0] + ".png"
            destination = target / short
            shutil.copyfile(export_dir / attachment["exportedFileName"], destination)
            copied.append(destination)
    return sorted(copied)


if __name__ == "__main__":
    files = collect(Path(sys.argv[1]), Path(sys.argv[2]))
    print("\n".join(str(path) for path in files) or "no appstore-* attachments found")
    sys.exit(0 if files else 1)
