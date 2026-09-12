$ErrorActionPreference = 'Stop'

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Updating Game Ping Booster Service & Profiles" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$svcName = 'GamePingBooster'
Write-Host "1. Stopping $svcName service..." -ForegroundColor Yellow
try {
    Stop-Service $svcName -Force -ErrorAction SilentlyContinue
} catch {}
Start-Sleep -Seconds 2

# Ensure any existing process is stopped
$procs = Get-Process gpb-service, GamePingBooster -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "Terminating active processes..." -ForegroundColor Yellow
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$svcPublish = Join-Path $repoRoot "client\src\GamePingBooster.Service\bin\Release\net9.0-windows\win-x64\publish"
$appPublish = Join-Path $repoRoot "client\src\GamePingBooster.App\bin\Release\net9.0-windows\win-x64\publish"
$profilesDir = Join-Path $repoRoot "profiles"

$progFiles = 'C:\Program Files\Game Ping Booster'
$progData  = 'C:\ProgramData\GamePingBooster'

# 2. Update Program Files
if (Test-Path $progFiles) {
    Write-Host "2. Copying binaries to '$progFiles'..." -ForegroundColor Cyan
    Copy-Item "$svcPublish\gpb-service.exe" "$progFiles\gpb-service.exe" -Force
    Copy-Item "$appPublish\GamePingBooster.exe" "$progFiles\GamePingBooster.exe" -Force
    if (Test-Path "$svcPublish\wintun.dll") {
        Copy-Item "$svcPublish\wintun.dll" "$progFiles\wintun.dll" -Force
    }
    Copy-Item "$appPublish\*.dll" "$progFiles\" -Force

    $destProfiles = Join-Path $progFiles "profiles"
    if (-not (Test-Path $destProfiles)) {
        New-Item -ItemType Directory -Path $destProfiles -Force | Out-Null
    }
    Copy-Item "$profilesDir\*.json" $destProfiles -Force
    Write-Host "   Program Files updated successfully." -ForegroundColor Green
}

# 3. Update ProgramData
if (-not (Test-Path $progData)) {
    New-Item -ItemType Directory -Path $progData -Force | Out-Null
}

Write-Host "3. Updating configuration in '$progData'..." -ForegroundColor Cyan
$cfgFile = Join-Path $progData "config.json"
$existingPsk = "xNQAPOr3Zi2rjc6cQrxa5Atu6q23Mik4JkOk8/st9Wo="
$existingRelays = @("74.81.54.201:51820")

if (Test-Path $cfgFile) {
    try {
        $raw = Get-Content $cfgFile -Raw | ConvertFrom-Json
        if ($raw.psk) { $existingPsk = $raw.psk }
        if ($raw.relayEndpoints -and $raw.relayEndpoints.Count -gt 0) {
            $existingRelays = @($raw.relayEndpoints)
        }
    } catch {}
}

$newConfig = [ordered]@{
    profileUrl     = $null
    profilePath    = "profiles"
    psk            = $existingPsk
    licenceUrl     = ""
    defaultRelayId = $null
    relayEndpoints = $existingRelays
    defaultGameId  = "auto"
    adapterName    = "Game Ping Booster"
    routeWithoutGame = $false
}
$newConfig | ConvertTo-Json -Depth 5 | Set-Content $cfgFile -Encoding utf8

$dataProfiles = Join-Path $progData "profiles"
if (-not (Test-Path $dataProfiles)) {
    New-Item -ItemType Directory -Path $dataProfiles -Force | Out-Null
}
Copy-Item "$profilesDir\*.json" $dataProfiles -Force

# 4. Start service
Write-Host "4. Starting $svcName service..." -ForegroundColor Green
Start-Service $svcName
Start-Sleep -Seconds 2

$status = Get-Service $svcName
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Service '$svcName' is now: $($status.Status)" -ForegroundColor Green
Write-Host "Multi-game support (Auto-detect, CS2, PUBG) active!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Start-Sleep -Seconds 2
