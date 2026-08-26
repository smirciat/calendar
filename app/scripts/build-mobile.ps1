# Build Family Calendar mobile APK for Firebase App Distribution.
# Run from: calendar\app\scripts
#   powershell -ExecutionPolicy Bypass -File .\build-mobile.ps1

$ErrorActionPreference = "Stop"

$AppDir = Join-Path $PSScriptRoot ".."
$ApkPath = Join-Path $AppDir "build\app\outputs\flutter-apk\app-mobile-release.apk"

Write-Host ""
Write-Host "========================================"
Write-Host " Family Calendar - Build Mobile APK"
Write-Host "========================================"
Write-Host ""

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: flutter not found in PATH." -ForegroundColor Red
    exit 1
}

Push-Location $AppDir
try {
    Write-Host "Building release APK (mobile flavor)..."
    flutter build apk --flavor mobile -t lib/main_mobile.dart --release
} finally {
    Pop-Location
}

if (-not (Test-Path $ApkPath)) {
    Write-Host "ERROR: APK not found at $ApkPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "OK: $ApkPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next: .\distribute-mobile.ps1"
Write-Host '  or: .\distribute-mobile.ps1 "Release notes here"'
