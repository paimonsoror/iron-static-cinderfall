# Headless whole-run sim runner wrapper. Runs Godot headless on tools/sim_run.gd and judges by its output text.
# stdout is deterministic (RUN lines, SIM VIOLATION lines, "SIM SUMMARY: runs=N victories=V defeats=D" last); the
# TIMING line and engine noise go to stderr, so two executions diff clean.
# Exit 0 every run finished and kept every invariant, 1 a run hit -MaxTicks or broke an invariant (or no summary),
# 2 script/parse error, bad arguments or unreadable content.
# Usage: .\tools\sim_run.ps1 [-Seed 1] [-Runs 20] [-Policy greedy|none|both] [-MaxTicks 60000]
#        [-DamageMult 1.0] [-StartScrap 0] [-Data res://data]
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Seed = 1,
    [int]$Runs = 20,
    [string]$Policy = "greedy",
    [int]$MaxTicks = 60000,
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
    Write-Host "SIM RUN FAILED (project import)"
    exit 2
}

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$argList = @("--headless", "-s", "res://tools/sim_run.gd", "--",
    "--runs", "$Runs", "--seed", "$Seed", "--policy", $Policy, "--max-ticks", "$MaxTicks",
    "--damage-mult", $DamageMult.ToString($inv), "--start-scrap", "$StartScrap", "--data", $Data)
if ($Extra.Count -gt 0) { $argList += $Extra }   # forwarded raw: the script rejects unknown flags itself
$r = Invoke-Godot $argList -TimeoutSec 1800
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() })
foreach ($l in $lines) {
    # Only the deterministic result lines go to stdout; engine banner and TIMING go to stderr.
    if ($l -cmatch '^(RUN |SIM |usage:|--runs )') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^SIM ERROR:' })
if ($bad.Count -gt 0) { Write-Host "SIM RUN FAILED (script error)"; exit 2 }
$hasSummary = @($lines | Where-Object { $_ -cmatch '^SIM SUMMARY: runs=\d+ victories=\d+ defeats=\d+$' }).Count -gt 0
$simErrors = @($lines | Where-Object { $_ -cmatch '^SIM ERROR:' })
$violations = @($lines | Where-Object { $_ -cmatch '^SIM VIOLATION ' })
if (-not $hasSummary) {
    if ($simErrors.Count -gt 0) { exit 2 }
    Write-Host "SIM RUN FAILED (no summary line)"
    exit 1
}
if ($simErrors.Count -gt 0 -or $violations.Count -gt 0) { exit 1 }
exit 0
