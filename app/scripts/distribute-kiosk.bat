@echo off
setlocal EnableExtensions

REM Upload kiosk APK to bering-dev for OTA updates.
REM Safe to run from app/scripts/ (uses script location).
REM Requires: scp in PATH (OpenSSH client), SSH access to deploy host.

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%.."
set "REPO_ROOT=%SCRIPT_DIR%..\.."
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-kiosk-release.apk"
set "ENV_FILE=%REPO_ROOT%\.env"
set "EXPECTED_PACKAGE=com.smircich.familycalendar.kiosk"
set "KIOSK_DEPLOY_HOST=bering-dev"
set "KIOSK_DEPLOY_PATH=/var/www/family-calendar/releases/app-kiosk-release.apk"

if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b "KIOSK_DEPLOY_HOST=" "%ENV_FILE%"`) do set "KIOSK_DEPLOY_HOST=%%B"
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b "KIOSK_DEPLOY_PATH=" "%ENV_FILE%"`) do set "KIOSK_DEPLOY_PATH=%%B"
)

echo.
echo ========================================
echo  Family Calendar - Upload Kiosk APK
echo  Package: %EXPECTED_PACKAGE%
echo  Host:    %KIOSK_DEPLOY_HOST%
echo  Path:    %KIOSK_DEPLOY_PATH%
echo ========================================
echo.

where scp >nul 2>&1
if errorlevel 1 (
  echo ERROR: scp not found. Install OpenSSH client on Windows.
  goto :done
)

if not exist "%APK_PATH%" (
  echo ERROR: APK not found at %APK_PATH%
  echo Run build-kiosk.bat first.
  goto :done
)

call "%SCRIPT_DIR%_verify-apk-package.bat" "%APK_PATH%" "%EXPECTED_PACKAGE%"
if errorlevel 1 goto :done

echo Uploading %APK_PATH% ...
scp "%APK_PATH%" %KIOSK_DEPLOY_HOST%:%KIOSK_DEPLOY_PATH%
if errorlevel 1 (
  echo ERROR: scp failed.
  goto :done
)

echo.
echo OK: uploaded to %KIOSK_DEPLOY_HOST%:%KIOSK_DEPLOY_PATH%
echo Next on server:
echo   1. Set KIOSK_LATEST_BUILD in .env
echo   2. pm2 restart family-calendar

:done
echo.
pause
