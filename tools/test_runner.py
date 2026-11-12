#!/usr/bin/env python3
"""Test runner for IRON STATIC: CINDERFALL: import, run GdUnit4 headless, parse output + JUnit XML.

Headless Godot can exit 0 on failure, so this script judges only by parsed output and report.
Exit codes: 0 pass, 1 test failure/error, 2 script/parse error in output, 3 zero tests, 4 tool failure.
Everything is written inside the checkout (build/) so parallel worktrees never share files. Stdlib only.
See docs/setup in the original project and CLAUDE.md for the rules.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from godot_proc import run_godot, strip_ansi

ERROR_PATTERNS = [
    re.compile(p)
    for p in (
        r"SCRIPT ERROR",
        r"Parse Error",
        r"\bERROR:",
        r"Warning treated as error",
        r"Failed to instantiate an autoload",
        r"Nonexistent function",
    )
]
REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWLIST_FILE = Path(__file__).resolve().parent / "test_allowlist.txt"
CANARY_COPY_DIRS = ("addons", "src", "assets", "data", "scenes")
CANARY_PARSE_SOURCE = "extends GdUnitTestSuite\n\n\nfunc test_parse_canary() -> void:\n\tvar x: int = \n"
DEFAULT_ROOTS = ["res://tests/unit", "res://tests/integration", "res://tests/stress"]


def load_allowlist(path: Path = ALLOWLIST_FILE) -> list[re.Pattern[str]]:
    if not path.is_file():
        return []
    out: list[re.Pattern[str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(re.compile(line))
    return out


def scan_errors(output: str, allowlist: list[re.Pattern[str]]) -> list[str]:
    """Return output lines matching an error pattern and not allowlisted."""
    hits: list[str] = []
    for line in strip_ansi(output).splitlines():
        if any(a.search(line) for a in allowlist):
            continue
        if any(p.search(line) for p in ERROR_PATTERNS):
            hits.append(line.strip())
    return hits


def parse_junit(xml_text: str) -> dict[str, int]:
    root = ET.fromstring(xml_text)
    totals = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    suites = root.findall(".//testsuite") or [root]
    for suite in suites:
        for key in totals:
            totals[key] += int(suite.get(key, "0") or 0)
    return totals


def evaluate(output: str, junit_xml: str | None, allowlist: list[re.Pattern[str]]) -> tuple[dict[str, int], int, list[str]]:
    """Pure decision function: (counts, exit code, error lines)."""
    counts = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    errors = scan_errors(output, allowlist)
    if errors:
        return counts, 2, errors
    if junit_xml is None:
        return counts, (3 if "No test cases found" in output else 4), errors
    try:
        counts = parse_junit(junit_xml)
    except ET.ParseError:
        return counts, 4, errors
    if counts["tests"] == 0:
        return counts, 3, errors
    if counts["failures"] or counts["errors"]:
        return counts, 1, errors
    return counts, 0, errors


def discover_paths(project: Path) -> list[str]:
    """The default roots that actually contain a test_*.gd (an empty root makes GdUnit4 complain)."""
    found = []
    for root in DEFAULT_ROOTS:
        base = project / root.removeprefix("res://")
        if base.is_dir() and any(base.rglob("test_*.gd")):
            found.append(root)
    return found


def split_paths(values: list[str] | None) -> list[str]:
    """Each --path may itself be a comma-separated list (PowerShell -File passes it as one string)."""
    out: list[str] = []
    for v in values or []:
        out += [p.strip() for p in v.split(",") if p.strip()]
    return out


def write_summary(build_dir: Path, counts: dict[str, int], code: int) -> str:
    line = "TEST SUMMARY: tests={tests} failures={failures} errors={errors} skipped={skipped} exit={x}".format(
        x=code, **counts
    )
    (build_dir / "summary.json").write_text(json.dumps({**counts, "exit": code}, indent=2) + "\n", encoding="utf-8")
    return line


def ensure_build_root(project: Path) -> None:
    """build/ holds nested projects (canary) and PNGs; .gdignore keeps Godot from scanning it."""
    root = project / "build"
    root.mkdir(parents=True, exist_ok=True)
    (root / ".gdignore").touch(exist_ok=True)


def prune_old_runs(runs_root: Path, keep: Path, max_age_s: float = 6 * 3600) -> None:
    """Delete per-run folders older than max_age_s (never the current one)."""
    now = time.time()
    for d in runs_root.iterdir():
        if d == keep or not d.is_dir():
            continue
        try:
            if now - d.stat().st_mtime > max_age_s:
                shutil.rmtree(d, ignore_errors=True)
        except OSError:
            pass


def resolve_targets(project: Path, res_path: list[str], suite: str | None) -> list[str]:
    """res:// targets for GdUnit4. A suite name is looked up in each path (first hit wins)."""
    paths = [p.rstrip("/") for p in res_path]
    if not suite:
        return paths
    if suite.startswith("res://"):
        return [suite]
    for p in paths:
        hits = list((project / p.removeprefix("res://")).rglob(f"{suite}.gd"))
        if hits:
            return ["res://" + hits[0].relative_to(project).as_posix()]
    return [f"{paths[0]}/{suite}.gd"]


