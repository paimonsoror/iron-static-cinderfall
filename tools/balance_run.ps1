# Balance runner wrapper: N seeds x {no purchases, greedy bot} against GDD 8.4. Runs Godot headless on
# tools/balance_run.gd and judges by its output text. stdout is deterministic ("BALANCE ..." lines, the verdict
# "BALANCE: PASS|WARN|FAIL ..." last); TIMING and engine noise go to stderr, so two executions diff clean.
# Exit 0 on PASS or WARN, 1 on FAIL (or no verdict line), 2 on a script error, bad arguments or unreadable content.
# Usage: .\tools\balance_run.ps1 [-Runs 20] [-Seed 1] [-MaxTicks 60000] [-DamageMult 1.0] [-StartScrap 0] [-Data res://data]
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Runs = 20,
    [int]$Seed = 1,
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
    Write-Host "BALANCE FAILED (project import)"
    exit 2
}

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$argList = @("--headless", "-s", "res://tools/balance_run.gd", "--",
    "--runs", "$Runs", "--seed", "$Seed", "--policy", "both", "--max-ticks", "$MaxTicks",
    "--damage-mult", $DamageMult.ToString($inv), "--start-scrap", "$StartScrap", "--data", $Data)
if ($Extra.Count -gt 0) { $argList += $Extra }   # forwarded raw: the script rejects unknown flags itself
$r = Invoke-Godot $argList -TimeoutSec 1800
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
