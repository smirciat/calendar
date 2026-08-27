#!/usr/bin/env bash
# Configure stable release signing for Android mobile + kiosk APKs.
#
# Import the Windows debug keystore (same key that signed kiosk builds 15-17):
#   app/scripts/upload-android-keystore.bat   (from Windows)
#   app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore
#
# Usage:
#   app/scripts/setup-android-signing.sh [--import /path/to.keystore] [--new]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ANDROID="$(cd "$SCRIPT_DIR/../android" && pwd)"
KEY_PROPS="$APP_ANDROID/key.properties"
CONFIG_DIR="${HOME}/.config/family-calendar"
DEFAULT_JKS="$CONFIG_DIR/android-release.jks"
IMPORT_PATH=""
FORCE_NEW=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --import)
      IMPORT_PATH="$2"
      shift 2
      ;;
    --new)
      FORCE_NEW=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

mkdir -p "$CONFIG_DIR"

# Prefer existing imported keys (legacy kiosk-signing.jks name included).
if [[ -z "$IMPORT_PATH" && ! -f "$DEFAULT_JKS" ]]; then
  for legacy in "$CONFIG_DIR/kiosk-signing.jks" "$CONFIG_DIR/windows-debug.keystore"; do
    if [[ -f "$legacy" ]]; then
      cp "$legacy" "$DEFAULT_JKS"
      echo "Using existing keystore: $legacy"
      break
    fi
  done
fi

if [[ -n "$IMPORT_PATH" ]]; then
  if [[ ! -f "$IMPORT_PATH" ]]; then
    echo "ERROR: import file not found: $IMPORT_PATH"
    exit 1
  fi
  cp "$IMPORT_PATH" "$DEFAULT_JKS"
  echo "Imported keystore → $DEFAULT_JKS"
elif [[ "$FORCE_NEW" == true || ! -f "$DEFAULT_JKS" ]]; then
  if [[ -f "$DEFAULT_JKS" && "$FORCE_NEW" != true ]]; then
    echo "Using existing keystore: $DEFAULT_JKS"
  else
    echo "Generating new Android release key at $DEFAULT_JKS"
    echo "WARNING: phones/tablets need reinstall if signing key changes."
    keytool -genkeypair -v \
      -keystore "$DEFAULT_JKS" \
      -storepass "${ANDROID_STORE_PASSWORD:-familycalendar}" \
      -keypass "${ANDROID_KEY_PASSWORD:-familycalendar}" \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -alias release \
      -dname "CN=Family Calendar, O=Smircich, C=US"
  fi
fi

if [[ ! -f "$DEFAULT_JKS" ]]; then
  echo "ERROR: no keystore at $DEFAULT_JKS — use --import or --new"
  exit 1
fi

ALIAS="release"
STORE_PASS="${ANDROID_STORE_PASSWORD:-familycalendar}"
KEY_PASS="${ANDROID_KEY_PASSWORD:-familycalendar}"
if keytool -list -keystore "$DEFAULT_JKS" -storepass android >/dev/null 2>&1; then
  ALIAS="androiddebugkey"
  STORE_PASS="android"
  KEY_PASS="android"
  echo "Detected Android debug keystore (alias androiddebugkey)"
fi

cat >"$KEY_PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=$DEFAULT_JKS
EOF

echo
echo "Wrote $KEY_PROPS"
keytool -list -v -keystore "$DEFAULT_JKS" -storepass "$STORE_PASS" 2>/dev/null | grep -E "Alias name:|SHA256:" | head -4
echo
echo "Rebuild:"
echo "  app/scripts/build-mobile.sh && app/scripts/distribute-mobile.sh"
echo "  app/scripts/build-kiosk.sh && app/scripts/distribute-kiosk.sh"
echo
echo "iOS uses Apple code signing in Xcode — not this keystore. Bump pubspec and build on Mac."
