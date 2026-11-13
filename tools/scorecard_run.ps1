# Predictability scorecard wrapper (VARIETY_SPEC 14.2, GDD 8.4). Runs Godot headless on tools/scorecard_run.gd and
# judges by its output text. stdout is deterministic ("SCORECARD ..." lines, the verdict
# "SCORECARD: PASS|WARN|FAIL rows=.. pass=.. warn=.. fail=.. runs=.." last); TIMING and engine noise go to stderr.
# Exit 0 on PASS or WARN, 1 on FAIL (or no verdict line), 2 on a script error, bad arguments or unreadable content.
# Usage: .\tools\scorecard_run.ps1 [-Runs 30] [-Seed 1] [-Pool base|full] [-Jobs 1] [-Data res://data]
#   -Runs 30   the gate version; -Runs 200 is the full card (200 seeds x 8 policies, plus 3 extra runs of `balanced` per
#              seed for the route rows S14 and the pool row S15).
#   -Pool      the pool of the main runs: base = a profile with no unlock, full = every unlock of the content.
#   -Jobs n    play the card in n Godot processes at once (shards of the job list), then join their records in one more
#              process. The default 1 is a single process. Every shard only reads the project after the one import.
[CmdletBinding(PositionalBinding = $false)]
param(
    [int]$Runs = 30,
    [int]$Seed = 1,
    [string]$Pool = "base",
    [int]$Jobs = 1,
    [string]$Data = "res://data",
    [int]$TimeoutMin = 720,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Use-CheckoutAppData "sim_appdata"

if ($Pool -ne "base" -and $Pool -ne "full") { Write-Host "SCORECARD ERROR: -Pool must be base or full (got $Pool)"; exit 2 }
if ($Jobs -lt 1) { Write-Host "SCORECARD ERROR: -Jobs must be 1 or more"; exit 2 }

$ansi = "\x1b\[[0-9;]*[A-Za-z]"

# Import first so new class_name scripts are in the global class cache (fresh worktrees have no .godot yet).
$imp = Invoke-Godot @("--headless", "--import") -TimeoutSec 300
$impText = $imp.Output -replace $ansi, ""
$impBad = @($impText -split "`r?`n" | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' })
if ($impBad.Count -gt 0) {
    $impBad | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    Write-Host "SCORECARD FAILED (project import)"
    exit 2
}

# Compile probe: a tool script that does not compile leaves Godot idling forever, so find that out in seconds, not hours.
# A script that loads answers the unknown flag with an error line and quits.
try { $probe = Invoke-Godot @("--headless", "-s", "res://tools/scorecard_run.gd", "--", "--probe", "1") -TimeoutSec 300 } catch { $probe = $null }
if ($null -eq $probe -or ($probe.Output -replace $ansi, "") -cnotmatch 'SCORECARD ERROR: .*--probe') {
    Write-Host "SCORECARD FAILED (the tool script does not compile or load)"
    exit 2
}

$base = @("--headless", "-s", "res://tools/scorecard_run.gd", "--",
    "--runs", "$Runs", "--seed", "$Seed", "--pool", $Pool, "--data", $Data)
if ($Extra.Count -gt 0) { $base += $Extra }   # forwarded raw: the script rejects unknown flags itself

function Join-Shards {
    # Starts $Jobs Godot processes (one shard each), waits for all, returns the paths of their record files.
    $dir = Join-Path $BuildRoot "scorecard"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Get-ChildItem $dir -Filter "shard_*" -ErrorAction SilentlyContinue | Remove-Item -Force
    $exe = if (Test-Path $GodotNoConsole) { $GodotNoConsole } else { $Godot }
    $started = @()
    for ($i = 0; $i -lt $Jobs; $i++) {
        $out = (Join-Path $dir "shard_$i.jsonl") -replace '\\', '/'
        $argList = $base + @("--shard", "$i", "--shards", "$Jobs", "--out", $out)
        $argString = (@("--path", $RepoRoot) + $argList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
        $log = Join-Path $dir "shard_$i.log"
        $p = Start-Process -FilePath $exe -ArgumentList $argString -WorkingDirectory $RepoRoot -NoNewWindow -PassThru `
            -RedirectStandardOutput $log -RedirectStandardError (Join-Path $dir "shard_$i.err")
        $started += @{ Proc = $p; Log = $log; Out = $out; Index = $i }
    }
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    foreach ($s in $started) {
        $left = [int][Math]::Max(1, ($deadline - (Get-Date)).TotalMilliseconds)
        if (-not $s.Proc.WaitForExit($left)) {
            foreach ($t in $started) { & taskkill.exe /PID $t.Proc.Id /T /F 2>&1 | Out-Null }
            Write-Host "SCORECARD FAILED (timeout after $TimeoutMin min)"
            exit 2
        }
    }
    $files = @()
    foreach ($s in $started) {
        $text = (Get-Content -Raw $s.Log) -replace $ansi, ""
        if ($text -cmatch 'SCRIPT ERROR|Parse Error' -or $text -cnotmatch "SCORECARD shard $($s.Index)/$Jobs done") {
            Write-Host "SCORECARD FAILED (shard $($s.Index): see $($s.Log))"
            exit 2
        }
        $files += $s.Out
    }
    return $files
}

if ($Jobs -eq 1) {
    $r = Invoke-Godot $base -TimeoutSec ($TimeoutMin * 60)
} else {
    $files = Join-Shards
    $r = Invoke-Godot ($base + @("--report", ($files -join ","))) -TimeoutSec 600
}
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() })
foreach ($l in $lines) {
    # Only the deterministic result lines go to stdout; engine banner and TIMING go to stderr.
    if ($l -cmatch '^(SCORECARD|usage:|--runs )') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^SCORECARD ERROR:' })
if ($bad.Count -gt 0) { Write-Host "SCORECARD FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^SCORECARD ERROR:' }).Count -gt 0) { exit 2 }
$verdict = @($lines | Where-Object { $_ -cmatch '^SCORECARD: (PASS|WARN|FAIL) ' })
if ($verdict.Count -eq 0) { Write-Host "SCORECARD FAILED (no verdict line)"; exit 1 }
if ($verdict[-1] -cmatch '^SCORECARD: FAIL ') { exit 1 }
exit 0
