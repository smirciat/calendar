#!/usr/bin/env bash
# One-time kiosk wall setup over ADB.
set -euo pipefail

FAMILY_PKG="com.smircich.familycalendar.kiosk"
MAIN_ACTIVITY="${FAMILY_PKG}/com.familycalendar.family_calendar.MainActivity"
FAMILY_HOME="${FAMILY_PKG}/com.familycalendar.family_calendar.KioskHome"
DEVICE_ADMIN="${FAMILY_PKG}/com.familycalendar.family_calendar.KioskDeviceAdminReceiver"

echo "=== Installed family calendar packages ==="
adb shell pm list packages | grep -i smircich || true

echo
echo "=== Current default HOME launcher ==="
adb shell cmd package resolve-activity --brief \
  -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null || true

echo
echo "=== Re-enable Fujia calendar (do NOT disable it on Fujia hardware) ==="
adb shell pm enable com.fujia.calendar 2>/dev/null || true

echo
echo "=== Launch Family Calendar ==="
adb shell am start -n "${MAIN_ACTIVITY}"

echo
echo "=== Setting Family Calendar Wall as default HOME ==="
adb shell cmd role add-role-holder android.app.role.HOME "${FAMILY_PKG}" 2>/dev/null || true
adb shell cmd package set-home-activity "${FAMILY_HOME}" 2>/dev/null || true

echo
echo "=== Device owner (helps prevent uninstall on reboot) ==="
adb shell dpm set-device-owner "${DEVICE_ADMIN}" 2>/dev/null || \
  echo "Device owner failed (remove Google accounts on device and retry, or factory reset)."

echo
echo "=== Verifying ==="
adb shell cmd package resolve-activity --brief \
  -a android.intent.action.MAIN -c android.intent.category.HOME

adb shell pm list packages | grep -i smircich || true

echo
echo "Done. Reboot to test: adb reboot"
echo "IMPORTANT: Do NOT disable com.fujia.calendar on Fujia tablets."
