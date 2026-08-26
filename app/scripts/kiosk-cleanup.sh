#!/usr/bin/env bash
# Remove duplicate/old calendar apps from the wall kiosk.
set -euo pipefail

KIOSK_PKG="com.familycalendar.family_calendar.kiosk"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APK_PATH="${SCRIPT_DIR}/../build/app/outputs/flutter-apk/app-kiosk-release.apk"

TO_REMOVE=(
  "com.familycalendar.family_calendar"
  "com.familycalendar.family_calendar.mobile"
  "${KIOSK_PKG}"
)

echo
echo "========================================"
echo " Kiosk Calendar Cleanup (ADB)"
echo "========================================"
echo

command -v adb >/dev/null || { echo "ERROR: adb not found"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "ERROR: No device connected"; exit 1; }

echo "--- Currently installed ---"
adb shell pm list packages fujia || true
adb shell pm list packages familycalendar || true
adb shell pm list packages calendar || true

echo
echo "Will NOT touch com.fujia.calendar (keep on Fujia tablets)."
printf 'Will uninstall for user 0:\n'
printf '  - %s\n' "${TO_REMOVE[@]}"
echo
read -r -p "Continue? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy] ]] || exit 0

echo
for pkg in "${TO_REMOVE[@]}"; do
  echo "--- Uninstalling ${pkg} ---"
  adb shell pm uninstall --user 0 "${pkg}" || true
done

echo
echo "--- Remaining ---"
adb shell pm list packages fujia || true
adb shell pm list packages familycalendar || true

echo
echo "--- Reinstall kiosk APK ---"
if [[ -f "$APK_PATH" ]]; then
  adb install -r "$APK_PATH"
else
  echo "APK not found: $APK_PATH"
fi

echo
echo "--- Set as HOME ---"
adb shell am start -n "${KIOSK_PKG}/com.familycalendar.family_calendar.MainActivity"
adb shell cmd package set-home-activity "${KIOSK_PKG}/com.familycalendar.family_calendar.KioskHome"
adb shell cmd role add-role-holder android.app.role.HOME 0 "${KIOSK_PKG}" 2>/dev/null || true
adb shell am start -a android.settings.HOME_SETTINGS

echo
echo "Current default HOME:"
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

echo
echo "Reboot when ready: adb reboot"
