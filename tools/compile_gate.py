#!/usr/bin/env python3
"""Compile gate: imports the project, then loads every .gd and .tscn through tools/compile_check.gd in chunks.

Warnings are errors (project.godot), so a warning shows up as a parse error here. Judges by output text, never
by exit code (headless Godot can exit 0 on failure). Stdlib only.
Usage: compile_gate.py --godot <console exe> [--project <dir>]
Exit 0 pass, 1 compile errors, 4 tool failure.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

from godot_proc import run_godot

BAD_IMPORT = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
BAD_COMPILE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:|Warning treated as error|Failed to instantiate|COMPILE FAIL")
CHUNK = 60
TOOLS = Path(__file__).resolve().parent


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--godot", required=True)
    ap.add_argument("--project", default=str(TOOLS.parent))
    ap.add_argument("--timeout", type=int, default=300)
    a = ap.parse_args()
    project = Path(a.project).resolve()
    if not Path(a.godot).is_file():
        print("TOOL ERROR: Godot not found: " + a.godot)
        return 4
    listing = subprocess.run(
        [sys.executable, str(TOOLS / "lint_layers.py"), "--list-gd"], capture_output=True, text=True, check=False
    )
    files = [f.strip() for f in listing.stdout.splitlines() if f.strip()]
    if listing.returncode != 0 or not files:
        print("TOOL ERROR: lint_layers.py --list-gd gave no files")
        return 4

    bad: list[str] = []
    _, imp = run_godot(a.godot, project, ["--import"], a.timeout)
    bad += [ln for ln in imp.splitlines() if BAD_IMPORT.search(ln)]
    for i in range(0, len(files), CHUNK):
        chunk = ["res://" + f for f in files[i : i + CHUNK]]
        _, text = run_godot(a.godot, project, ["-s", "res://tools/compile_check.gd", "--"] + chunk, a.timeout)
        bad += [ln for ln in text.splitlines() if BAD_COMPILE.search(ln)]
        if f"COMPILE SUMMARY: checked={len(chunk)} " not in text:
            bad.append("compile_check did not finish (no summary)")
    if bad:
        print(f"[FAIL] compile (warnings-as-errors) ({len(files)} files)")
        for b in bad[:30]:
            print("    " + b)
        return 1
    print(f"[PASS] compile (warnings-as-errors) ({len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
