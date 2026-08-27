#!/usr/bin/env bash
# Upload iOS IPA to Firebase App Distribution.
# Safe to run from any directory (uses script location).
# Usage: distribute-ios.sh ["Release notes"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
RELEASE_NOTES="${1:-Family Calendar iOS build}"
FIREBASE_TESTERS_GROUP=family-ios

# shellcheck source=_env.sh
source "$SCRIPT_DIR/_env.sh"
# shellcheck source=_firebase.sh
source "$SCRIPT_DIR/_firebase.sh"

echo
echo "========================================"
echo " Family Calendar - Firebase Distribute"
echo " iOS (mobile)"
echo "========================================"
echo

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy .env-sample to .env and set IOS_APP_ID."
  exit 1
fi

load_firebase_env

if [[ -z "$IOS_APP_ID" ]]; then
  echo "ERROR: IOS_APP_ID is missing in $ENV_FILE"
  echo "Add: IOS_APP_ID=1:YOUR_PROJECT:ios:YOUR_APP_HASH"
  exit 1
fi

IPA_PATH="$(find "$APP_DIR/build/ios/ipa" -name '*.ipa' -type f 2>/dev/null | head -1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "ERROR: No IPA found under $APP_DIR/build/ios/ipa/"
  echo "Run build-ios.sh first."
  exit 1
fi

echo "Env:     $ENV_FILE"
echo "App ID:  $IOS_APP_ID"
echo "Group:   $FIREBASE_TESTERS_GROUP"
echo "IPA:     $IPA_PATH"
echo "Notes:   $RELEASE_NOTES"
echo

if ! firebase_cmd appdistribution:distribute "$IPA_PATH" \
  --app "$IOS_APP_ID" \
  --groups "$FIREBASE_TESTERS_GROUP" \
  --release-notes "$RELEASE_NOTES"; then
  echo
  echo "ERROR: Firebase upload failed."
  exit 1
fi

echo
echo "Done. Testers in group '$FIREBASE_TESTERS_GROUP' should get an email."