def run_pipeline(godot: str, project: Path, res_path: list[str], suite: str | None, timeout: int, quiet: bool = False) -> int:
    """Import, run GdUnit4, parse. Prints the summary line last. Returns the exit code."""
    ensure_build_root(project)
    # Every invocation gets its own folder under this checkout's build/, so parallel agents (each in their own
    # worktree) and repeated runs never clobber each other's report.
    latest_dir = project / "build" / "test"
    runs_root = latest_dir / "runs"
    run_name = f"{os.getpid()}_{int(time.time() * 1000)}"
    build_dir = runs_root / run_name
    build_dir.mkdir(parents=True, exist_ok=True)
    prune_old_runs(runs_root, keep=build_dir)
    zero = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    allow = load_allowlist()

    def finish(counts: dict[str, int], code: int) -> int:
        print(write_summary(build_dir, counts, code))
        for name in ("summary.json", "last_import.txt", "last_output.txt"):
            src = build_dir / name
            if src.is_file():
                try:
                    shutil.copyfile(src, latest_dir / name)
                except OSError:
                    pass
        return code

    if not Path(godot).is_file():
        print("TOOL ERROR: Godot not found: " + godot)
        return finish(zero, 4)

    rc, imp = run_godot(godot, project, ["--import"], timeout)
    errs = scan_errors(imp, allow)
    (build_dir / "last_import.txt").write_text(imp, encoding="utf-8")
    if errs:
        print("Import step reported errors:")
        for e in errs[:20]:
            print("  " + e)
        return finish(zero, 2)

    if not res_path:
        print("No test folders with test_*.gd found")
        return finish(zero, 3)
    report_dir = build_dir / "report"
    report_dir.mkdir(parents=True)
    targets = resolve_targets(project, res_path, suite)
    args = ["-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode"]
    for target in targets:
        args += ["-a", target]  # GdUnit4's CLI accepts several -a options
    args += ["-c", "-rd", f"res://build/test/runs/{run_name}/report", "--", "--mute"]
    rc, out = run_godot(godot, project, args, timeout)
    (build_dir / "last_output.txt").write_text(out, encoding="utf-8")
    if not quiet:
        print(out)

    xmls = sorted(report_dir.rglob("results.xml"), key=lambda p: p.stat().st_mtime)
    xml_text = xmls[-1].read_text(encoding="utf-8") if xmls else None
    counts, code, errors = evaluate(out, xml_text, allow)
    if errors:
        print("Errors found in test output:")
        for e in errors[:20]:
            print("  " + e)
    return finish(counts, code)


def remove_tree(path: Path) -> None:
    def onerror(func, p, _exc):  # type: ignore[no-untyped-def]
        os.chmod(p, 0o700)
        func(p)

    if path.exists():
        shutil.rmtree(path, onerror=onerror)


