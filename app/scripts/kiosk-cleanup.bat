@echo off
setlocal EnableExtensions

REM Remove duplicate/old calendar apps from the wall kiosk.
REM Run from: calendar\app\scripts  (device on USB, USB debugging on)
REM After cleanup, reinstall kiosk APK and run kiosk-setup.bat

set "KIOSK_PKG=com.familycalendar.family_calendar.kiosk"
set "APK_PATH=..\build\app\outputs\flutter-apk\app-kiosk-release.apk"

echo.
echo ========================================
echo  Kiosk Calendar Cleanup (ADB)
echo ========================================
echo.

where adb >nul 2>&1
if errorlevel 1 (
  echo ERROR: adb not found in PATH.
  goto :done
)

adb get-state 1>nul 2>&1
if errorlevel 1 (
  echo ERROR: No device connected.
  goto :done
)

echo --- Currently installed (calendar-related) ---
adb shell pm list packages fujia
adb shell pm list packages familycalendar
adb shell pm list packages calendar

echo.
echo This script will UNINSTALL for user 0:
echo   - com.fujia.calendar          (old Fujia eCalendar)
echo   - com.familycalendar.family_calendar       (wrong build, if present)
echo   - com.familycalendar.family_calendar.mobile (mobile flavor, if present)
echo.
echo It will KEEP (or reinstall):
echo   - %KIOSK_PKG%
echo.
set /p CONFIRM=Continue? [y/N]:
if /i not "%CONFIRM%"=="y" goto :done

echo.
echo --- Uninstalling old Fujia calendar ---
adb shell pm uninstall --user 0 com.fujia.calendar
if errorlevel 1 echo   ^(may be system app - trying disable instead^)
adb shell pm disable-user --user 0 com.fujia.calendar 2>nul

echo --- Uninstalling non-kiosk Family Calendar builds ---
adb shell pm uninstall --user 0 com.familycalendar.family_calendar
adb shell pm uninstall --user 0 com.familycalendar.family_calendar.mobile

echo --- Uninstalling kiosk build (fresh reinstall next) ---
adb shell pm uninstall --user 0 %KIOSK_PKG%

echo.
echo --- Remaining calendar-related packages ---
adb shell pm list packages fujia
adb shell pm list packages familycalendar
adb shell pm list packages calendar

echo.
echo --- Reinstall kiosk APK ---
if exist "%APK_PATH%" (
  adb install -r "%APK_PATH%"
) else (
  echo APK not found: %APK_PATH%
  echo Build first: flutter build apk --flavor kiosk -t lib/main_kiosk.dart
)

echo.
echo --- Launch and set as HOME ---
adb shell am start -n %KIOSK_PKG%/com.familycalendar.family_calendar.MainActivity
adb shell cmd package set-home-activity %KIOSK_PKG%/com.familycalendar.family_calendar.KioskHome
adb shell cmd role add-role-holder android.app.role.HOME 0 %KIOSK_PKG% 2>nul
adb shell am start -a android.settings.HOME_SETTINGS

echo.
echo Current default HOME:
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

echo.
echo ========================================
echo  Reboot when ready: adb reboot
echo ========================================

:done
echo.
pause
