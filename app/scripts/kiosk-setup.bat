@echo off
setlocal EnableExtensions

REM Family Calendar kiosk setup for Windows (CMD)
REM Run from: calendar\app\scripts
REM Requires: adb in PATH, USB debugging on wall device

set "FAMILY_PKG=com.smircich.familycalendar.kiosk"
set "MAIN_ACTIVITY=%FAMILY_PKG%/com.familycalendar.family_calendar.MainActivity"
set "KIOSK_HOME=%FAMILY_PKG%/com.familycalendar.family_calendar.KioskHome"
set "DEVICE_ADMIN=%FAMILY_PKG%/com.familycalendar.family_calendar.KioskDeviceAdminReceiver"
set "APK_PATH=..\build\app\outputs\flutter-apk\app-kiosk-release.apk"

echo.
echo ========================================
echo  Family Calendar - Kiosk Setup (ADB)
echo ========================================
echo.

where adb >nul 2>&1
if errorlevel 1 (
  echo ERROR: adb not found. Install Android platform-tools and add to PATH.
  goto :done
)

echo Checking device...
adb get-state 1>nul 2>&1
if errorlevel 1 (
  echo ERROR: No device connected. Plug in USB and allow debugging.
  goto :done
)

echo.
echo --- Step 1: Re-enable Fujia calendar (do NOT disable it) ---
adb shell pm enable com.fujia.calendar

echo.
echo --- Step 2: Install kiosk APK (if built) ---
if exist "%APK_PATH%" (
  echo Installing %APK_PATH%
  adb install -r "%APK_PATH%"
) else (
  echo APK not found at %APK_PATH%
  echo Build first: flutter build apk --flavor kiosk -t lib/main_kiosk.dart
)

echo.
echo --- Step 3: Check app is installed ---
adb shell pm list packages %FAMILY_PKG%
adb shell pm path %FAMILY_PKG%
if errorlevel 1 (
  echo ERROR: %FAMILY_PKG% is not installed. Build and install APK first.
  goto :done
)

echo.
echo --- Step 4: Launch Family Calendar ---
adb shell am start -n %MAIN_ACTIVITY%

echo.
echo --- Step 5: Set default HOME (tries several methods) ---
echo Trying set-home-activity...
adb shell cmd package set-home-activity %KIOSK_HOME%
if errorlevel 1 (
  echo set-home-activity failed, trying MainActivity...
  adb shell cmd package set-home-activity %MAIN_ACTIVITY%
)

echo Trying role add-role-holder with user 0...
adb shell cmd role add-role-holder android.app.role.HOME 0 %FAMILY_PKG%
if errorlevel 1 (
  echo role holder failed ^(common on Android 10 / custom ROMs^) - use HOME button on device if needed
)

echo Opening Android Home app settings ^(pick Family Calendar Wall - Always^)...
adb shell am start -a android.settings.HOME_SETTINGS

echo.
echo --- Step 6: Device owner ^(optional, helps prevent uninstall^) ---
echo May fail if a Google account exists on the device.
adb shell dpm set-device-owner %DEVICE_ADMIN%

echo.
echo --- Step 7: Verify ---
echo Current default HOME:
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
echo.
echo Installed family packages:
adb shell pm list packages smircich

echo.
echo ========================================
echo  Next: reboot and confirm app survives
echo    adb reboot
echo.
echo  IMPORTANT: Never disable com.fujia.calendar
echo ========================================

:done
echo.
pause
