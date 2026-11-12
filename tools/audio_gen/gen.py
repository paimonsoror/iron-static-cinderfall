#!/usr/bin/env python3
"""Generates every sound of IRON STATIC: CINDERFALL into assets/audio/ (ARCH 10). Python 3.12, standard library only.

    py -3.12 -I tools/audio_gen/gen.py                 write every SFX (registry.py) and the 2 loops
    py -3.12 -I tools/audio_gen/gen.py --out <dir>     write into <dir> instead
    py -3.12 -I tools/audio_gen/gen.py --check         regenerate twice into temp dirs, require both runs to be
                                                       byte-identical to each other and to the committed files
    py -3.12 -I tools/audio_gen/gen.py --report [dir]  measure the files in <dir> (default assets/audio)

Everything is synthesized from fixed seeds (dsp.rng_for), so repeated runs on one machine produce identical bytes.
Exit codes: 0 success, 1 check or report failure, 4 tool failure.
"""
from __future__ import annotations

import argparse
import cmath
import hashlib
import math
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I removes the script folder from sys.path

import beds  # noqa: E402
import dsp  # noqa: E402
import registry  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "assets" / "audio"
MAX_SFX_SECONDS = 1.5  # stingers (registry.STINGERS) are exempt
MAX_STINGER_SECONDS = 4.0
LOOP_RANGE_SECONDS = (12.0, 24.0)
MAX_SEAM_RATIO = 3.0


def outputs() -> dict[str, str]:
    """relative path -> kind ('sfx' or 'loop')."""
    out: dict[str, str] = {}
    for sid in registry.RECIPES:
        out[f"sfx/{sid}.wav"] = "sfx"
    for name in beds.LOOPS:
        out[f"loops/{name}.wav"] = "loop"
    return out


