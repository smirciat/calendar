#!/usr/bin/env bash
# Upload kiosk APK to bering-dev for OTA updates.
# Safe to run from app/scripts/ (uses script location).
# Requires: scp in PATH, SSH access to deploy host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-kiosk-release.apk"
EXPECTED_PACKAGE="com.smircich.familycalendar.kiosk"

# shellcheck source=_env.sh
source "$SCRIPT_DIR/_env.sh"
load_kiosk_deploy_env

echo
echo "========================================"
echo " Family Calendar - Upload Kiosk APK"
echo " Package: $EXPECTED_PACKAGE"
echo " Host:    $KIOSK_DEPLOY_HOST"
echo " Path:    $KIOSK_DEPLOY_PATH"
echo "========================================"
echo

if [[ ! -f "$APK_PATH" ]]; then
  echo "ERROR: APK not found at $APK_PATH"
  echo "Run build-kiosk.bat or build-kiosk.sh first."
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

echo "Uploading $APK_PATH ..."
scp "$APK_PATH" "${KIOSK_DEPLOY_HOST}:${KIOSK_DEPLOY_PATH}"

echo
echo "OK: uploaded to ${KIOSK_DEPLOY_HOST}:${KIOSK_DEPLOY_PATH}"
echo "Next on server:"
echo "  1. Set KIOSK_LATEST_BUILD (and notes) in ~/calendar/.env"
echo "  2. pm2 restart family-calendar"
