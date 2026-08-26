@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Verify APK package name. Sets VERIFY_PACKAGE on success.
REM Usage: call _verify-apk-package.bat "path\to.apk" "com.expected.package"
if "%~2"=="" exit /b 1

set "APK=%~1"
set "EXPECTED=%~2"
set "AAPT="

if not exist "%APK%" (
  echo ERROR: APK not found: %APK%
  exit /b 1
)

where aapt >nul 2>&1
if not errorlevel 1 set "AAPT=aapt"

if not defined AAPT (
  if defined ANDROID_HOME (
    for /f "delims=" %%i in ('dir /b /o-n "%ANDROID_HOME%\build-tools" 2^>nul') do (
      if exist "%ANDROID_HOME%\build-tools\%%i\aapt.exe" (
        set "AAPT=%ANDROID_HOME%\build-tools\%%i\aapt.exe"
        goto :found_aapt
      )
    )
  )
)

:found_aapt
if not defined AAPT (
  if exist "%LOCALAPPDATA%\Android\Sdk\build-tools" (
    for /f "delims=" %%i in ('dir /b /o-n "%LOCALAPPDATA%\Android\Sdk\build-tools" 2^>nul') do (
      if exist "%LOCALAPPDATA%\Android\Sdk\build-tools\%%i\aapt.exe" (
        set "AAPT=%LOCALAPPDATA%\Android\Sdk\build-tools\%%i\aapt.exe"
        goto :have_aapt
      )
    )
  )
)

:have_aapt
if not defined AAPT (
  echo ERROR: aapt not found. Install Android SDK build-tools or add aapt to PATH.
  echo Cannot verify APK package — refusing to continue.
  exit /b 1
)

set "FOUND_PACKAGE="
for /f "tokens=2 delims='" %%p in ('"%AAPT%" dump badging "%APK%" 2^>nul ^| findstr /b "package: name"') do set "FOUND_PACKAGE=%%p"

if not defined FOUND_PACKAGE (
  echo ERROR: Could not read package name from APK.
  exit /b 1
)

if /i not "!FOUND_PACKAGE!"=="%EXPECTED%" (
  echo ERROR: Wrong APK package: !FOUND_PACKAGE!
  echo Expected: %EXPECTED%
  exit /b 1
)

echo Verified package: !FOUND_PACKAGE!
exit /b 0
