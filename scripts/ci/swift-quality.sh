#!/usr/bin/env bash
# Format / lint gate for all Swift sources. CI runs this in the pinned swift container
# (see .github/workflows/swift-ci.yml) so results do not depend on the local Xcode's swift-format.
#   scripts/ci/swift-quality.sh format-check | lint | format
set -euo pipefail
cd "$(dirname "$0")/../.."

SWIFT_FORMAT=(swift format)
if ! swift format --version >/dev/null 2>&1; then
    SWIFT_FORMAT=(xcrun swift-format)
fi
PATHS=(Hibimachi HibimachiWidget Shared HibimachiTests HibimachiUITests HibimachiCore/Package.swift HibimachiCore/Sources HibimachiCore/Tests)

case "${1:-}" in
    format)
        "${SWIFT_FORMAT[@]}" format --in-place --recursive --parallel "${PATHS[@]}"
        ;;
    format-check)
        # swift-format has no check mode; format a scratch copy and diff it against the tree.
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        tar cf - .swift-format "${PATHS[@]}" | (cd "$tmp" && tar xf -)
        (cd "$tmp" && "${SWIFT_FORMAT[@]}" format --in-place --recursive --parallel "${PATHS[@]}")
        status=0
        for p in "${PATHS[@]}"; do
            diff -ru "$p" "$tmp/$p" || status=1
        done
        if [ "$status" -ne 0 ]; then
            echo "Swift sources are not formatted. Run: scripts/ci/swift-quality.sh format" >&2
        fi
        exit "$status"
        ;;
    lint)
        "${SWIFT_FORMAT[@]}" lint --strict --recursive --parallel "${PATHS[@]}"
        ;;
    *)
        echo "usage: $0 format|format-check|lint" >&2
        exit 2
        ;;
esac
