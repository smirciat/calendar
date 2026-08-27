@echo off
setlocal EnableExtensions

REM Build Family Calendar KIOSK APK for wall tablet (ADB install — NOT Firebase).
REM Safe to run from any directory (uses script location).

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%.."
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-kiosk-release.apk"
set "EXPECTED_PACKAGE=com.smircich.familycalendar.kiosk"

echo.
echo ========================================
echo  Family Calendar - Build KIOSK APK
echo  Package: %EXPECTED_PACKAGE%
echo  Entry:   lib/main_kiosk.dart
echo  Output:  app-kiosk-release.apk
echo  Install: kiosk-setup.bat or adb install
echo  Do NOT upload to Firebase
echo ========================================
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found. Add Flutter to PATH.
  goto :done
)

pushd "%APP_DIR%"
echo Building release APK ^(kiosk flavor^)...
call flutter build apk --flavor kiosk -t lib/main_kiosk.dart --release
set "BUILD_EXIT=%ERRORLEVEL%"
popd

if not "%BUILD_EXIT%"=="0" (
  echo.
  echo ERROR: flutter build failed.
  goto :done
)

if not exist "%APK_PATH%" (
  echo ERROR: APK not found at %APK_PATH%
  goto :done
)

call "%SCRIPT_DIR%_verify-apk-package.bat" "%APK_PATH%" "%EXPECTED_PACKAGE%"
if errorlevel 1 goto :done

echo.
echo OK: %APK_PATH%
echo Next: distribute-kiosk.bat  (upload for OTA) or kiosk-setup.bat  (USB install)

:done
echo.
pause
