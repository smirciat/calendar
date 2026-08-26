# Build mobile APK and upload to Firebase App Distribution.
# Run from: calendar\app\scripts
#   powershell -ExecutionPolicy Bypass -File .\mobile-release.ps1
#   powershell -ExecutionPolicy Bypass -File .\mobile-release.ps1 "Bug fixes"

param(
    [string]$ReleaseNotes = "Family Calendar mobile build"
)

$ErrorActionPreference = "Stop"

$AppDir = Join-Path $PSScriptRoot ".."
$BuildScript = Join-Path $PSScriptRoot "build-mobile.ps1"
$DistributeScript = Join-Path $PSScriptRoot "distribute-mobile.ps1"

Write-Host ""
Write-Host "========================================"
Write-Host " Family Calendar - Mobile Release"
Write-Host "========================================"
Write-Host ""

& $BuildScript
& $DistributeScript -ReleaseNotes $ReleaseNotes
