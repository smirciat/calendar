# Remove duplicate/old calendar apps from the wall kiosk.
# Usage: powershell -ExecutionPolicy Bypass -File .\kiosk-cleanup.ps1

$ErrorActionPreference = "Continue"

$KioskPkg = "com.familycalendar.family_calendar.kiosk"
$ApkPath = Join-Path $PSScriptRoot "..\build\app\outputs\flutter-apk\app-kiosk-release.apk"
$ToRemove = @(
    "com.familycalendar.family_calendar",
    "com.familycalendar.family_calendar.mobile",
    $KioskPkg
)

function Invoke-Adb([string]$Args) {
    Write-Host "> adb $Args" -ForegroundColor DarkGray
    adb $Args.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries) 2>&1 | ForEach-Object { Write-Host $_ }
}

Write-Host ""
Write-Host "========================================"
Write-Host " Kiosk Calendar Cleanup (ADB)"
Write-Host "========================================"
Write-Host ""

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: adb not in PATH." -ForegroundColor Red
    exit 1
}
if ((Invoke-Adb "get-state") -and $LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No device connected." -ForegroundColor Red
    exit 1
}

Write-Host "--- Currently installed ---"
Invoke-Adb "shell pm list packages fujia"
Invoke-Adb "shell pm list packages familycalendar"
Invoke-Adb "shell pm list packages calendar"

Write-Host ""
Write-Host "Will NOT touch com.fujia.calendar (keep on Fujia tablets)." -ForegroundColor Cyan
$ToRemove | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
$confirm = Read-Host "Continue? [y/N]"
if ($confirm -notmatch "^[Yy]") { exit 0 }

Write-Host ""
foreach ($pkg in $ToRemove) {
    Write-Host "--- Uninstalling $pkg ---"
    Invoke-Adb "shell pm uninstall --user 0 $pkg"
}

Write-Host ""
Write-Host "--- Remaining ---"
Invoke-Adb "shell pm list packages fujia"
Invoke-Adb "shell pm list packages familycalendar"

Write-Host ""
Write-Host "--- Reinstall kiosk APK ---"
if (Test-Path $ApkPath) {
    Invoke-Adb "install -r `"$ApkPath`""
} else {
    Write-Host "APK not found: $ApkPath"
}

Write-Host ""
Write-Host "--- Set as HOME ---"
Invoke-Adb "shell am start -n $KioskPkg/com.familycalendar.family_calendar.MainActivity"
Invoke-Adb "shell cmd package set-home-activity $KioskPkg/com.familycalendar.family_calendar.KioskHome"
Invoke-Adb "shell cmd role add-role-holder android.app.role.HOME 0 $KioskPkg"
Invoke-Adb "shell am start -a android.settings.HOME_SETTINGS"

Write-Host ""
Write-Host "Current default HOME:"
Invoke-Adb "shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME"

Write-Host ""
Write-Host "Reboot when ready: adb reboot"
