#!/usr/bin/env python3
"""Layer lint and file hygiene for IRON STATIC: CINDERFALL (ARCH 2). Stdlib only.

Checks: layer rules (forbidden tokens and cross-layer class references), UTF-8 without BOM, LF endings,
tab indentation in .gd, 400-line cap for src/**/*.gd.
`--list-gd` prints every .gd and .tscn the compile gate must load (res:// relative paths).
Exit 0 pass, 1 violations, 4 tool failure. Run with `py -3.12 tools/lint_layers.py` (not -I: it is path-independent).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".godot", "addons", "build", "docs", "__pycache__", "android", ".venv"}
MAX_LINES = 400
AUTOLOAD_WORDS = r"\b(Log|Events|Content|Save|Game|Sfx)\."
SIM_FORBIDDEN = [
    (r"^\s*extends\s+Node\b", "extends Node"),
    (r"\bEngine\.", "Engine."),
    (r"\bOS\.", "OS."),
    (r"\bTime\.", "Time."),
    (r"\bInput\b", "Input"),
    (r"\bget_tree\b", "get_tree"),
    (r"(?<![.\w])randf\(", "randf("),
    (r"(?<![.\w])randi\(", "randi("),
    (r"(?<![.\w])randomize\(", "randomize("),
    (AUTOLOAD_WORDS, "autoload name"),
]
SHARED_FORBIDDEN = [
    (r"^\s*extends\s+Node\b", "extends Node"),
    (AUTOLOAD_WORDS, "autoload name"),
    (r"(?<![.\w])randf\(", "randf("),
    (r"(?<![.\w])randi\(", "randi("),
    (r"\bTime\.", "Time."),
    (r"\bOS\.", "OS."),
]
# Classes the UI may never touch (it talks to the sim only through RunApi).
UI_FORBIDDEN_CLASSES = {
    "SimWorld", "EnemyStore", "TurretStore", "WardenState", "AbilityState", "NavState", "CombatState",
    "PhaseState", "SimCommand", "SimConfig", "SimEvents",
}
# Classes any downstream layer may use even though they live in src/core.
CORE_LIBS = {"Strings", "RendererInfo"}
# Allowed class layers per layer (None = unrestricted).
ALLOWED = {
    "shared": {"shared"},
    "defs": {"shared", "defs"},
    "sim": {"shared", "defs", "sim"},
    "content": {"shared", "defs", "content"},
    "save": {"shared", "defs", "save"},
    "view": {"shared", "defs", "sim", "view"},
    "audio": {"shared", "defs", "audio"},
}
VIEW_WRITE_PATTERNS = [
    (r"\b_?(sim|world)\.[\w.\[\]]*\s*(=|\+=|-=|\*=|/=)(?!=)", "assignment into sim state"),
    (r"\b_?(sim|world)\.(set_phase|add_scrap|spawn_enemy|kill_enemy|set_core_hp|submit|step)\(", "sim mutator call"),
    (r"\.(free_index|alloc)\(", "store mutation"),
]


def layer_of(rel: str) -> str | None:
    p = rel.replace("\\", "/")
    if p.startswith("src/shared/"):
        return "shared"
    if p.startswith("src/content/defs/"):
        return "defs"
    if p.startswith("src/sim/"):
        return "sim"
    if p.startswith("src/content/"):
        return "content"
    if p.startswith("src/save/"):
        return "save"
    if p.startswith("src/view/"):
        return "view"
    if p.startswith("src/ui/"):
        return "ui"
    if p.startswith("src/audio/"):
        return "audio"
    if p.startswith("src/debug/"):
        return "debug"
    if p.startswith("src/game/") or p.startswith("src/core/"):
        return "game"
    return None


def iter_files(suffixes: tuple[str, ...]) -> list[Path]:
    out: list[Path] = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.suffix not in suffixes:
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        out.append(path)
    return out


def strip_code(line: str) -> str:
    """Remove comments and string contents from one line (good enough for token checks)."""
    out: list[str] = []
    quote = ""
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = ""
                out.append(c)
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def class_layers() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for path in iter_files((".gd",)):
        rel = path.relative_to(ROOT).as_posix()
        layer = layer_of(rel)
        if layer is None:
            continue
        m = re.search(r"^class_name\s+(\w+)", path.read_text(encoding="utf-8"), re.M)
        if m:
            mapping[m.group(1)] = layer
    return mapping


def lint_layers(files: list[Path], classes: dict[str, str]) -> list[str]:
    errs: list[str] = []
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        layer = layer_of(rel)
        if layer is None or path.suffix != ".gd":
            continue
        lines = [strip_code(ln) for ln in path.read_text(encoding="utf-8").splitlines()]
        rules = SIM_FORBIDDEN if layer == "sim" else SHARED_FORBIDDEN if layer in ("shared", "defs") else []
        for n, ln in enumerate(lines, 1):
            for pat, label in rules:
                if re.search(pat, ln):
                    errs.append(f"{rel}:{n}: [{layer}] forbidden {label}: {ln.strip()}")
            if layer == "view":
                for pat, label in VIEW_WRITE_PATTERNS:
                    if re.search(pat, ln):
                        errs.append(f"{rel}:{n}: [view] {label}: {ln.strip()}")
        forbidden: set[str] = set()
        if layer in ALLOWED:
            forbidden = {c for c, cl in classes.items() if cl not in ALLOWED[layer] and c not in CORE_LIBS}
        elif layer == "ui":
            forbidden = set(UI_FORBIDDEN_CLASSES)
        own = re.search(r"^class_name\s+(\w+)", path.read_text(encoding="utf-8"), re.M)
        for cname in sorted(forbidden):
            if own and own.group(1) == cname:
                continue
            pat = re.compile(r"\b" + re.escape(cname) + r"\b")
            for n, ln in enumerate(lines, 1):
                if pat.search(ln):
                    errs.append(f"{rel}:{n}: [{layer}] may not reference {cname} (layer {classes[cname] if cname in classes else '?'})")
                    break
    return errs


def lint_hygiene(files: list[Path]) -> list[str]:
    errs: list[str] = []
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            errs.append(f"{rel}: UTF-8 BOM")
        if path.suffix in (".gd", ".tscn", ".json", ".cfg", ".svg") and b"\r" in raw:
            errs.append(f"{rel}: CR/CRLF line endings (use LF)")
        if path.suffix == ".gd":
            text = raw.decode("utf-8", "replace")
            for n, ln in enumerate(text.splitlines(), 1):
                if ln.startswith("    ") and rel.startswith(("src/", "tests/")):
                    errs.append(f"{rel}:{n}: space indentation in .gd (use tabs)")
                    break
            if rel.startswith("src/") and len(text.splitlines()) > MAX_LINES:
                errs.append(f"{rel}: {len(text.splitlines())} lines (cap {MAX_LINES})")
    return errs


def self_test() -> int:
    cases = [
        (strip_code('var a = "OS.x" # Time.now'), "var a = \"\" "),
        (bool(re.search(r"(?<![.\w])randf\(", "rng.randf()")), False),
        (bool(re.search(r"(?<![.\w])randf\(", "x = randf()")), True),
        (bool(re.search(AUTOLOAD_WORDS, "GameState.Id.BOOT")), False),
        (bool(re.search(AUTOLOAD_WORDS, "Game.boot()")), True),
        (bool(re.search(VIEW_WRITE_PATTERNS[0][0], "_sim.turrets.active[p] == 1")), False),
        (bool(re.search(VIEW_WRITE_PATTERNS[0][0], "_sim.core_hp = 3.0")), True),
    ]
    bad = 0
    for got, want in cases:
        if got != want:
            bad += 1
            print(f"  [FAIL] got {got!r}, want {want!r}")
    print("SELF-TEST " + ("OK" if bad == 0 else "FAILED"))
    return 0 if bad == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list-gd", action="store_true", help="print .gd and .tscn files to compile (res:// relative)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if a.list_gd:
        for p in iter_files((".gd", ".tscn")):
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith(("src/", "scenes/", "tests/", "tools/")):
                print(rel)
        return 0
    if not (ROOT / "project.godot").is_file():
        print("TOOL ERROR: project.godot not found at " + str(ROOT))
        return 4
    text_files = iter_files((".gd", ".tscn", ".json", ".cfg", ".svg"))
    gd_files = [p for p in text_files if p.suffix == ".gd"]
    errs = lint_layers(gd_files, class_layers()) + lint_hygiene(text_files)
    if errs:
        print(f"[FAIL] layers and hygiene ({len(text_files)} files)")
        for e in errs[:60]:
            print("    " + e)
        return 1
    print(f"[PASS] layers and hygiene ({len(text_files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
