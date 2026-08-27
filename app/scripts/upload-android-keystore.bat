@echo off
setlocal EnableExtensions

REM Upload the Windows Android debug keystore to bering-dev for mobile + kiosk signing.
REM Run from the Windows PC that built prior release APKs (same signing key).
REM Safe to run from any directory (uses script location).

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%..\.."
set "ENV_FILE=%REPO_ROOT%\.env"
set "KEYSTORE_SRC=%USERPROFILE%\.android\debug.keystore"
set "KIOSK_DEPLOY_HOST=bering-dev"
set "REMOTE_PATH=.config/family-calendar/windows-debug.keystore"

if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b "KIOSK_DEPLOY_HOST=" "%ENV_FILE%"`) do set "KIOSK_DEPLOY_HOST=%%B"
)

echo.
echo ========================================
echo  Family Calendar - Upload Android Keystore
echo  Host:   %KIOSK_DEPLOY_HOST%
echo  Source: %KEYSTORE_SRC%
echo ========================================
echo.

where scp >nul 2>&1
if errorlevel 1 (
  echo ERROR: scp not found. Install OpenSSH client on Windows.
  goto :done
)

where ssh >nul 2>&1
if errorlevel 1 (
  echo ERROR: ssh not found. Install OpenSSH client on Windows.
  goto :done
)

if not exist "%KEYSTORE_SRC%" (
  echo ERROR: Keystore not found at:
  echo   %KEYSTORE_SRC%
  echo.
  echo Build at least one Android APK on this PC first, or install Android Studio.
  goto :done
)

echo Creating remote folder .config/family-calendar ...
ssh %KIOSK_DEPLOY_HOST% "mkdir -p .config/family-calendar"
if errorlevel 1 (
  echo ERROR: ssh failed. Check SSH access to %KIOSK_DEPLOY_HOST%.
  goto :done
)

echo Uploading debug keystore...
scp "%KEYSTORE_SRC%" %KIOSK_DEPLOY_HOST%:%REMOTE_PATH%
if errorlevel 1 (
  echo.
  echo ERROR: scp failed. Check SSH access to %KIOSK_DEPLOY_HOST%.
  goto :done
)

echo.
echo OK: uploaded to %KIOSK_DEPLOY_HOST%:%REMOTE_PATH%
echo.
echo Next on bering-dev:
echo   cd ~/calendar ^&^& git pull
echo   app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore
echo   app/scripts/build-mobile.sh ^&^& app/scripts/distribute-mobile.sh "Build notes"
echo   app/scripts/build-kiosk.sh ^&^& app/scripts/distribute-kiosk.sh
echo   pm2 restart family-calendar
echo.
echo iOS: build on Mac with Xcode signing ^(Apple cert, not this keystore^).

:done
echo.
pause
