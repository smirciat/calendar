#!/usr/bin/env bash
# Build Family Calendar kiosk APK (Linux dev host).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-kiosk-release.apk"
EXPECTED_PACKAGE="com.smircich.familycalendar.kiosk"

# shellcheck source=_android-env.sh
source "$SCRIPT_DIR/_android-env.sh"

echo
echo "========================================"
echo " Family Calendar - Build KIOSK APK"
echo " Package: $EXPECTED_PACKAGE"
echo "========================================"
echo

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not in PATH."
  exit 1
fi
if [[ ! -d "$ANDROID_HOME/platforms" ]]; then
  echo "ERROR: Android SDK not found at $ANDROID_HOME"
  echo "Run: app/scripts/setup-dev-android.sh"
  exit 1
fi

android_ensure_release_signing "$SCRIPT_DIR"

android_acquire_build_lock
pushd "$APP_DIR" >/dev/null
android_stop_gradle_daemons "$APP_DIR"
flutter pub get
android_run_flutter_build "kiosk release APK" build apk --flavor kiosk -t lib/main_kiosk.dart --release
popd >/dev/null

if [[ ! -f "$APK_PATH" ]]; then
  echo "ERROR: APK not found at $APK_PATH"
  exit 1
fi

if command -v aapt >/dev/null 2>&1; then
  actual="$(aapt dump badging "$APK_PATH" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
  if [[ "$actual" != "$EXPECTED_PACKAGE" ]]; then
    echo "ERROR: Wrong package: $actual (expected $EXPECTED_PACKAGE)"
    exit 1
  fi
  echo "Verified package: $actual"
fi

android_verify_apk_signing "$APK_PATH" "$SCRIPT_DIR/../android/key.properties"

echo
echo "OK: $APK_PATH"
echo "Next: app/scripts/distribute-kiosk.sh"
