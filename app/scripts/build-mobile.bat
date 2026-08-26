@echo off
setlocal EnableExtensions

REM Build Family Calendar mobile APK for Firebase App Distribution.
REM Run from: calendar\app\scripts
REM Requires: flutter in PATH

set "APP_DIR=.."
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-mobile-release.apk"

echo.
echo ========================================
echo  Family Calendar - Build Mobile APK
echo ========================================
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found. Add Flutter to PATH.
  goto :done
)

pushd "%APP_DIR%"
echo Building release APK ^(mobile flavor^)...
call flutter build apk --flavor mobile -t lib/main_mobile.dart --release
set "BUILD_EXIT=%ERRORLEVEL%"
popd

if not "%BUILD_EXIT%"=="0" (
  echo.
  echo ERROR: flutter build failed.
  goto :done
)

if exist "%APK_PATH%" (
  echo.
  echo OK: %APK_PATH%
  echo.
  echo Next: distribute-mobile.bat
  echo   or: distribute-mobile.bat "Release notes here"
) else (
  echo ERROR: APK not found at %APK_PATH%
)

:done
echo.
pause
