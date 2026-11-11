# Full gate: import + compile (warnings as errors) + layer lint + tests.
# Pass = exit 0 and the last line "CHECK OK". Usage: .\tools\check.ps1 [-Path res://tests/unit/core] [-SkipTests]
param(
    [string[]]$Path = @(),
    [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Use-CheckoutAppData "test_appdata"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$py = (Find-Python) -split ' '
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }

function Step([string]$Title, [string[]]$PyArgs) {
    Write-Host "== $Title"
    $lines = New-Object System.Collections.Generic.List[string]
    & $py[0] @pyRest -u @PyArgs | ForEach-Object { $s = "$_"; Write-Host $s; $lines.Add($s) }
    return @{ Code = $LASTEXITCODE; Lines = $lines }
}

$r = Step "layer lint" @("$PSScriptRoot\lint_layers.py")
if ($r.Code -ne 0) { Write-Host "CHECK FAILED: layer lint (exit $($r.Code))"; exit 1 }

$r = Step "compile gate" @("$PSScriptRoot\compile_gate.py", "--godot", $Godot, "--project", $RepoRoot)
if ($r.Code -ne 0) { Write-Host "CHECK FAILED: compile gate (exit $($r.Code))"; exit 1 }

if (-not $SkipTests) {
    $targs = @("$PSScriptRoot\test_runner.py", "--godot", $Godot, "--project", $RepoRoot)
    foreach ($p in (Split-PathList $Path)) { $targs += @("--path", $p) }
    $r = Step "tests" $targs
    $summary = $r.Lines | Where-Object { $_ -match '^TEST SUMMARY: ' } | Select-Object -Last 1
    if ($r.Code -ne 0 -or -not $summary) {
        Write-Host "CHECK FAILED: tests (exit $($r.Code))"; exit 1
    }
    if ($summary -notmatch 'tests=([1-9]\d*) failures=0 errors=0') {
        Write-Host "CHECK FAILED: unexpected summary: $summary"; exit 1
    }
    Write-Host "tests run: $($Matches[1])"
}
Write-Host "CHECK OK"
exit 0
