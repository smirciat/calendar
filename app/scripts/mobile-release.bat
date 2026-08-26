@echo off
setlocal EnableExtensions

REM Build mobile APK and upload to Firebase App Distribution.
REM Run from: calendar\app\scripts
REM Optional release notes: mobile-release.bat "Fixed duplicate events"

set "APP_DIR=.."
set "SCRIPT_DIR=%~dp0"
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-mobile-release.apk"
set "RELEASE_NOTES=%~1"
if "%RELEASE_NOTES%"=="" set "RELEASE_NOTES=Family Calendar mobile build"

echo.
echo ========================================
echo  Family Calendar - Mobile Release
echo ========================================
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found.
  goto :done
)

pushd "%APP_DIR%"
echo --- Build ---
call flutter build apk --flavor mobile -t lib/main_mobile.dart --release
set "BUILD_EXIT=%ERRORLEVEL%"
popd

if not "%BUILD_EXIT%"=="0" goto :done
if not exist "%APK_PATH%" (
  echo ERROR: APK not found at %APK_PATH%
  goto :done
)

echo.
echo --- Distribute ---
call "%SCRIPT_DIR%distribute-mobile.bat" "%RELEASE_NOTES%"

:done
echo.
pause
