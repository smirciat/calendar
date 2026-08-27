# Upload the Windows Android debug keystore to bering-dev for mobile + kiosk signing.
#   powershell -ExecutionPolicy Bypass -File .\upload-android-keystore.ps1

$ErrorActionPreference = "Stop"

$EnvFile = Join-Path $PSScriptRoot "..\..\.env"
$KeystoreSrc = Join-Path $env:USERPROFILE ".android\debug.keystore"
$DeployHost = "bering-dev"
$RemotePath = ".config/family-calendar/windows-debug.keystore"

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
Write-Host " Family Calendar - Upload Android Keystore"
Write-Host "========================================"
Write-Host ""

$hostOverride = Read-EnvValue $EnvFile "KIOSK_DEPLOY_HOST"
if ($hostOverride) { $DeployHost = $hostOverride }

Write-Host "Host:   $DeployHost"
Write-Host "Source: $KeystoreSrc"
Write-Host ""

if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: scp not found." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ssh not found." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $KeystoreSrc)) {
    Write-Host "ERROR: Keystore not found at $KeystoreSrc" -ForegroundColor Red
    exit 1
}

Write-Host "Creating remote folder .config/family-calendar ..."
ssh $DeployHost "mkdir -p .config/family-calendar"

Write-Host "Uploading debug keystore..."
scp $KeystoreSrc "${DeployHost}:${RemotePath}"

Write-Host ""
Write-Host "OK: uploaded to ${DeployHost}:${RemotePath}" -ForegroundColor Green
Write-Host ""
Write-Host "Next on bering-dev:"
Write-Host "  app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore"
Write-Host "iOS: build on Mac with Xcode signing (Apple cert, not this keystore)."
