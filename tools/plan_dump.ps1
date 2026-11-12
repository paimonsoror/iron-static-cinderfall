# Run-plan printer wrapper. Runs Godot headless on tools/plan_dump.gd and judges by its output text.
# stdout is a pure function of the seed and the data: "PLAN ..." lines (bosses, both options of every wave with their
# groups and elites, events, drum points) and, last, "PLAN SUMMARY: seed=.. waves=.. options=.. events=.. plan_hash=..".
# Engine noise goes to stderr, so two executions diff clean.
# Exit 0 the plan was printed, 1 there is no generated plan to print ("PLAN UNAVAILABLE: ...": the plan is still the
# legacy stub of the scaffold until task V2-A lands, or -Data is the legacy five-wave content), 2 script/parse error,
# bad arguments or unreadable content.
# Usage: .\tools\plan_dump.ps1 [-Seed 1] [-Data res://data]
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Seed = 1,
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
    Write-Host "PLAN DUMP FAILED (project import)"
    exit 2
}

$argList = @("--headless", "-s", "res://tools/plan_dump.gd", "--", "--seed", "$Seed", "--data", $Data)
if ($Extra.Count -gt 0) { $argList += $Extra }   # forwarded raw: the script rejects unknown flags itself
$r = Invoke-Godot $argList -TimeoutSec 600
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() })
foreach ($l in $lines) {
    # Only the plan lines go to stdout; the engine banner and boot lines go to stderr.
    if ($l -cmatch '^(PLAN |usage:)') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^PLAN ERROR:' })
if ($bad.Count -gt 0) { Write-Host "PLAN DUMP FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^PLAN ERROR:' }).Count -gt 0) { exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^PLAN UNAVAILABLE:' }).Count -gt 0) { exit 1 }
if (@($lines | Where-Object { $_ -cmatch '^PLAN SUMMARY: ' }).Count -eq 0) { Write-Host "PLAN DUMP FAILED (no summary line)"; exit 1 }
exit 0
