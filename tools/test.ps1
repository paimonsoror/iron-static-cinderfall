# Test wrapper: import, run GdUnit4, parse output. Exit 0 pass, 1 test failure, 2 script/parse error,
# 3 zero tests, 4 tool failure. Last output line: TEST SUMMARY: ... (or CANARY OK for -Canary).
# Usage: .\tools\test.ps1 [-Path res://tests/unit/core,res://tests/unit/shared] [-Suite test_formulas] [-Canary]
# With no -Path it runs tests/unit, tests/integration and tests/stress (those that contain tests).
param(
    [string[]]$Path = @(),
    [string]$Suite = "",
    [switch]$Canary
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Use-CheckoutAppData "test_appdata"

$py = (Find-Python) -split ' '
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
$argList = @("$PSScriptRoot\test_runner.py", "--godot", $Godot, "--project", $RepoRoot)
if ($Canary) { $argList += "--canary" }
else {
    foreach ($p in (Split-PathList $Path)) { $argList += @("--path", $p) }
    if ($Suite) { $argList += @("--suite", $Suite) }
}
& $py[0] @pyRest -u @argList
exit $LASTEXITCODE
