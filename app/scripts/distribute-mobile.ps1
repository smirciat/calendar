# Upload mobile APK to Firebase App Distribution.
# Run from: calendar\app\scripts
#   powershell -ExecutionPolicy Bypass -File .\distribute-mobile.ps1
#   powershell -ExecutionPolicy Bypass -File .\distribute-mobile.ps1 "Bug fixes"

param(
    [string]$ReleaseNotes = "Family Calendar mobile build"
)

$ErrorActionPreference = "Stop"

$EnvFile = Join-Path $PSScriptRoot "..\..\.env"
$ApkPath = Join-Path $PSScriptRoot "..\build\app\outputs\flutter-apk\app-mobile-release.apk"
$AndroidAppId = $null
$TestersGroup = "family"

function Read-EnvValue([string]$Path, [string]$Key) {
    if (-not (Test-Path $Path)) { return $null }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $parts = $line -split "=", 2
        if ($parts.Count -eq 2 -and $parts[0].Trim() -eq $Key) {
            return $parts[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

Write-Host ""
Write-Host "========================================"
Write-Host " Family Calendar - Firebase Distribute"
Write-Host "========================================"
Write-Host ""

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: firebase not found. Run: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: $EnvFile not found. Copy .env-sample to .env and set ANDROID_APP_ID." -ForegroundColor Red
    exit 1
}

$AndroidAppId = Read-EnvValue $EnvFile "ANDROID_APP_ID"
$groupOverride = Read-EnvValue $EnvFile "FIREBASE_TESTERS_GROUP"
if ($groupOverride) { $TestersGroup = $groupOverride }

if (-not $AndroidAppId) {
    Write-Host "ERROR: ANDROID_APP_ID is missing in $EnvFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ApkPath)) {
    Write-Host "ERROR: APK not found at $ApkPath" -ForegroundColor Red
    Write-Host "Build first: .\build-mobile.ps1"
    exit 1
}

Write-Host "App ID: $AndroidAppId"
Write-Host "Group:  $TestersGroup"
Write-Host "APK:    $ApkPath"
Write-Host "Notes:  $ReleaseNotes"
Write-Host ""

& firebase appdistribution:distribute $ApkPath `
    --app $AndroidAppId `
    --groups $TestersGroup `
    --release-notes $ReleaseNotes

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: firebase distribute failed. Try: firebase login" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Done. Testers in group '$TestersGroup' should get an email." -ForegroundColor Green
