# W3-C look-dev measurement: average frame_ms (not capped fps) of the look-dev sandbox with the puppet's 50 enemies at
# 1080x1920 (rendered in a SubViewport of that size inside a 540x960 window: the screen is only 1080 pixels tall),
# vsync off, Engine.max_fps = 0, for each look at each quality tier. One Godot process at a time.
# Usage (idle machine, nothing else running):
#   powershell -NoProfile -ExecutionPolicy Bypass -File docs\reports\lookdev\measure.ps1 [-Seconds 26] [-Runs "stylised_plus:2:glow_off", ...]
# Each run logs a [PERF] line every 5 s (PerfHud); the first line (warm-up) is discarded, the others are averaged.
# Output: one table row per run, and build\lookdev_measure.csv.
param(
    [int]$Seconds = 26,
    [string[]]$Looks = @("current", "stylised", "stylised_plus"),
    [int[]]$Tiers = @(0, 1, 2),
    [string]$Extra = "",
    [string]$Tag = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $repo "tools\_common.ps1")
Use-CheckoutAppData "measure_appdata"
$csv = Join-Path $BuildRoot "lookdev_measure.csv"
if (-not (Test-Path $csv)) { "tag,look,tier,frames_lines,frame_ms,p95_ms,draws,prims,tick_ms" | Out-File -Encoding ascii $csv }
foreach ($tier in $Tiers) {
    foreach ($look in $Looks) {
        $godotArgs = @('--disable-vsync', '--resolution', '540x960', '--position', '0,0',
            'res://src/debug/look_dev_sandbox.tscn', '--', "--look=$look", "--quality=$tier", '--scenario=hold50',
            '--render-size=1080x1920', '--debug-perf', "--measure=$Seconds", '--mute')
        if ($Extra -ne "") { $godotArgs += ($Extra -split ' ') }
        $r = Invoke-Godot $godotArgs ($Seconds + 90)
        $lines = @($r.Output -split "`r?`n" | Where-Object { $_ -match '^\[PERF\]' })
        $info = @($r.Output -split "`r?`n" | Where-Object { $_ -match '^\[lookdev\]' }) | Select-Object -First 1
        $used = @($lines | Select-Object -Skip 1)
        if ($used.Count -eq 0) { Write-Host "NO PERF LINES for $look tier $tier"; continue }
        function Field($line, $name) { if ($line -match "$name=([\d.]+)") { return [double]$Matches[1] } else { return 0.0 } }
        $ms = ($used | ForEach-Object { Field $_ 'frame_ms' } | Measure-Object -Average).Average
        $p95 = ($used | ForEach-Object { Field $_ 'p95_ms' } | Measure-Object -Average).Average
        $draws = ($used | ForEach-Object { Field $_ 'draws' } | Measure-Object -Average).Average
        $prims = ($used | ForEach-Object { Field $_ 'prims' } | Measure-Object -Average).Average
        $tick = ($used | ForEach-Object { Field $_ 'tick_ms' } | Measure-Object -Average).Average
        $per = ($used | ForEach-Object { '{0:N2}' -f (Field $_ 'frame_ms') }) -join ' '
        "{0} {1} tier={2} lines={3} frame_ms={4:N2} p95={5:N2} draws={6:N0} prims={7:N0} tick={8:N2}  [{9}]" -f $Tag, $look, $tier, $used.Count, $ms, $p95, $draws, $prims, $tick, $per | Write-Host
        "{0},{1},{2},{3},{4:N3},{5:N3},{6:N0},{7:N0},{8:N3}" -f $Tag, $look, $tier, $used.Count, $ms, $p95, $draws, $prims, $tick | Out-File -Encoding ascii -Append $csv
        Start-Sleep -Seconds 3
    }
}
Write-Host "MEASURE DONE $csv"
