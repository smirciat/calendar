#!/usr/bin/env bash
# Upload mobile APK to Firebase App Distribution.
# Safe to run from any directory (uses script location).
# Usage: distribute-mobile.sh ["Release notes"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-mobile-release.apk"
EXPECTED_PACKAGE="com.smircich.familycalendar"
FIREBASE_TESTERS_GROUP=family-android
RELEASE_NOTES="${1:-Family Calendar mobile build}"

# shellcheck source=_env.sh
source "$SCRIPT_DIR/_env.sh"
# shellcheck source=_firebase.sh
source "$SCRIPT_DIR/_firebase.sh"

echo
echo "========================================"
echo " Family Calendar - Firebase Distribute"
echo " MOBILE ONLY: $EXPECTED_PACKAGE"
echo "========================================"
echo

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy .env-sample to .env and set ANDROID_APP_ID."
  exit 1
fi

load_firebase_env

if [[ -z "$ANDROID_APP_ID" ]]; then
  echo "ERROR: ANDROID_APP_ID is missing in $ENV_FILE"
  exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "ERROR: Mobile APK not found at $APK_PATH"
  echo "Run: flutter build apk --flavor mobile -t lib/main_mobile.dart --release"
  exit 1
fi

if command -v aapt >/dev/null 2>&1; then
  ACTUAL="$(aapt dump badging "$APK_PATH" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
  if [[ "$ACTUAL" != "$EXPECTED_PACKAGE" ]]; then
    echo "ERROR: Wrong package in APK: $ACTUAL (expected $EXPECTED_PACKAGE)"
    exit 1
  fi
  echo "Verified package: $ACTUAL"
fi

echo "App ID:  $ANDROID_APP_ID"
echo "Group:   $FIREBASE_TESTERS_GROUP"
echo "APK:     $APK_PATH"
echo "Notes:   $RELEASE_NOTES"
echo

if ! firebase_cmd appdistribution:distribute "$APK_PATH" \
  --app "$ANDROID_APP_ID" \
  --groups "$FIREBASE_TESTERS_GROUP" \
  --release-notes "$RELEASE_NOTES"; then
  echo
  echo "ERROR: Firebase upload failed."
  exit 1
fi

echo
echo "Done. Testers in group '$FIREBASE_TESTERS_GROUP' should get an email."
