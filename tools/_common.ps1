# Dot-source from other scripts: . "$PSScriptRoot\_common.ps1"
# Provides $RepoRoot, $BuildRoot, $Godot, $GodotNoConsole, Invoke-Godot, Find-Python, Use-CheckoutAppData,
# Split-PathList, Write-Utf8NoBom.
#
# Concurrency rules (several agents run these tools at once, each in its own git worktree):
#  - $RepoRoot comes from this file's own location, never from the current directory or a fixed path;
#  - every log, report and temp file goes under $BuildRoot (the checkout's own build/);
#  - APPDATA is redirected per checkout (Use-CheckoutAppData), so Godot's editor settings, shader caches and
#    user:// are never shared between checkouts;
#  - a process is only ever killed through the tree of the process this script started (never by image name).

$RepoRoot = Split-Path $PSScriptRoot -Parent

# Godot path: docs and tools/GODOT_VERSION pin 4.7.2. CINDERFALL_GODOT overrides the console exe path.
$Godot = "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$GodotVersionFile = Join-Path $PSScriptRoot "GODOT_VERSION"
$pinned = (Get-Content -Raw $GodotVersionFile).Trim()
$pinnedMajorMinor = ($pinned -split '\.')[0..1] -join '.'
if ($env:CINDERFALL_GODOT) { $Godot = $env:CINDERFALL_GODOT }
elseif ($Godot -notmatch "\\godot\\$([regex]::Escape($pinnedMajorMinor))(\.\d+)?\\") {
    throw "tools/GODOT_VERSION ($pinned) major.minor does not match Godot path: $Godot"
}

# build/ holds logs, reports, screenshots and nested projects; .gdignore keeps Godot from scanning it.
$BuildRoot = Join-Path $RepoRoot "build"
if (-not (Test-Path $BuildRoot)) { New-Item -ItemType Directory -Path $BuildRoot | Out-Null }
$gdIgnore = Join-Path $BuildRoot ".gdignore"
if (-not (Test-Path $gdIgnore)) { [System.IO.File]::WriteAllText($gdIgnore, "") }

# The plain (GUI-subsystem) exe exits cleanly when its output is piped; the console wrapper can hang after the
# real Godot has exited. $Godot (console) stays for the Python tools, which pipe it with a timeout and tree kill.
$GodotNoConsole = $Godot -replace '_console\.exe$', '.exe'

# Per-checkout APPDATA: Godot on Windows keeps editor settings and user:// under %APPDATA%\Godot. Only affects this
# process tree. The game's real save location on the player's machine is unchanged.
function Use-CheckoutAppData {
    param([string]$Name = "test_appdata")
    $dir = Join-Path $BuildRoot $Name
    New-Item -ItemType Directory -Force $dir | Out-Null
    $env:APPDATA = $dir
}

# Starts the non-console Godot with stdout and stderr captured, waits with a timeout and, on timeout, kills the
# whole tree of the process it started. Returns @{ ExitCode; Output }. Godot's exit code is not a verdict.
function Invoke-Godot {
    param([string[]]$ArgList, [int]$TimeoutSec = 300)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = if (Test-Path $GodotNoConsole) { $GodotNoConsole } else { $Godot }
    $all = @('--path', $RepoRoot) + $ArgList
    $psi.Arguments = ($all | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = $RepoRoot
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    try {
        [void]$p.Start()
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null
            try { $p.Kill() } catch { }
            throw "Godot timed out after $TimeoutSec s: $($psi.Arguments)"
        }
        $p.WaitForExit()
        $text = $outTask.Result + $errTask.Result
        return @{ ExitCode = $p.ExitCode; Output = $text }
    }
    finally {
        $p.Dispose()
    }
}

function Find-Python {
    # Returns a command string for Python >= 3.10 (e.g. "py -3.12" or "python").
    $candidates = @('py -3.12', 'py -3.11', 'py -3.10', 'python', 'python3')
    foreach ($c in $candidates) {
        $parts = $c -split ' '
        if (-not (Get-Command $parts[0] -ErrorAction SilentlyContinue)) { continue }
        try {
            $rest = @(); if ($parts.Count -gt 1) { $rest = $parts[1..($parts.Count - 1)] }
            $v = (& $parts[0] @rest --version 2>&1 | Out-String).Trim()
        } catch { continue }
        if ($v -match 'Python (\d+)\.(\d+)') {
            if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 10)) { return $c }
        }
    }
    throw "Python >= 3.10 not found. Install Python 3.12 (python.org) and ensure 'py' or 'python' is on PATH."
}

# -Path a,b arrives as ONE string "a,b" when the script is started with powershell -File (for example from Git
# Bash); from a PowerShell prompt it arrives as an array. Accept both.
function Split-PathList {
    param([string[]]$Values)
    $out = @()
    foreach ($v in $Values) { foreach ($p in ($v -split ',')) { if ($p.Trim()) { $out += $p.Trim() } } }
    return $out
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

$env:PYTHONIOENCODING = "utf-8"
