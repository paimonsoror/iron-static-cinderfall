"""Run Godot as a child process safely (shared by test_runner.py, compile_gate.py). Stdlib only.

Rules: never judge by Godot's exit code; always a timeout; on timeout kill the WHOLE tree of the process we
started (the console wrapper starts the real Godot as a child) and nothing else. Never kill by image name:
other checkouts run Godot at the same time.
"""
from __future__ import annotations

import os
import re
import signal
import subprocess

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def kill_tree(pid: int) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True, check=False)
    else:
        try:
            os.killpg(pid, signal.SIGKILL)
        except OSError:
            pass


def run_godot(godot: str, project, args: list[str], timeout: int, headless: bool = True) -> tuple[int, str]:
    """Returns (exit code, ANSI-stripped stdout+stderr). Exit code 124 on timeout."""
    cmd = [godot] + (["--headless"] if headless else []) + ["--path", str(project)] + args
    proc = subprocess.Popen(
        cmd,
        cwd=str(project),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        start_new_session=(os.name != "nt"),
    )
    try:
        raw, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_tree(proc.pid)
        proc.kill()
        raw, _ = proc.communicate()
        return 124, strip_ansi(raw.decode("utf-8", "replace")) + "\nTOOL ERROR: Godot timed out\n"
    return proc.returncode, strip_ansi(raw.decode("utf-8", "replace"))
