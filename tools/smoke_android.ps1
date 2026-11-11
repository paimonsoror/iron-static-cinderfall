<#
.SYNOPSIS  Emulator/phone smoke test: deploy (optional), check process and logcat, take a screenshot and check it.
.DESCRIPTION
Checks, in order (the first failure prints "SMOKE FAIL: <reason>" and exits 1):
  1. the app process is alive (pidof);
  2. the logcat of that process has no "SCRIPT ERROR", "FATAL", "ERROR: Content:" or "Force quitting" line, no crash-buffer or
     ANR entry for the package;
  3. the log contains "content ok" (data/*.json loaded on the device) and "boot ok" (Game.boot finished);
  4. the boot line "game boot ... renderer=<method>/<driver>" equals -ExpectRenderer (default mobile/vulkan, the owner
     decision) and no OpenGL fallback line is present; pass -ExpectRenderer "" to skip; any "ERROR: ... Vulkan ..." line
     (for example "Couldn't present to Vulkan queue") fails too unless -AllowVulkanErrors is given;
  5. the screenshot is portrait, not blank, and has pixels near amber (#F1A34A) or cyan (#39C9DB) (visual_tokens palette);
  6. optional -MinFps: parses "[PERF] fps=.. min=.. frame_ms=.. p95_ms=.. tick_ms=.. enemies=.. draws=.. prims=.. vid_mb=.."
     lines (needs --debug-perf baked into the build) after a PerfWarmup-second warm-up; the lowest per-line fps average
     must reach MinFps.
Prints "SMOKE OK" (exit 0) when everything passed.
.EXAMPLE   powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\smoke_android.ps1 -SkipDeploy
.EXAMPLE   ... smoke_android.ps1 -SkipDeploy -WaitSeconds 40 -Soak 180 -MinFps 30 -Serial R5CT12345AB
.PARAMETER Serial       adb serial (needed when an emulator and a phone are both online).
.PARAMETER Soak         keep the app running that many seconds after the wait, re-checking pid and crash patterns every 15 s.
.PARAMETER ImagePath    run only the screenshot checks on that PNG (no device needed; self-test).
.PARAMETER ExpectColor  one or more "#RRGGBB" (comma separated is fine); the check passes when ANY of them is present.
#>
param(
    [string]$Package = "com.normalexception.games.cinderfall.dev",
    [string]$Preset = "Cinderfall",
    [int]$WaitSeconds = 35,
    [switch]$SkipDeploy,
    [string]$Serial = "",
    [string[]]$ExpectColor = @("#F1A34A", "#39C9DB"),
    [string]$ExpectRenderer = "mobile/vulkan",
    [switch]$AllowVulkanErrors,
    [double]$MinFps = 0,
    [int]$Soak = 0,
    [int]$PerfWarmup = 40,
    [double]$BlankThreshold = 0.999,
    [string]$ImagePath = "",
    [int]$GridSize = 256,
    [double]$MinColorShare = 0.0005,
    [int]$ColorDistance = 60
)
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\_common.ps1"   # $RepoRoot, $BuildRoot
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$Adb = "$sdk\platform-tools\adb.exe"

function Fail([string]$why) {
    Write-Host "SMOKE FAIL: $why"
    exit 1
}

$sel = @(); if ($Serial) { $sel = @('-s', $Serial) }

# adb writes daemon-start messages to stderr; never let that abort the script.
function Run-Adb { param([string[]]$A) $o = & $Adb @sel @A 2>&1; return @($o | ForEach-Object { "$_" }) }

# Engine/script errors the Log autoload and Godot print (case-sensitive on purpose), plus a process kill.
$AppErrorPattern = 'SCRIPT ERROR|FATAL|ERROR: Content:|Force quitting|\sE\sAndroidRuntime'

# Lines that prove the package crashed or hung, from the crash buffer and from system_server.
function Get-SystemFaults {
    $f = @()
    $f += @(Run-Adb @('logcat', '-d', '-b', 'crash') | Where-Object { $_ -match [regex]::Escape($Package) })
    $f += @(Run-Adb @('logcat', '-d') | Where-Object { $_ -cmatch ('ANR in ' + [regex]::Escape($Package)) -or $_ -cmatch ('Process: ' + [regex]::Escape($Package)) })
    return $f
}

# Colour statistics of a PNG on a GridSize x GridSize sample grid.
function Get-ShotStats([string]$Path, [string[]]$Colors) {
    Add-Type -AssemblyName System.Drawing
    $targets = @()
    foreach ($c in $Colors) {
        foreach ($part in ($c -split ',')) {
            $hex = $part.Trim().TrimStart('#')
            if ($hex.Length -ne 6) { continue }
            $targets += , @([Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16), "#$($hex.ToUpper())", 0)
        }
    }
    $bmp = New-Object System.Drawing.Bitmap($Path)
    try {
        $w = $bmp.Width; $h = $bmp.Height
        $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
        $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $stride = $data.Stride
        $bytes = New-Object byte[] ($stride * $h)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $bmp.UnlockBits($data)
    }
    finally { $bmp.Dispose() }
    $counts = @{}
    $total = 0
    $maxD2 = $ColorDistance * $ColorDistance
    for ($iy = 0; $iy -lt $GridSize; $iy++) {
        $y = [int][Math]::Floor(($iy + 0.5) * $h / $GridSize)
        for ($ix = 0; $ix -lt $GridSize; $ix++) {
            $x = [int][Math]::Floor(($ix + 0.5) * $w / $GridSize)
            $i = $y * $stride + $x * 4
            $b = [int]$bytes[$i]; $g = [int]$bytes[$i + 1]; $r = [int]$bytes[$i + 2]
            $key = ($r * 65536) + ($g * 256) + $b
            $counts[$key] = 1 + [int]$counts[$key]
            $total++
            foreach ($t in $targets) {
                $d2 = ($r - $t[0]) * ($r - $t[0]) + ($g - $t[1]) * ($g - $t[1]) + ($b - $t[2]) * ($b - $t[2])
                if ($d2 -le $maxD2) { $t[4]++ }
            }
        }
    }
    $maxCount = ($counts.Values | Measure-Object -Maximum).Maximum
    return @{ Width = $w; Height = $h; Total = $total; Distinct = $counts.Count; DominantShare = $maxCount / $total; Targets = $targets }
}

if (-not $ImagePath) {
    if (-not $SkipDeploy) {
        $deploy = Join-Path $PSScriptRoot "deploy_android.ps1"
        $depArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $deploy, '-ProjectPath', $RepoRoot,
            '-Package', $Package, '-Preset', $Preset, '-LogSeconds', '5')
        if ($Serial) { $depArgs += @('-Serial', $Serial) }
        $dout = & powershell.exe @depArgs 2>&1 | ForEach-Object { "$_" }
        $dout | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { Fail "deploy failed (exit $LASTEXITCODE)" }
    }

    Write-Host "== Waiting $WaitSeconds s"
    Start-Sleep -Seconds $WaitSeconds

    $null = Run-Adb @('start-server')
    $pidText = ((Run-Adb @('shell', 'pidof', $Package)) -join '').Trim()
    if (-not $pidText -or $pidText -notmatch '^\d+') { Fail "process not running" }
    $pidText = ($pidText -split '\s+')[0]
    Write-Host "== Process running (pid $pidText)"

    if ($Soak -gt 0) {
        Write-Host "== Soak $Soak s (check every 15 s)"
        $t0 = Get-Date
        while (((Get-Date) - $t0).TotalSeconds -lt $Soak) {
            Start-Sleep -Seconds ([Math]::Min(15, [Math]::Max(1, [int]($Soak - ((Get-Date) - $t0).TotalSeconds))))
            $p2 = (((Run-Adb @('shell', 'pidof', $Package)) -join '').Trim() -split '\s+')[0]
            if (-not $p2 -or $p2 -notmatch '^\d+') { Fail ("process died during soak after {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds) }
            if ($p2 -ne $pidText) { Fail "process restarted during soak (pid $pidText -> $p2)" }
            $cb = @(Run-Adb @('logcat', '-d', "--pid=$pidText") | Where-Object { $_ -cmatch $AppErrorPattern })
            $cb += @(Get-SystemFaults)
            if ($cb.Count -gt 0) { Write-Host $cb[0]; Fail "crash pattern in log during soak: $($cb[0].Trim())" }
            Write-Host ("   t={0,4:N0} s alive pid {1}" -f ((Get-Date) - $t0).TotalSeconds, $p2)
        }
    }

    # ---- log scan (only this process: system and monkey lines must not fail the test) ---------------------------
    $logLines = @(Run-Adb @('logcat', '-d', "--pid=$pidText"))
    if ($logLines.Count -lt 5) { $logLines = @(Run-Adb @('logcat', '-d')) }   # --pid unsupported or buffer empty: whole log
    $bad = @($logLines | Where-Object { $_ -cmatch $AppErrorPattern })
    $bad += @(Get-SystemFaults)
    if ($bad.Count -gt 0) {
        $bad | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
        Fail "log contains errors ($($bad.Count) lines, first: $($bad[0].Trim()))"
    }
    Write-Host "== Log clean ($($logLines.Count) lines scanned)"

    if (-not ($logLines | Where-Object { $_ -match 'content ok' })) { Fail "log has no 'content ok' (data/*.json did not load on the device)" }
    if (-not ($logLines | Where-Object { $_ -match 'boot ok' })) { Fail "log has no 'boot ok' (Game.boot did not finish; log buffer rotated?)" }
    Write-Host "== 'content ok' and 'boot ok' present"

    $bootLine = $logLines | Where-Object { $_ -match 'game boot version=\S+ renderer=\S+' } | Select-Object -First 1
    if ($bootLine) { Write-Host "== $(($bootLine -replace '^.*?(game boot)', '$1').Trim())" }
    $gpuLine = $logLines | Where-Object { $_ -match 'Vulkan \d|OpenGL API|gpu adapter=' }
    $gpuLine | Select-Object -First 3 | ForEach-Object { Write-Host "== $(($_ -replace '^.*?:\s', '').Trim())" }
    if ($ExpectRenderer) {
        if (-not $bootLine) { Fail "no 'game boot ... renderer=' line in the log" }
        $null = $bootLine -match 'renderer=(\S+)'
        $renderer = $Matches[1]
        if ($renderer -ne $ExpectRenderer) { Fail "renderer is '$renderer', expected '$ExpectRenderer' (fallback counts as a failure)" }
        if ($ExpectRenderer -match 'vulkan') {
            $fb = @($logLines | Where-Object { $_ -match 'OpenGL API|OpenGL ES|[Ff]alling back' })
            if ($fb.Count -gt 0) { Write-Host $fb[0]; Fail "OpenGL fallback line in the log: $($fb[0].Trim())" }
        }
        Write-Host "== Renderer $renderer as expected$(if ($ExpectRenderer -match 'vulkan') { ', no OpenGL fallback' })"
    }
    # Vulkan errors (for example "Couldn't present to Vulkan queue") mean the 3D scene is not reaching the screen.
    $vkErrors = @($logLines | Where-Object { $_ -match 'ERROR: .*(Vulkan|VkResult|vkQueue)' })
    if ($vkErrors.Count -gt 0 -and -not $AllowVulkanErrors) {
        $vkErrors | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
        Fail "Vulkan errors in the log ($($vkErrors.Count) lines, first: $(($vkErrors[0] -replace '^.*?ERROR:', 'ERROR:').Trim())); see docs/reports/BUILD_INSTRUCTIONS.md section 5"
    }
    $engineErrors = @($logLines | Where-Object { $_ -match '\sE\sgodot\s' })
    if ($engineErrors.Count -gt 0) {
        Write-Host "== NOTE: $($engineErrors.Count) error-level godot log lines (not a failure); first: $($engineErrors[0].Trim())"
    }
}

# ---- screenshot --------------------------------------------------------------------------------------------
if ($ImagePath) {
    $shot = $ImagePath
    if (-not (Test-Path $shot)) { Fail "image not found: $shot" }
} else {
    # cmd.exe from C:\ because UNC working directories break redirection
    $outDir = Join-Path $BuildRoot "smoke"
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $shot = Join-Path $outDir "$stamp.png"
    $selStr = ''; if ($Serial) { $selStr = "-s $Serial " }
    cmd.exe /c "cd /d C:\ && `"$Adb`" $($selStr)exec-out screencap -p > `"$shot`"" 2>&1 | Out-Null
    # Multi-display devices (foldables) print a text warning ahead of the PNG: capture each display id and keep the
    # largest valid PNG (an inactive display is tiny or fails).
    $isPng = $false
    if (Test-Path $shot) { $hb = [System.IO.File]::ReadAllBytes($shot) | Select-Object -First 4; $isPng = ($hb.Count -ge 4 -and $hb[1] -eq 0x50) }
    if (-not $isPng) {
        $ids = @(Run-Adb @('shell', 'dumpsys SurfaceFlinger --display-id') | ForEach-Object { if ($_ -match '^Display (\d+)') { $Matches[1] } })
        $bestLen = 0
        foreach ($id in $ids) {
            $cand = Join-Path $outDir "${stamp}_d$id.png"
            cmd.exe /c "cd /d C:\ && `"$Adb`" $($selStr)exec-out screencap -d $id -p > `"$cand`"" 2>&1 | Out-Null
            if ((Test-Path $cand) -and (Get-Item $cand).Length -gt $bestLen) {
                $cb = [System.IO.File]::ReadAllBytes($cand) | Select-Object -First 4
                if ($cb.Count -ge 4 -and $cb[1] -eq 0x50) { $bestLen = (Get-Item $cand).Length; Copy-Item $cand $shot -Force }
            }
        }
    }
    if (-not (Test-Path $shot) -or (Get-Item $shot).Length -lt 1000) { Fail "screenshot failed" }
    Copy-Item $shot (Join-Path $outDir "latest.png") -Force
    Write-Host "== Screenshot $shot"
}

$st = Get-ShotStats $shot $ExpectColor
Write-Host ("== Screenshot {0}x{1}; dominant color share {2:P1} of {3} samples, {4} distinct colors" -f $st.Width, $st.Height, $st.DominantShare, $st.Total, $st.Distinct)
if ($st.DominantShare -gt $BlankThreshold) { Fail ("screenshot is blank ({0:P1} of samples are one color)" -f $st.DominantShare) }
if ($st.Height -le $st.Width) { Fail "screenshot is not portrait ($($st.Width)x$($st.Height))" }
$colorFail = ""
if ($st.Targets.Count -gt 0) {
    $need = [Math]::Max(1, [int][Math]::Ceiling($MinColorShare * $st.Total))
    $found = $false
    foreach ($t in $st.Targets) {
        Write-Host ("== Samples within {0} of {1}: {2} of {3} (need {4})" -f $ColorDistance, $t[3], $t[4], $st.Total, $need)
        if ($t[4] -ge $need) { $found = $true }
    }
    if (-not $found) { $colorFail = "none of the expected colors ($(($st.Targets | ForEach-Object { $_[3] }) -join ', ')) found in the screenshot" }
}
if ($ImagePath) {
    if ($colorFail) { Fail $colorFail }
    Write-Host "SMOKE OK (image only)"
    exit 0
}

# ---- optional fps gate -------------------------------------------------------------------------------------
if ($MinFps -gt 0) {
    $ep = @(Run-Adb @('logcat', '-d', '-v', 'epoch', "--pid=$pidText"))
    $perf = @()
    foreach ($l in $ep) {
        if ($l -match '^\s*(\d+\.\d+)\s.*\[PERF\]\s+(.*)$') {
            $kv = @{}
            foreach ($m in [regex]::Matches($Matches[2], '(\w+)=([\d.]+)')) { $kv[$m.Groups[1].Value] = [double]$m.Groups[2].Value }
            if (-not $kv.ContainsKey('fps')) { continue }
            $perf += [pscustomobject]@{
                T = [double]$l.Trim().Split(' ')[0]; Fps = $kv['fps']; Min = $kv['min']; FrameMs = $kv['frame_ms']; P95Ms = $kv['p95_ms']
                TickMs = $kv['tick_ms']; Enemies = [int]$kv['enemies']; Draws = [int]$kv['draws']; VidMb = $kv['vid_mb']
            }
        }
    }
    if ($perf.Count -eq 0) { Fail "no [PERF] lines in logcat (build needs --debug-perf in the preset's command_line/extra_args)" }
    # Lines are 5 s apart; the first appears about 5 s after launch.
    $cut = $perf[0].T - 5 + $PerfWarmup
    $use = @($perf | Where-Object { $_.T -ge $cut })
    if ($use.Count -eq 0) { Fail "no [PERF] lines after the $PerfWarmup s warm-up ($($perf.Count) lines total); wait longer" }
    $i = 0
    foreach ($u in $use) {
        $i++
        Write-Host ("   perf {0,3}: fps={1,6:N1} min={2,6:N1} frame_ms={3,6:N2} p95_ms={4,6:N2} tick_ms={5,6:N2} enemies={6} draws={7} vid_mb={8:N1}" -f $i, $u.Fps, $u.Min, $u.FrameMs, $u.P95Ms, $u.TickMs, $u.Enemies, $u.Draws, $u.VidMb)
    }
    $lowest = ($use | Measure-Object -Property Fps -Minimum).Minimum
    Write-Host ("== PERF samples after warm-up: {0}, lowest fps average {1:N1} (MinFps {2})" -f $use.Count, $lowest, $MinFps)
    if ($lowest -lt $MinFps) { Fail ("fps {0:N1} below MinFps {1}" -f $lowest, $MinFps) }
}

if ($colorFail) { Fail $colorFail }  # reported after the fps check so both results are printed
Write-Host "SMOKE OK"
exit 0
