# Balance runner wrapper: N seeds x {no purchases, greedy bot} against GDD 8.4. Runs Godot headless on
# tools/balance_run.gd and judges by its output text. stdout is deterministic ("BALANCE ..." lines, the verdict
# "BALANCE: PASS|WARN|FAIL ..." last); TIMING and engine noise go to stderr, so two executions diff clean.
# Exit 0 on PASS or WARN, 1 on FAIL (or no verdict line), 2 on a script error, bad arguments or unreadable content.
# On the shipped variety data it also plays `balanced` and reads the redefined targets (GDD 8.4: S4, S6, S7, S16, S17);
# -Data res://tests/fixtures/data_baseline runs the legacy fixture against the old targets.
# Usage: .\tools\balance_run.ps1 [-Runs 20] [-Seed 1] [-MaxTicks 0] [-DamageMult 1.0] [-StartScrap 0] [-Data res://data]
# -MaxTicks 0 = the default of the content: 60000 for the legacy waves, 108000 for a generated run.
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Runs = 20,
    [int]$Seed = 1,
    [int]$MaxTicks = 0,
    [double]$DamageMult = 1.0,
    [int]$StartScrap = 0,
    [string]$Data = "res://data",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Use-CheckoutAppData "sim_appdata"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"

# Import first so new class_name scripts are in the global class cache (fresh worktrees have no .godot yet).
$imp = Invoke-Godot @("--headless", "--import") -TimeoutSec 300
$impText = $imp.Output -replace $ansi, ""
$impBad = @($impText -split "`r?`n" | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' })
if ($impBad.Count -gt 0) {
    $impBad | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    Write-Host "BALANCE FAILED (project import)"
    exit 2
}

# Compile probe: a tool script that does not compile leaves Godot idling forever, so find that out in seconds, not hours.
# A script that loads answers the unknown flag with an error line and quits.
try { $probe = Invoke-Godot @("--headless", "-s", "res://tools/balance_run.gd", "--", "--probe", "1") -TimeoutSec 300 } catch { $probe = $null }
if ($null -eq $probe -or ($probe.Output -replace $ansi, "") -cnotmatch 'BALANCE ERROR: .*--probe') {
    Write-Host "BALANCE FAILED (the tool script does not compile or load)"
    exit 2
}

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$argList = @("--headless", "-s", "res://tools/balance_run.gd", "--",
    "--runs", "$Runs", "--seed", "$Seed", "--policy", "both",
    "--damage-mult", $DamageMult.ToString($inv), "--start-scrap", "$StartScrap", "--data", $Data)
if ($MaxTicks -gt 0) { $argList += @("--max-ticks", "$MaxTicks") }
if ($Extra.Count -gt 0) { $argList += $Extra }   # forwarded raw: the script rejects unknown flags itself
$r = Invoke-Godot $argList -TimeoutSec 7200
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() })
foreach ($l in $lines) {
    # Only the deterministic result lines go to stdout; engine banner and TIMING go to stderr.
    if ($l -cmatch '^(BALANCE|usage:|--runs )') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^BALANCE ERROR:' })
if ($bad.Count -gt 0) { Write-Host "BALANCE FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^BALANCE ERROR:' }).Count -gt 0) { exit 2 }
$verdict = @($lines | Where-Object { $_ -cmatch '^BALANCE: (PASS|WARN|FAIL) ' })
if ($verdict.Count -eq 0) { Write-Host "BALANCE FAILED (no verdict line)"; exit 1 }
if ($verdict[-1] -cmatch '^BALANCE: FAIL ') { exit 1 }
exit 0
