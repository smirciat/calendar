#!/usr/bin/env bash
# Build iOS IPA and upload to Firebase App Distribution.
# Safe to run from any directory (uses script location).
# Usage: ios-release.sh ["Release notes"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_NOTES="${1:-Family Calendar iOS build}"

"$SCRIPT_DIR/build-ios.sh"
"$SCRIPT_DIR/distribute-ios.sh" "$RELEASE_NOTES"
