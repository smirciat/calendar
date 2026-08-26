@echo off
setlocal EnableExtensions

REM Upload mobile APK to Firebase App Distribution.
REM Run from: calendar\app\scripts
REM Requires: firebase in PATH, firebase login, ANDROID_APP_ID in calendar\.env

set "ENV_FILE=..\..\.env"
set "APK_PATH=..\build\app\outputs\flutter-apk\app-mobile-release.apk"
set "FIREBASE_TESTERS_GROUP=family"
set "RELEASE_NOTES=%~1"

if "%RELEASE_NOTES%"=="" set "RELEASE_NOTES=Family Calendar mobile build"

echo.
echo ========================================
echo  Family Calendar - Firebase Distribute
echo ========================================
echo.

where firebase >nul 2>&1
if errorlevel 1 (
  echo ERROR: firebase not found. Run: npm install -g firebase-tools
  goto :done
)

if not exist "%ENV_FILE%" (
  echo ERROR: %ENV_FILE% not found. Copy .env-sample to .env and set ANDROID_APP_ID.
  goto :done
)

for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
  if /i "%%a"=="ANDROID_APP_ID" set "ANDROID_APP_ID=%%b"
  if /i "%%a"=="FIREBASE_TESTERS_GROUP" set "FIREBASE_TESTERS_GROUP=%%b"
)

if "%ANDROID_APP_ID%"=="" (
  echo ERROR: ANDROID_APP_ID is missing in %ENV_FILE%
  goto :done
)

if not exist "%APK_PATH%" (
  echo ERROR: APK not found at %APK_PATH%
  echo Build first: build-mobile.bat
  goto :done
)

echo App ID: %ANDROID_APP_ID%
echo Group:  %FIREBASE_TESTERS_GROUP%
echo APK:    %APK_PATH%
echo Notes:  %RELEASE_NOTES%
echo.

firebase appdistribution:distribute "%APK_PATH%" ^
  --app "%ANDROID_APP_ID%" ^
  --groups "%FIREBASE_TESTERS_GROUP%" ^
  --release-notes "%RELEASE_NOTES%"

if errorlevel 1 (
  echo.
  echo ERROR: firebase distribute failed. Try: firebase login
) else (
  echo.
  echo Done. Testers in group "%FIREBASE_TESTERS_GROUP%" should get an email.
)

:done
echo.
pause
