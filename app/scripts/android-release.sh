#!/usr/bin/env bash
# Build mobile + kiosk APKs, upload mobile to Firebase, upload kiosk for OTA.
# Usage: android-release.sh ["Release notes"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
RELEASE_NOTES="${1:-Family Calendar Android build}"

"$SCRIPT_DIR/build-mobile.sh"
"$SCRIPT_DIR/distribute-mobile.sh" "$RELEASE_NOTES"
"$SCRIPT_DIR/build-kiosk.sh"
"$SCRIPT_DIR/distribute-kiosk.sh"

build="$(grep '^version:' "$REPO_ROOT/app/pubspec.yaml" | sed -n 's/.*+\([0-9]*\)/\1/p')"
echo
echo "Kiosk OTA: update $ENV_FILE then restart PM2:"
echo "  KIOSK_LATEST_BUILD=$build"
echo "  KIOSK_RELEASE_NOTES=$RELEASE_NOTES"
echo "  pm2 restart family-calendar"
