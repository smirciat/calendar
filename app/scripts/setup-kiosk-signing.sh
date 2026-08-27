#!/usr/bin/env bash
# Configure a stable signing key for kiosk release APKs (required for OTA updates).
#
# Default: import Linux debug keystore copy, or generate a dedicated key.
# To match a tablet already on build 17 from Windows, copy that PC's debug keystore first:
#   scp "%USERPROFILE%\\.android\\debug.keystore" bering-dev:~/.config/family-calendar/windows-debug.keystore
#   app/scripts/setup-kiosk-signing.sh --import ~/.config/family-calendar/windows-debug.keystore
#
# Usage:
#   app/scripts/setup-kiosk-signing.sh [--import /path/to.keystore] [--new]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ANDROID="$(cd "$SCRIPT_DIR/../android" && pwd)"
KEY_PROPS="$APP_ANDROID/key.properties"
CONFIG_DIR="${HOME}/.config/family-calendar"
DEFAULT_JKS="$CONFIG_DIR/kiosk-signing.jks"
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
    echo "Generating new kiosk signing key at $DEFAULT_JKS"
    echo "WARNING: wall tablets need a one-time USB install before OTA works with this key."
    keytool -genkeypair -v \
      -keystore "$DEFAULT_JKS" \
      -storepass "${KIOSK_STORE_PASSWORD:-familycalendar}" \
      -keypass "${KIOSK_KEY_PASSWORD:-familycalendar}" \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -alias kiosk \
      -dname "CN=Family Calendar Kiosk, O=Smircich, C=US"
  fi
fi

if [[ ! -f "$DEFAULT_JKS" ]]; then
  echo "ERROR: no keystore at $DEFAULT_JKS — use --import or --new"
  exit 1
fi

# Detect alias when importing Android debug keystore.
ALIAS="kiosk"
STORE_PASS="${KIOSK_STORE_PASSWORD:-familycalendar}"
KEY_PASS="${KIOSK_KEY_PASSWORD:-familycalendar}"
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
echo "Rebuild kiosk: app/scripts/build-kiosk.sh && app/scripts/distribute-kiosk.sh"
