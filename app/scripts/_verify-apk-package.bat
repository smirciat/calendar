@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Verify APK package name.
REM Usage: call _verify-apk-package.bat "path\to.apk" "com.expected.package"
if "%~2"=="" exit /b 1

set "APK=%~f1"
set "EXPECTED=%~2"
set "BADGING=%TEMP%\family-cal-apk-badging.txt"
set "AAPT="
set "FOUND_PACKAGE="

if not exist "%APK%" (
  echo ERROR: APK not found: %APK%
  exit /b 1
)

call :FindAapt
if defined AAPT call :DumpBadging
if not defined FOUND_PACKAGE call :TryApkanalyzerPackage

if not defined FOUND_PACKAGE (
  echo ERROR: Could not read package name from APK.
  if defined AAPT echo Tool: %AAPT%
  if exist "%BADGING%" (
    echo Badging output:
    type "%BADGING%"
  ) else (
    echo Install Android SDK Build-Tools in Android Studio if aapt is missing.
  )
  exit /b 1
)

if /i not "!FOUND_PACKAGE!"=="%EXPECTED%" (
  echo ERROR: Wrong APK package: !FOUND_PACKAGE!
  echo Expected: %EXPECTED%
  exit /b 1
)

echo Verified package: !FOUND_PACKAGE!
del "%BADGING%" 2>nul
exit /b 0

:FindAapt
where aapt >nul 2>&1 && set "AAPT=aapt" && exit /b 0
where aapt2 >nul 2>&1 && set "AAPT=aapt2" && exit /b 0
if defined ANDROID_HOME call :FindAaptIn "%ANDROID_HOME%\build-tools"
if defined AAPT exit /b 0
if exist "%LOCALAPPDATA%\Android\Sdk\build-tools" (
  call :FindAaptIn "%LOCALAPPDATA%\Android\Sdk\build-tools"
)
exit /b 0

:FindAaptIn
set "TOOLS_ROOT=%~1"
if not exist "%TOOLS_ROOT%" exit /b 0
for /f "delims=" %%i in ('dir /b /o-n "%TOOLS_ROOT%" 2^>nul') do (
  if not defined AAPT if exist "%TOOLS_ROOT%\%%i\aapt.exe" set "AAPT=%TOOLS_ROOT%\%%i\aapt.exe"
  if not defined AAPT if exist "%TOOLS_ROOT%\%%i\aapt2.exe" set "AAPT=%TOOLS_ROOT%\%%i\aapt2.exe"
)
exit /b 0

:DumpBadging
del "%BADGING%" 2>nul
"%AAPT%" dump badging "%APK%" > "%BADGING%" 2>&1
if errorlevel 1 (
  echo WARNING: %AAPT% dump badging failed.
  exit /b 0
)
for /f "usebackq delims=" %%L in ("%BADGING%") do (
  set "LINE=%%L"
  echo !LINE! | findstr /c:"package: name=" >nul 2>&1
  if not errorlevel 1 if not defined FOUND_PACKAGE (
    for /f "tokens=2 delims='" %%p in ("!LINE!") do set "FOUND_PACKAGE=%%p"
  )
)
exit /b 0

:TryApkanalyzerPackage
set "APKANALYZER="
if defined ANDROID_HOME if exist "%ANDROID_HOME%\cmdline-tools\latest\bin\apkanalyzer.bat" (
  set "APKANALYZER=%ANDROID_HOME%\cmdline-tools\latest\bin\apkanalyzer.bat"
)
if not defined APKANALYZER if exist "%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\apkanalyzer.bat" (
  set "APKANALYZER=%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\apkanalyzer.bat"
)
if not defined APKANALYZER exit /b 0
for /f "delims=" %%p in ('call "%APKANALYZER%" manifest application-id "%APK%" 2^>nul') do (
  if not defined FOUND_PACKAGE set "FOUND_PACKAGE=%%p"
)
exit /b 0
