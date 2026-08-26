@echo off
setlocal EnableExtensions

REM Build mobile APK and upload to Firebase App Distribution.
REM Safe to run from any directory (uses script location).
REM Optional: mobile-release.bat "Release notes"

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%.."
set "REPO_ROOT=%SCRIPT_DIR%..\.."
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-mobile-release.apk"
set "ENV_FILE=%REPO_ROOT%\.env"
set "EXPECTED_PACKAGE=com.smircich.familycalendar"
set "FIREBASE_TESTERS_GROUP=family"
set "RELEASE_NOTES=%~1"

if "%RELEASE_NOTES%"=="" set "RELEASE_NOTES=Family Calendar mobile build"

echo.
echo ========================================
echo  Family Calendar - Mobile Release
echo  build-mobile + distribute-mobile
echo ========================================
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found.
  goto :done
)

where firebase >nul 2>&1
if errorlevel 1 (
  echo ERROR: firebase not found.
  goto :done
)

pushd "%APP_DIR%"
echo --- Build mobile ---
call flutter build apk --flavor mobile -t lib/main_mobile.dart --release
set "BUILD_EXIT=%ERRORLEVEL%"
popd

if not "%BUILD_EXIT%"=="0" goto :done
if not exist "%APK_PATH%" (
  echo ERROR: APK not found at %APK_PATH%
  goto :done
)

call "%SCRIPT_DIR%_verify-apk-package.bat" "%APK_PATH%" "%EXPECTED_PACKAGE%"
if errorlevel 1 goto :done

if not exist "%ENV_FILE%" (
  echo ERROR: %ENV_FILE% not found.
  goto :done
)

for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
  if /i "%%a"=="ANDROID_APP_ID" set "ANDROID_APP_ID=%%b"
  if /i "%%a"=="FIREBASE_TESTERS_GROUP" set "FIREBASE_TESTERS_GROUP=%%b"
)

echo.
echo --- Distribute ---
firebase appdistribution:distribute "%APK_PATH%" ^
  --app "%ANDROID_APP_ID%" ^
  --groups "%FIREBASE_TESTERS_GROUP%" ^
  --release-notes "%RELEASE_NOTES%"

:done
echo.
pause
