<#
.SYNOPSIS  Boot the tower_phone emulator (WHPX, -gpu mode via -Gpu) and wait until Android finished booting.
.DESCRIPTION
Prints the emulator serial when Android reports sys.boot_completed=1. Safe to call when the emulator is already up
(it just waits for it). Works with a physical phone attached too: the wait is done against the emulator's own serial.
Exit 0 = booted, 1 = timeout or the emulator process died.
.PARAMETER Avd        AVD name (default tower_phone: Pixel 6 profile, 1080x2400, x86_64, android-35 google_apis_playstore).
.PARAMETER Gpu        Emulator -gpu mode (default host). host | swangle_indirect | angle_indirect | swiftshader_indirect | auto.
                      Changing it needs a stopped emulator (adb emu kill) plus -ColdBoot. Mobile/Vulkan fallback order for
                      a failing render is host, then swangle_indirect (docs/reports/BUILD_INSTRUCTIONS.md).
.PARAMETER ColdBoot   Skip the quickboot snapshot (use after a crash, a config or -Gpu change, or when adb shows "offline").
.PARAMETER PublicDns  Opt-in: start with -dns-server 8.8.8.8,1.1.1.1 (not needed by Cinderfall: the build is offline).
.PARAMETER EmuLog     Optional file that receives the emulator's own stdout and stderr (gpu and Vulkan diagnostics).
.PARAMETER TimeoutSec Give up after this many seconds (default 300).
#>
param(
    [string]$Avd = "tower_phone",
    [ValidateSet('host', 'swangle_indirect', 'angle_indirect', 'swiftshader_indirect', 'auto')][string]$Gpu = "host",
    [switch]$ColdBoot,
    [switch]$PublicDns,
    [string]$EmuLog = "",
    [int]$TimeoutSec = 300
)
$ErrorActionPreference = "Stop"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = "$sdk\platform-tools\adb.exe"
$emu = "$sdk\emulator\emulator.exe"
if (-not (Test-Path $emu)) { throw "emulator.exe not found at $emu (set ANDROID_HOME)" }

# adb prints daemon-start notices on stderr; keep them from becoming terminating errors under PS 5.1.
function Adb { param([string[]]$A) $o = & $adb @A 2>&1; return @($o | ForEach-Object { "$_" }) }

# Serial of an emulator that is online ("emulator-5554"), or "" when none is.
function Get-EmulatorSerial {
    foreach ($l in (Adb @('devices'))) { if ($l -match '^(emulator-\d+)\s+device\s*$') { return $Matches[1] } }
    return ''
}
function Get-Boot([string]$Serial) {
    try { return ((Adb @('-s', $Serial, 'shell', 'getprop', 'sys.boot_completed')) -join '').Trim() } catch { return '' }
}

$null = Adb @('start-server')
$serial = Get-EmulatorSerial
$proc = $null
if ($serial) {
    Write-Host "An emulator is already running ($serial)."
} else {
    # An emulator process for this AVD may exist while adb has not seen it yet (just started) or sees it "offline".
    $running = @(Get-CimInstance Win32_Process -Filter "Name='emulator.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "-avd\s+$([regex]::Escape($Avd))(\s|$)" })
    if ($running.Count -gt 0) {
        Write-Host "emulator.exe for $Avd is already running (pid $($running[0].ProcessId)) but adb does not list it as online."
        Write-Host "Waiting for it. If this times out: adb emu kill, then run this script again with -ColdBoot."
    } else {
        $emuArgs = @('-avd', $Avd, '-gpu', $Gpu, '-no-boot-anim', '-no-audio')
        if ($ColdBoot) { $emuArgs += '-no-snapshot-load' }
        if ($PublicDns) { $emuArgs += @('-dns-server', '8.8.8.8,1.1.1.1') }
        Write-Host "Starting $Avd gpu=$Gpu $(if($ColdBoot){'(cold boot)'})$(if($PublicDns){' (public DNS)'})..."
        $sp = @{ FilePath = $emu; ArgumentList = $emuArgs; WindowStyle = 'Minimized'; PassThru = $true }
        if ($EmuLog) {
            $sp['RedirectStandardOutput'] = $EmuLog
            $sp['RedirectStandardError'] = "$EmuLog.err"
        }
        $proc = Start-Process @sp
    }
}

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($true) {
    $serial = Get-EmulatorSerial
    if ($serial -and (Get-Boot $serial) -eq '1') { break }
    if ($proc -and $proc.HasExited -and $proc.ExitCode -ne 0 -and -not $serial) {
        Write-Host "emulator.exe exited with code $($proc.ExitCode) before Android came up. Run it by hand to see why:"
        Write-Host "  $emu -avd $Avd -gpu $Gpu"
        exit 1
    }
    if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) {
        Write-Host "Emulator did not finish booting in $TimeoutSec s (adb devices: $((Adb @('devices')) -join ' | '))"
        exit 1
    }
    Start-Sleep -Seconds 3
}
Write-Host ("Emulator {0} booted in {1:N0}s (gpu={2}). Tip: wait ~20-25s after a COLD boot before launching apps." -f $serial, $sw.Elapsed.TotalSeconds, $Gpu)
exit 0
