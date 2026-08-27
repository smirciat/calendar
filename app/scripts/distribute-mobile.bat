@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Upload MOBILE APK to Firebase App Distribution.
REM Safe to run from any directory (uses script location).

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%.."
set "REPO_ROOT=%SCRIPT_DIR%..\.."
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-mobile-release.apk"
set "KIOSK_APK=%APP_DIR%\build\app\outputs\flutter-apk\app-kiosk-release.apk"
set "ENV_FILE=%REPO_ROOT%\.env"
set "EXPECTED_PACKAGE=com.smircich.familycalendar"
set "FIREBASE_TESTERS_GROUP=family-android"
set "RELEASE_NOTES=%~1"

if "%RELEASE_NOTES%"=="" set "RELEASE_NOTES=Family Calendar mobile build"

echo.
echo ========================================
echo  Family Calendar - Firebase Distribute
echo  MOBILE ONLY: %EXPECTED_PACKAGE%
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
  if /i "%%a"=="MOBILE_PACKAGE_NAME" set "EXPECTED_PACKAGE=%%b"
)

if "%ANDROID_APP_ID%"=="" (
  echo ERROR: ANDROID_APP_ID is missing in %ENV_FILE%
  goto :done
)

if not exist "%APK_PATH%" (
  echo ERROR: Mobile APK not found:
  echo   %APK_PATH%
  echo.
  echo Run build-mobile.bat first ^(not build-kiosk.bat^).
  goto :done
)

if exist "%KIOSK_APK%" (
  for %%F in ("%APK_PATH%") do set "MOBILE_TIME=%%~tF"
  for %%F in ("%KIOSK_APK%") do set "KIOSK_TIME=%%~tF"
  if "!MOBILE_TIME!" LSS "!KIOSK_TIME!" (
    echo ERROR: Kiosk APK is newer than mobile APK.
    echo You likely built the wall tablet last. Run build-mobile.bat, then try again.
    goto :done
  )
)

call "%SCRIPT_DIR%_verify-apk-package.bat" "%APK_PATH%" "%EXPECTED_PACKAGE%"
if errorlevel 1 (
  echo.
  if exist "%KIOSK_APK%" (
    echo If you need the wall build, use build-kiosk.bat + adb install.
  )
  goto :done
)

echo App ID:  %ANDROID_APP_ID%
echo Package: %EXPECTED_PACKAGE%
echo Group:   %FIREBASE_TESTERS_GROUP%
echo APK:     %APK_PATH%
echo Notes:   %RELEASE_NOTES%
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
