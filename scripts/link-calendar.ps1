# Link a Google Calendar account to the family.
# Usage: .\scripts\link-calendar.ps1
#        .\scripts\link-calendar.ps1 -Password "your-family-password"
# Or set env: $env:FAMILY_PASSWORD = "your-family-password"

param(
    [string]$Password = $env:FAMILY_PASSWORD,
    [string]$BaseUrl = $env:BASE_URL
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$EnvFile = Join-Path $Root ".env"

if (-not $BaseUrl -and (Test-Path $EnvFile)) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*BASE_URL=(.+)$') { $BaseUrl = $Matches[1].Trim('"') }
    }
}
if (-not $BaseUrl) { $BaseUrl = "https://smircich.ddns.net" }

if (-not $Password) {
    $secure = Read-Host "Family password" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
}

function Invoke-JsonPost($Url, $Body, $Token) {
    $headers = @{ "Content-Type" = "application/json" }
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    return Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body ($Body | ConvertTo-Json)
}

function Invoke-JsonGet($Url, $Token) {
    $headers = @{}
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    return Invoke-RestMethod -Uri $Url -Method Get -Headers $headers
}

Write-Host ""
Write-Host "Logging in to $BaseUrl ..."

try {
    $login = Invoke-JsonPost "$BaseUrl/api/v1/auth/login" @{ password = $Password } $null
} catch {
    Write-Host "Login failed: $_" -ForegroundColor Red
    exit 1
}

$token = $login.token
Write-Host "Getting Google sign-in URL ..."

try {
    $oauth = Invoke-JsonGet "$BaseUrl/api/v1/calendars/oauth/start" $token
} catch {
    Write-Host "OAuth start failed: $_" -ForegroundColor Red
    exit 1
}

$url = $oauth.url

Write-Host ""
Write-Host "=========================================="
Write-Host " Open this URL and sign in as the person"
Write-Host " whose calendar you are linking."
Write-Host "=========================================="
Write-Host ""
Write-Host $url
Write-Host ""
Write-Host "Grant calendar read access when asked."
Write-Host 'Success page: "Calendar linked"'
Write-Host ""

$open = Read-Host "Open in browser now? [Y/n]"
if ($open -eq "" -or $open -match "^[Yy]") {
    Start-Process $url
}

Read-Host "Press Enter after completing sign-in in the browser"

Write-Host ""
Write-Host "Linked calendars:"
$calendars = Invoke-JsonGet "$BaseUrl/api/v1/calendars" $token
if (-not $calendars -or $calendars.Count -eq 0) {
    Write-Host "  (none yet)"
} else {
    foreach ($c in $calendars) {
        $synced = if ($c.last_synced_at) { "synced" } else { "waiting for sync" }
        Write-Host "  - $($c.nickname) ($($c.google_account_email)) - $synced"
    }
}

Write-Host ""
$again = Read-Host "Link another account? [y/N]"
if ($again -match "^[Yy]") {
    & $MyInvocation.MyCommand.Path -Password $Password -BaseUrl $BaseUrl
} else {
    Write-Host "Done. Events sync within about a minute."
}
