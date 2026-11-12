# W3-E environment cost measurement: average frame_ms of the look-dev sandbox (hold50, 1080x1920 SubViewport, vsync off,
# Engine.max_fps = 0) for the old yard (`--env=off`) and for every effect of the styled yard on its own, per quality tier.
# Every run takes C:\dev\tower-two-wt\measure.lock first (another agent measures on the same machine: the lock keeps the windows
# clean; a lock older than 25 minutes is stale), so a run only waits, it never overlaps. 2 interleaved passes over the cells.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File docs\reports\lookdev\measure_env.ps1 [-Seconds 26] [-Passes 2] [-Tag env] [-Cells "off:0,floor:0,..."]
# A cell is `name:tier`; names map to --env flags below. Output: one row per run, build\env_measure.csv.
param(
    [int]$Seconds = 26,
    [int]$Passes = 2,
    [string]$Tag = "env",
    [string[]]$Cells = @()
)
$ErrorActionPreference = "Stop"
$repo = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $repo "tools\_common.ps1")
Use-CheckoutAppData "measure_appdata"
$csv = Join-Path $BuildRoot "env_measure.csv"
if (-not (Test-Path $csv)) { "tag,pass,cell,tier,frame_ms,p95_ms,draws,prims" | Out-File -Encoding ascii $csv }
$flags = @{
    "cur"      = "--look=current"
    "off"      = "--look=stylised --env=off"
    "floor"    = "--look=stylised --env=only:floor"
    "wet"      = "--look=stylised --env=only:floor,wet"
    "ripples"  = "--look=stylised --env=only:floor,wet,ripples"
    "props"    = "--look=stylised --env=only:props"
    "propsh"   = "--look=stylised --env=only:props,prop_shader"
    "reactor"  = "--look=stylised --env=only:reactor,spill"
    "spill"    = "--look=stylised --env=only:spill"
    "vignette" = "--look=stylised --env=only:vignette"
    "grade"    = "--look=stylised --env=only:grade"
    "glow"     = "--look=stylised --env=only:spill,glow"
    "glowf"    = "--look=stylised --env=only:spill --glow=1"
    "all"      = "--look=stylised"
    "all_noglow" = "--look=stylised --env=no:glow"
}
if ($Cells.Count -eq 0) {
    $Cells = @()
    foreach ($t in 0, 1, 2) { foreach ($n in "off", "floor", "props", "spill", "vignette", "grade", "all") { $Cells += "{0}:{1}" -f $n, $t } }
    foreach ($t in 1, 2) { $Cells += "wet:$t" }
    $Cells += "propsh:1"; $Cells += "propsh:2"; foreach ($t in 0, 1, 2) { $Cells += "glowf:$t" }; $Cells += "ripples:2"; $Cells += "reactor:2"; $Cells += "all_noglow:2"
}
$lock = "C:\dev\tower-two-wt\measure.lock"
function Get-Lock {
    $waited = 0
    while ($true) {
        if (Test-Path $lock) {
            if (((Get-Date) - (Get-Item $lock).LastWriteTime).TotalMinutes -gt 25) { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
        }
        try { New-Item -ItemType File $lock -ErrorAction Stop | Out-Null; return } catch { }
        Start-Sleep -Seconds 30
        $waited += 30
        if ($waited -gt 1200) { throw "measure.lock held for 20 minutes" }
    }
}
function Field($line, $name) { if ($line -match "$name=([\d.]+)") { return [double]$Matches[1] } else { return 0.0 } }
for ($pass = 1; $pass -le $Passes; $pass++) {
    foreach ($cell in $Cells) {
        $p = $cell -split ":"
        $name = $p[0]; $tier = $p[1]
        $godotArgs = @('--disable-vsync', '--resolution', '540x960', '--position', '0,0', 'res://src/debug/look_dev_sandbox.tscn', '--') +
            ($flags[$name] -split ' ') + @("--quality=$tier", '--scenario=hold50', '--render-size=1080x1920', '--debug-perf', "--measure=$Seconds", '--mute')
        Get-Lock
        try { $r = Invoke-Godot $godotArgs ($Seconds + 90) } finally { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
        $lines = @($r.Output -split "`r?`n" | Where-Object { $_ -match '^\[PERF\]' })
        $used = @($lines | Select-Object -Skip 1)
        if ($used.Count -eq 0) { Write-Host "NO PERF LINES for $cell"; continue }
        $ms = ($used | ForEach-Object { Field $_ 'frame_ms' } | Measure-Object -Average).Average
        $p95 = ($used | ForEach-Object { Field $_ 'p95_ms' } | Measure-Object -Average).Average
        $draws = ($used | ForEach-Object { Field $_ 'draws' } | Measure-Object -Average).Average
        $prims = ($used | ForEach-Object { Field $_ 'prims' } | Measure-Object -Average).Average
        "{0} pass={1} {2} tier={3} frame_ms={4:N2} p95={5:N2} draws={6:N0} prims={7:N0}" -f $Tag, $pass, $name, $tier, $ms, $p95, $draws, $prims | Write-Host
        "{0},{1},{2},{3},{4:N3},{5:N3},{6:N0},{7:N0}" -f $Tag, $pass, $name, $tier, $ms, $p95, $draws, $prims | Out-File -Encoding ascii -Append $csv
        Start-Sleep -Seconds 2
    }
}
Write-Host "MEASURE ENV DONE $csv"
