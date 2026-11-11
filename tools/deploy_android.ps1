<#
.SYNOPSIS  Export a debug APK headlessly, install it on the running emulator/device, launch it, print the Godot logcat.
.EXAMPLE   powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\deploy_android.ps1 -ProjectPath C:\dev\tower-two -Package com.normalexception.games.cinderfall.dev -Preset Cinderfall -LogSeconds 40
.EXAMPLE   ... deploy_android.ps1 -ProjectPath C:\dev\tower-two -Serial R5CT12345AB     # a USB / wireless phone while the emulator also runs
Exports with the REAL Godot editor settings (%APPDATA%\Godot: SDK, JDK and debug keystore paths); the per-checkout
APPDATA redirect of the test tools is deliberately not used here. No keystore is read or printed.
Run it from a normal drive path (not \\wsl$) and never twice at once (adb and log collisions).
Ends with "== RUNNING (pid n)" and exit 0, or "== NOT RUNNING ..." and exit 1. Any earlier failure throws (exit 1).
Files written under <ProjectPath>\build\: <Package>.debug.apk, logs\deploy_export.log, logs\deploy_logcat.txt.
#>
param(
    [string]$ProjectPath = (Split-Path $PSScriptRoot -Parent),
    [string]$Package = "com.normalexception.games.cinderfall.dev",
    [string]$Preset = "Cinderfall",
    [int]$LogSeconds = 8,
    [string]$Serial = ""
)
$ErrorActionPreference = "Continue"   # native stderr (adb notices, Godot progress) must not abort under PS 5.1; failures throw explicitly
. "$PSScriptRoot\_common.ps1"          # $Godot (pinned console exe), $GodotNoConsole, Invoke-Godot
$ProjectPath = (Resolve-Path $ProjectPath).Path
$RepoRoot = $ProjectPath               # Invoke-Godot runs against the project we were asked to export
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = "$sdk\platform-tools\adb.exe"

$buildDir = Join-Path $ProjectPath "build"
$logDir = Join-Path $buildDir "logs"
New-Item -ItemType Directory -Force $logDir | Out-Null
if (-not (Test-Path (Join-Path $buildDir ".gdignore"))) { [System.IO.File]::WriteAllText((Join-Path $buildDir ".gdignore"), "") }
$apk = Join-Path $buildDir "$Package.debug.apk"
if (Test-Path $apk) { Remove-Item $apk -Force }   # never install a stale APK after a failed export

$sel = @(); if ($Serial) { $sel = @('-s', $Serial) }
function Adb { param([string[]]$A) $o = & $adb @sel @A 2>&1; return @($o | ForEach-Object { "$_" }) }

# ---- export -------------------------------------------------------------------------------------------------
Write-Host "== Exporting $Preset -> $apk"
$imp = Invoke-Godot -ArgList @('--headless', '--import') -TimeoutSec 600
$exp = Invoke-Godot -ArgList @('--headless', '--export-debug', $Preset, $apk) -TimeoutSec 900
$expLog = Join-Path $logDir "deploy_export.log"
Write-Utf8NoBom $expLog ("--- import (exit $($imp.ExitCode)) ---`n" + $imp.Output + "`n--- export (exit $($exp.ExitCode)) ---`n" + $exp.Output)
if (-not (Test-Path $apk)) { Write-Host $exp.Output; throw "Export failed (no APK produced). Full log: $expLog" }
$expLines = $exp.Output -split "`r?`n"
$expLines | Where-Object { $_ -match 'ERROR|Parse Error|SCRIPT ERROR|Signed' } | ForEach-Object { Write-Host $_.Trim() }
if ($expLines | Where-Object { $_ -match 'Parse Error|SCRIPT ERROR' }) { throw "Script errors during export. Full log: $expLog" }
Write-Host ("== APK {0:N1} MB  sha256 {1}" -f ((Get-Item $apk).Length / 1MB), (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower())

# Guard for A07: the runtime JSON must be inside the APK (include_filter), else the device fails to load content.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk)
try { $dataJson = @($zip.Entries | Where-Object { $_.FullName -match 'data/.*\.json$' } | ForEach-Object { $_.FullName }) } finally { $zip.Dispose() }
Write-Host "== Data files in APK: $($dataJson.Count)"
if ($dataJson.Count -eq 0) { throw "No data/*.json inside the APK: check include_filter in export_presets.cfg" }

# ---- device -------------------------------------------------------------------------------------------------
# Godot's export may restart the adb server; make sure it is back and a device is ready.
$null = Adb @('start-server')
if (-not $Serial) {
    $online = @(& $adb devices 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match '\sdevice\s*$' })
    if ($online.Count -gt 1) { throw "More than one device online; pass -Serial <id>:`n$($online -join "`n")" }
}
$tries = 0
while (-not ((Adb @('get-state')) -join '').Trim().Equals('device')) {
    if (++$tries -gt 40) { throw "No device/emulator online. Run tools\run_emulator.ps1 or connect a phone." }
    Start-Sleep -Seconds 3
}
Write-Host "== Installing"
$inst = Adb @('install', '-r', $apk)
$inst | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not (($inst -join ' ') -match 'Success')) {
    throw "adb install failed (a different signing key? try: adb uninstall $Package)"
}
$null = Adb @('logcat', '-c')
$null = Adb @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')   # a locked or dozing screen stops the activity right after launch
$null = Adb @('shell', 'wm', 'dismiss-keyguard')
Write-Host "== Launching $Package"
$null = Adb @('shell', 'monkey', '-p', $Package, '-c', 'android.intent.category.LAUNCHER', '1')
Write-Host "== Godot log for $LogSeconds s"
Start-Sleep -Seconds $LogSeconds
$godotLog = Adb @('logcat', '-d', '-s', 'godot:V', 'GodotApp:V')
$godotLog | ForEach-Object { Write-Host $_ }
Write-Utf8NoBom (Join-Path $logDir "deploy_logcat.txt") ((Adb @('logcat', '-d')) -join "`n")
$pidText = ((Adb @('shell', 'pidof', $Package)) -join '').Trim()
if ($pidText -match '^\d+') { Write-Host "== RUNNING (pid $pidText)"; exit 0 }
Write-Host "== NOT RUNNING - check: adb logcat -d | findstr $Package   (full log: $logDir\deploy_logcat.txt)"
exit 1
