"""App Store metadata as code.

  python3 scripts/appstore/asc.py validate            # offline checks (PRs; TODOs/secrets only warn)
  python3 scripts/appstore/asc.py plan [--screenshots]  # read App Store Connect, print what would change
  python3 scripts/appstore/asc.py apply [--screenshots] [--build N] [--submit]

plan/apply need ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 in the environment.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from config import ConfigError, load

ROOT = Path(__file__).resolve().parents[2]
METADATA = ROOT / "appstore" / "metadata.yml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["validate", "plan", "apply"])
    parser.add_argument("--metadata", type=Path, default=METADATA)
    parser.add_argument("--screenshots", action="store_true", help="replace screenshots with the local files")
    parser.add_argument("--build", help="build number to attach to the version")
    parser.add_argument("--submit", action="store_true", help="submit the version for App Review (apply only)")
    args = parser.parse_args(argv)

    strict = args.command != "validate"
    try:
        metadata = load(args.metadata, ROOT, strict=strict)
    except ConfigError as error:
        print("metadata.yml has problems:", file=sys.stderr)
        for problem in error.problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    for warning in metadata.warnings:
        print(f"warning: {warning}")
    if args.command == "validate":
        print(f"metadata.yml OK ({', '.join(metadata.localizations)})")
        return 0
    if args.submit and args.command != "apply":
        parser.error("--submit only works with apply")

    from asc_client import Client
    from sync import Syncer, SyncError

    missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8") if not os.environ.get(name)]
    if missing:
        print(f"Missing environment variables: {', '.join(missing)}", file=sys.stderr)
        return 1
    client = Client(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_P8"])
    try:
        Syncer(client, metadata, apply=args.command == "apply").run(
            screenshots=args.screenshots, build=args.build, submit=args.submit
        )
    except SyncError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
