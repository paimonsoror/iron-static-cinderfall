# Desktop screenshot of one scene through the REAL renderer (opens a window briefly; not headless).
# Pass = exit 0, PNG exists and is not blank, last line "CAPTURE OK <path>".
# Usage: .\tools\capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out C:\...\build\shots\x.png [-Size 1080x2400] [-Frames 90]
param(
    [Parameter(Mandatory = $true)][string]$Scene,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Size = "1080x2400",
    [int]$Frames = 90,
    [int]$TimeoutSec = 180
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Use-CheckoutAppData "capture_appdata"

if ($Size -notmatch '^\d+x\d+$') { Write-Host "CAPTURE FAILED: -Size must look like 1080x2400"; exit 2 }
$outFull = [System.IO.Path]::GetFullPath($Out)
New-Item -ItemType Directory -Force (Split-Path $outFull -Parent) | Out-Null
if (Test-Path $outFull) { Remove-Item $outFull -Force }

# Make sure the checkout is imported (fresh worktrees have no .godot yet).
$imp = Invoke-Godot @('--headless', '--import') 300
$impErrors = @($imp.Output -split "`r?`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|ERROR:' })
if ($impErrors.Count -gt 0) { $impErrors | Select-Object -First 10 | ForEach-Object { Write-Host $_ }; Write-Host "CAPTURE FAILED: import errors"; exit 2 }

$r = Invoke-Godot @('--', "--capture-scene=$Scene", "--capture-out=$outFull", "--capture-size=$Size", "--capture-frames=$Frames", '--mute') $TimeoutSec
$logPath = Join-Path $BuildRoot "capture_last.txt"
Write-Utf8NoBom $logPath $r.Output
$lines = @($r.Output -split "`r?`n")
$lines | Where-Object { $_ -match 'Vulkan|OpenGL|capture renderer=|Forward|Mobile|content ok' } | ForEach-Object { Write-Host $_ }
$bad = @($lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|ERROR:' })
if ($bad.Count -gt 0) { $bad | Select-Object -First 10 | ForEach-Object { Write-Host $_ }; Write-Host "CAPTURE FAILED: errors in output (log: $logPath)"; exit 2 }
if (-not ($lines | Where-Object { $_ -match '^CAPTURE SAVED ' })) { Write-Host "CAPTURE FAILED: no CAPTURE SAVED line (log: $logPath)"; exit 1 }
if (-not (Test-Path $outFull) -or (Get-Item $outFull).Length -lt 2000) { Write-Host "CAPTURE FAILED: PNG missing or too small"; exit 1 }
if (-not ($r.Output -match 'renderer=mobile/vulkan')) {
    Write-Host "CAPTURE WARNING: log does not show renderer=mobile/vulkan (see $logPath)"
}
Write-Host "CAPTURE OK $outFull"
exit 0
