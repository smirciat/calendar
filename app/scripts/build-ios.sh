#!/usr/bin/env bash
# Build Family Calendar iOS IPA for Firebase App Distribution (Ad Hoc).
# Safe to run from any directory (uses script location).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo
echo "========================================"
echo " Family Calendar - Build iOS IPA"
echo " Bundle:  com.smircich.familycalendar"
echo " Entry:   lib/main_mobile.dart"
echo " Output:  app/build/ios/ipa/*.ipa"
echo " Upload:  distribute-ios.sh"
echo "========================================"
echo

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not found. Add Flutter to PATH."
  exit 1
fi

cd "$APP_DIR"
flutter pub get
flutter precache --ios

if [[ ! -f ios/Podfile ]]; then
  echo "ERROR: ios/Podfile missing. Pull latest calendar repo or run flutter create . --platforms=ios in app/."
  exit 1
fi

if [[ -d ios ]] && command -v pod >/dev/null 2>&1; then
  echo "Running pod install..."
  (cd ios && pod install)
elif [[ -d ios/Pods ]]; then
  echo "Note: CocoaPods not in PATH; using existing ios/Pods."
else
  echo "WARNING: pod not found. If build fails, run: sudo gem install cocoapods"
fi

echo "Building release IPA (Ad Hoc)..."
flutter build ipa --release \
  -t lib/main_mobile.dart \
  --export-method ad-hoc

IPA_PATH="$(find "$APP_DIR/build/ios/ipa" -name '*.ipa' -type f 2>/dev/null | head -1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "ERROR: IPA not found under build/ios/ipa/"
  echo "Try Xcode: Product → Archive → Distribute App → Ad Hoc"
  exit 1
fi

echo
echo "OK: $IPA_PATH"
echo "Next: $SCRIPT_DIR/distribute-ios.sh"
