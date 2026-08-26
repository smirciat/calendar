# Family Calendar kiosk setup for Windows (PowerShell)
# Run from: calendar\app\scripts
#   powershell -ExecutionPolicy Bypass -File .\kiosk-setup.ps1

$ErrorActionPreference = "Continue"

$FamilyPkg = "com.smircich.familycalendar.kiosk"
$MainActivity = "$FamilyPkg/com.familycalendar.family_calendar.MainActivity"
$KioskHome = "$FamilyPkg/com.familycalendar.family_calendar.KioskHome"
$DeviceAdmin = "$FamilyPkg/com.familycalendar.family_calendar.KioskDeviceAdminReceiver"
$ApkPath = Join-Path $PSScriptRoot "..\build\app\outputs\flutter-apk\app-kiosk-release.apk"

function Invoke-Adb([string]$Args) {
    Write-Host "> adb $Args" -ForegroundColor DarkGray
    $output = adb $Args.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries) 2>&1
    $output | ForEach-Object { Write-Host $_ }
    return $LASTEXITCODE
}

Write-Host ""
Write-Host "========================================"
Write-Host " Family Calendar - Kiosk Setup (ADB)"
Write-Host "========================================"
Write-Host ""

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: adb not found in PATH." -ForegroundColor Red
    exit 1
}

if ((Invoke-Adb "get-state") -ne 0) {
    Write-Host "ERROR: No device connected." -ForegroundColor Red
    exit 1
}

Write-Host "--- Step 1: Re-enable Fujia calendar ---"
Invoke-Adb "shell pm enable com.fujia.calendar" | Out-Null

Write-Host ""
Write-Host "--- Step 2: Install kiosk APK (if built) ---"
if (Test-Path $ApkPath) {
    Invoke-Adb "install -r `"$ApkPath`"" | Out-Null
} else {
    Write-Host "APK not found: $ApkPath"
    Write-Host "Build: flutter build apk --flavor kiosk -t lib/main_kiosk.dart"
}

Write-Host ""
Write-Host "--- Step 3: Check app is installed ---"
Invoke-Adb "shell pm list packages $FamilyPkg"
$pathCode = Invoke-Adb "shell pm path $FamilyPkg"
if ($pathCode -ne 0) {
    Write-Host "ERROR: $FamilyPkg not installed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "--- Step 4: Launch Family Calendar ---"
Invoke-Adb "shell am start -n $MainActivity" | Out-Null

Write-Host ""
Write-Host "--- Step 5: Set default HOME ---"

Write-Host "Trying set-home-activity (KioskHome)..."
if ((Invoke-Adb "shell cmd package set-home-activity $KioskHome") -ne 0) {
    Write-Host "Trying set-home-activity (MainActivity)..."
    Invoke-Adb "shell cmd package set-home-activity $MainActivity" | Out-Null
}

Write-Host "Trying role add-role-holder with user 0..."
if ((Invoke-Adb "shell cmd role add-role-holder android.app.role.HOME 0 $FamilyPkg") -ne 0) {
    Write-Host "role holder failed (common on Android 10) - pick launcher on device" -ForegroundColor Yellow
}

Write-Host "Opening Home app settings..."
Invoke-Adb "shell am start -a android.settings.HOME_SETTINGS" | Out-Null

Write-Host ""
Write-Host "--- Step 6: Device owner (optional) ---"
Invoke-Adb "shell dpm set-device-owner $DeviceAdmin" | Out-Null

Write-Host ""
Write-Host "--- Step 7: Verify ---"
Write-Host "Current default HOME:"
Invoke-Adb "shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME"
Write-Host ""
Write-Host "Installed family packages:"
Invoke-Adb "shell pm list packages smircich"

Write-Host ""
Write-Host "========================================"
Write-Host " Next: adb reboot"
Write-Host " Never disable com.fujia.calendar"
Write-Host "========================================"
Write-Host ""