def generate(out_dir: Path) -> list[str]:
    """Writes every file; returns the relative paths written."""
    written: list[str] = []
    for sid, recipe in registry.RECIPES.items():
        sig = recipe(dsp.rng_for(sid))
        dsp.write_wav(out_dir / "sfx" / f"{sid}.wav", sig)
        written.append(f"sfx/{sid}.wav")
    for name, fn in beds.LOOPS.items():
        dsp.write_wav(out_dir / "loops" / f"{name}.wav", fn())
        written.append(f"loops/{name}.wav")
    return written


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_wav(path: Path) -> tuple[list[float], int, int, int]:
    """(samples in -1..1, rate, channels, sample width bytes)."""
    with wave.open(str(path), "rb") as w:
        n, rate, ch, width = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    ints = struct.unpack("<%dh" % (len(raw) // 2), raw) if width == 2 else ()
    return [v / 32768.0 for v in ints], rate, ch, width


# ---------------------------------------------------------------------------------------------------------
# --check
# ---------------------------------------------------------------------------------------------------------

def check() -> int:
    expected = outputs()
    with tempfile.TemporaryDirectory(prefix="cinderfall_audio_a_") as da, \
            tempfile.TemporaryDirectory(prefix="cinderfall_audio_b_") as db:
        # two independent processes, in parallel: proves run-to-run determinism including interpreter state
        procs = [subprocess.Popen([sys.executable, "-I", str(Path(__file__).resolve()), "--out", d],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) for d in (da, db)]
        for p in procs:
            out, _ = p.communicate()
            if p.returncode != 0:
                print("AUDIO CHECK FAILED: generator run failed")
                print(out)
                return 4
        problems: list[str] = []
        total = 0
        for rel in expected:
            a, b, c = Path(da) / rel, Path(db) / rel, DEFAULT_OUT / rel
            if not a.is_file() or not b.is_file():
                problems.append(f"{rel}: not generated")
                continue
            total += a.stat().st_size
            if sha(a) != sha(b):
                problems.append(f"{rel}: two runs differ (not deterministic)")
            if not c.is_file():
                problems.append(f"{rel}: missing from assets/audio")
            elif sha(a) != sha(c):
                problems.append(f"{rel}: committed file differs from a fresh run")
        extra = sorted(p.relative_to(DEFAULT_OUT).as_posix() for p in DEFAULT_OUT.rglob("*.wav")
                       if p.relative_to(DEFAULT_OUT).as_posix() not in expected)
        for rel in extra:
            problems.append(f"{rel}: not produced by the generator")
        for rel in expected:
            problems.extend(f"{rel}: {m}" for m in format_problems(rel, expected[rel], Path(da) / rel))
    if problems:
        for p in problems:
            print("  " + p)
        print(f"AUDIO CHECK FAILED: {len(problems)} problem(s)")
        return 1
    print(f"AUDIO CHECK OK ({len(expected)} files, {total} bytes, two runs identical, committed files match)")
    return 0


def format_problems(rel: str, kind: str, path: Path) -> list[str]:
    """Spec limits: mono 16-bit, 22.05 or 44.1 kHz, duration bounds, not silent, no clipping, edges at zero."""
    if not path.is_file():
        return []
    x, rate, ch, width = read_wav(path)
    sid = Path(rel).stem
    issues: list[str] = []
    if ch != 1 or width != 2 or rate not in (22050, 44100):
        issues.append(f"format ch={ch} width={width} rate={rate}")
    dur = len(x) / rate
    if kind == "loop":
        if not LOOP_RANGE_SECONDS[0] <= dur <= LOOP_RANGE_SECONDS[1]:
            issues.append(f"loop length {dur:.2f}s outside {LOOP_RANGE_SECONDS}")
        if seam_ratio(x) > MAX_SEAM_RATIO:
            issues.append(f"loop seam ratio {seam_ratio(x):.2f} exceeds {MAX_SEAM_RATIO}")
    elif sid in registry.STINGERS:
        if dur > MAX_STINGER_SECONDS:
            issues.append(f"stinger length {dur:.2f}s")
    elif dur >= MAX_SFX_SECONDS:
        issues.append(f"length {dur:.2f}s is not under {MAX_SFX_SECONDS}s")
    peak = max((abs(s) for s in x), default=0.0)
    if peak < 0.1:
        issues.append(f"too quiet (peak {peak:.3f})")
    if peak > 0.95:
        issues.append(f"peak {peak:.3f} is too hot")
    if kind == "sfx" and (abs(x[0]) > 0.01 or abs(x[-1]) > 0.01):
        issues.append("edges are not at zero")
    return issues


# ---------------------------------------------------------------------------------------------------------
# --report
# ---------------------------------------------------------------------------------------------------------

def fft(a: list[complex]) -> list[complex]:
    n = len(a)
    if n == 1:
        return a
    even, odd = fft(a[0::2]), fft(a[1::2])
    tw = [cmath.exp(-2j * math.pi * k / n) * odd[k] for k in range(n // 2)]
    return [even[k] + tw[k] for k in range(n // 2)] + [even[k] - tw[k] for k in range(n // 2)]


def centroid_hz(x: list[float], rate: int) -> float:
    """Spectral centroid of the first 8192 samples (Hann window): a rough 'brightness' number."""
    m = min(len(x), 8192)
    size = 1
    while size < m:
        size *= 2
    seg = [x[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / max(m - 1, 1))) for i in range(m)] + [0.0] * (size - m)
    spec = fft([complex(v) for v in seg])[: size // 2]
    mags = [abs(c) for c in spec]
    total = sum(mags)
    if total <= 0.0:
        return 0.0
    return sum(mags[k] * (k * rate / size) for k in range(len(mags))) / total


def seam_ratio(x: list[float]) -> float:
    """Step across the loop point (last sample to first) over the mean of the two steps on each side of it.
    About 1 for a continuous signal; much larger means a click when the loop wraps."""
    wrap = abs(x[0] - x[-1])
    near = (abs(x[-1] - x[-2]) + abs(x[-2] - x[-3]) + abs(x[1] - x[0]) + abs(x[2] - x[1])) / 4.0
    return wrap / max(near, 1e-9)


def db(v: float) -> float:
    return 20.0 * math.log10(v) if v > 1e-9 else -99.0


def report(directory: Path) -> int:
    expected = outputs()
    print(f"{'file':28} {'sec':>6} {'samples':>8} {'rate':>6} {'peak':>7} {'rms':>7} {'cent_hz':>8} {'first':>7} {'last':>7} {'seam':>6}")
    bad = 0
    for rel, kind in expected.items():
        p = directory / rel
        if not p.is_file():
            print(f"{rel:28} MISSING")
            bad += 1
            continue
        x, rate, ch, width = read_wav(p)
        peak = max(abs(s) for s in x)
        rms = math.sqrt(sum(s * s for s in x) / len(x))
        seam = ""
        if kind == "loop":
            seam = f"{seam_ratio(x):.2f}"
        cen = centroid_hz(x if kind == "sfx" else x[: 8192], rate)
        print(f"{rel:28} {len(x) / rate:6.3f} {len(x):8d} {rate:6d} {db(peak):6.1f}dB {db(rms):6.1f}dB {cen:8.0f} "
              f"{x[0] * 32768:7.0f} {x[-1] * 32768:7.0f} {seam:>6}")
        for issue in format_problems(rel, kind, p):
            print(f"   PROBLEM: {issue}")
            bad += 1
    size = sum((directory / rel).stat().st_size for rel in expected if (directory / rel).is_file())
    print(f"files={len(expected)} total_bytes={size} problems={bad}")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", help="output directory (default assets/audio)")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--report", nargs="?", const=str(DEFAULT_OUT), metavar="DIR")
    a = ap.parse_args()
    try:
        if a.check:
            return check()
        if a.report is not None:
            return report(Path(a.report))
        out = Path(a.out) if a.out else DEFAULT_OUT
        written = generate(out)
        print(f"generated {len(written)} files into {out}")
        return 0
    except Exception as exc:  # tool failure, not a verdict
        print(f"TOOL ERROR: {type(exc).__name__}: {exc}")
        return 4


if __name__ == "__main__":
    sys.exit(main())