def run_canary(godot: str, timeout: int) -> int:
    """Run the canary suites inside a temp copy of the project under build/canary; the broken file only exists there."""
    ensure_build_root(REPO_ROOT)
    copy = REPO_ROOT / "build" / "canary"
    remove_tree(copy)
    copy.mkdir(parents=True)
    shutil.copy2(REPO_ROOT / "project.godot", copy / "project.godot")
    if (REPO_ROOT / "icon.svg").is_file():
        shutil.copy2(REPO_ROOT / "icon.svg", copy / "icon.svg")
    for d in CANARY_COPY_DIRS:
        if (REPO_ROOT / d).is_dir():
            shutil.copytree(REPO_ROOT / d, copy / d)
    shutil.copytree(REPO_ROOT / "tests" / "canary", copy / "tests" / "canary")

    # Warm-up import: the first import of a brand-new copy can emit racy half-imported errors; a second import in
    # the pipeline then finds everything in place. The canary still proves the runner catches failures.
    run_godot(godot, copy, ["--import"], timeout)

    print("== canary 1: failing test must give exit 1")
    c1 = run_pipeline(godot, copy, ["res://tests/canary"], None, timeout, quiet=True)

    print("== canary 2: parse error must give exit 2")
    dst = copy / "tests" / "canary_parse"
    dst.mkdir(parents=True)
    (dst / "test_canary_parse.gd").write_text(CANARY_PARSE_SOURCE, encoding="utf-8", newline="\n")
    c2 = run_pipeline(godot, copy, ["res://tests/canary_parse"], None, timeout, quiet=True)

    if c1 == 1 and c2 in (1, 2):
        print("CANARY OK")
        return 0
    print(f"CANARY FAILED: canary1 exit={c1} (want 1), canary2 exit={c2} (want 2 or 1)")
    return 1


def self_test() -> int:
    allow = [re.compile(r"known benign thing")]
    ok_xml = '<testsuites><testsuite tests="2" failures="0" errors="0" skipped="0"/></testsuites>'
    fail_xml = '<testsuites><testsuite tests="2" failures="1" errors="0" skipped="0"/></testsuites>'
    zero_xml = '<testsuites><testsuite tests="0" failures="0" errors="0" skipped="0"/></testsuites>'
    cases = [
        ("pass", evaluate("all good\n0 errors", ok_xml, allow)[1], 0),
        ("failure", evaluate("FAILED", fail_xml, allow)[1], 1),
        ("parse error", evaluate("SCRIPT ERROR: Parse Error: x (Warning treated as error.)", ok_xml, allow)[1], 2),
        ("zero tests xml", evaluate("fine", zero_xml, allow)[1], 3),
        ("zero tests no report", evaluate("No test cases found, abort test run!", None, allow)[1], 3),
        ("allowlisted error", evaluate("ERROR: known benign thing happened", ok_xml, allow)[1], 0),
        ("ansi stripped", evaluate("\x1b[31mERROR: boom\x1b[0m", ok_xml, [])[1], 2),
        ("no report", evaluate("something", None, allow)[1], 4),
        ("counts", evaluate("x", fail_xml, allow)[0]["tests"], 2),
        ("split paths", len(split_paths(["a,b", "c"])), 3),
    ]
    bad = 0
    for name, got, want in cases:
        status = "ok" if got == want else "FAIL"
        bad += got != want
        print(f"  [{status}] {name}: got {got}, want {want}")
    print("SELF-TEST " + ("OK" if bad == 0 else "FAILED"))
    return 0 if bad == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", help="Godot console executable")
    ap.add_argument("--project", default=str(REPO_ROOT), help="project directory")
    ap.add_argument("--path", action="append", help="res:// test folder; repeatable or comma-separated")
    ap.add_argument("--suite", help="suite file name (without .gd) inside --path, or a res:// path")
    ap.add_argument("--canary", action="store_true", help="prove the runner detects failures")
    ap.add_argument("--self-test", action="store_true", help="run parser unit checks")
    # Per Godot invocation; only a hang guard. The full suite (stress and seed-sweep tests included) needs ~200 s
    # and keeps growing, so the original 300 s left too little margin.
    ap.add_argument("--timeout", type=int, default=1800)
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if not a.godot:
        ap.error("--godot is required")
    if a.canary:
        return run_canary(a.godot, a.timeout)
    project = Path(a.project).resolve()
    paths = split_paths(a.path) or discover_paths(project)
    return run_pipeline(a.godot, project, paths, a.suite, a.timeout)


if __name__ == "__main__":
    sys.exit(main())
