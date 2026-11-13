"""Variety enemy sounds (VARIETY_SPEC 12.1, group Enemies): fuses, blasts, bolts, wards, splits and spawns.

Same kit and rules as voices.py: a recipe takes its own fixed-seed `random.Random` and returns a finished mono signal.
"""
from __future__ import annotations

import math
import random
from typing import Callable

from blocks import bell, exciter, nbp, nhp, nlp, rand_gate, scatter, taper, thump
from dsp import (
    SR, Track, bpf, count, env_exp, env_line, env_swell, exp_curve, finish, fm_sweep, hpf, lpf, mul, noise,
    partials, saw_sweep, sine_sweep, softclip,
)


def burster_arm(r: random.Random) -> list[float]:
    """The tank swells for the 1.2 s fuse (CONTENT 4): a rising whine and hiss under ticks that speed up, then a latch."""
    t = Track(1.25)
    n = count(1.15)
    whine = lpf(saw_sweep(n, 110, 460), exp_curve(n, 350, 2600))
    t.add(taper(mul(whine, env_swell(n, 1.1, 100.0)), 25.0), 0.0, 0.7)
    t.add(taper(mul(sine_sweep(n, 70, 150), env_line(n, 0.2, 1.0)), 25.0), 0.0, 0.5)
    t.add(taper(mul(bpf(noise(r, n), exp_curve(n, 1500, 5200), 1.8), env_line(n, 0.0, 1.0)), 25.0), 0.0, 1.2)
    at = 0.08
    gap = 0.26
    while at < 1.12:
        t.add(partials(0.06, [(1900, 0.012, 0.6)]), at, 0.8)
        t.add(nbp(r, 0.02, 0.004, 3500, 4.0), at, 0.4)
        at += gap
        gap = max(0.05, gap * 0.78)
    t.add(nbp(r, 0.04, 0.01, 2600, 5.0), 1.17, 0.9)
    return finish(softclip(t.data, 1.3), fade_out_ms=25.0)


def blast_small(r: random.Random) -> list[float]:
    """A burster or chain blast: a short punch with a hiss of debris (death_small is all hiss, this one has weight)."""
    t = Track(0.55)
    t.add(thump(0.30, 160, 44, 0.075), 0.0, 1.0)
    n = count(0.40)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 4200, 260), 0.9), env_exp(n, 0.11)), 0.0, 0.9)
    t.add(nhp(r, 0.03, 0.006, 1200), 0.0, 0.6)
    scatter(r, t, 6, 0.03, 0.30, (600.0, 2400.0), 3.0, 0.01, 0.3)
    t.add(nlp(r, 0.25, 0.10, 500), 0.02, 0.5)
    return finish(softclip(t.data, 1.8), fade_out_ms=30.0)


def blast_big(r: random.Random) -> list[float]:
    """Replaces four or more simultaneous small blasts (SPEC 10.5): a deep double thump, a debris shower, a rumble."""
    t = Track(1.25)
    t.add(thump(0.80, 95, 26, 0.24), 0.0, 1.2)
    t.add(thump(0.40, 140, 40, 0.10), 0.0, 0.6)
    n = count(0.90)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 3000, 110), 0.9), env_exp(n, 0.32)), 0.0, 1.0)
    t.add(nhp(r, 0.06, 0.012, 700), 0.0, 0.8)
    t.add(thump(0.50, 70, 30, 0.16), 0.09, 0.7)
    t.add(nlp(r, 0.30, 0.10, 400), 0.09, 0.5)
    scatter(r, t, 16, 0.06, 0.95, (500.0, 2600.0), 3.0, 0.014, 0.35, power=1.4)
    k = count(0.70)
    t.add(mul(lpf(noise(r, k), 160), env_exp(k, 0.35)), 0.2, 0.8)
    return finish(softclip(t.data, 2.0), fade_out_ms=60.0)


def spitter_shot(r: random.Random) -> list[float]:
    """The spitter lobs a bolt: a wet "thwip" with a rising blip of acid and a low gurgle under it."""
    t = Track(0.42)
    n = count(0.30)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 600, 2900), 1.8), env_exp(n, 0.07)), 0.0, 2.0)
    t.add(mul(fm_sweep(n, 700, 1900, 1.7, 3.5, 0.2), env_exp(n, 0.09)), 0.0, 0.5)
    t.add(mul(sine_sweep(count(0.25), 260, 120), env_exp(count(0.25), 0.08)), 0.0, 0.6)
    t.add(nhp(r, 0.02, 0.004, 2500), 0.0, 0.5)
    scatter(r, t, 3, 0.05, 0.25, (1500.0, 3200.0), 4.0, 0.006, 0.3)
    return finish(softclip(t.data, 1.3), fade_out_ms=25.0)


def bolt_impact(r: random.Random) -> list[float]:
    """The bolt strikes the cage: a sharp crack, a short fry of sparks and a dull ring of the frame (quiet)."""
    t = Track(0.32)
    t.add(nhp(r, 0.04, 0.004, 2400), 0.0, 1.0)
    m = count(0.26)
    fry = mul(hpf(noise(r, m), 3000), rand_gate(r, m, (1.5, 5.0), (2.0, 9.0)))
    t.add(mul(fry, env_exp(m, 0.07)), 0.0, 0.8)
    t.add(thump(0.12, 160, 70, 0.04), 0.0, 0.7)
    t.add(partials(0.22, [(540, 0.07, 0.25), (830, 0.05, 0.18)]), 0.0, 0.6)
    return finish(softclip(t.data, 1.4), fade_out_ms=25.0)


def splitter_split(r: random.Random) -> list[float]:
    """The splitter breaks apart: a heavy crack, a tumble of debris and three small pings as the shards fly off."""
    t = Track(0.85)
    t.add(nhp(r, 0.08, 0.012, 700), 0.0, 1.0)
    t.add(thump(0.35, 140, 46, 0.09), 0.0, 1.0)
    n = count(0.55)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 3500, 200), 0.9), env_exp(n, 0.16)), 0.0, 0.8)
    scatter(r, t, 14, 0.04, 0.45, (700.0, 2800.0), 3.0, 0.012, 0.4, power=1.2)
    for at, f in ((0.16, 1750.0), (0.25, 2250.0), (0.35, 2850.0)):
        t.add(partials(0.30, [(f, 0.05, 0.30), (f * 1.52, 0.04, 0.18)]), at, 0.8)
        t.add(nbp(r, 0.02, 0.004, f * 1.5, 5.0), at, 0.5)
    return finish(softclip(t.data, 1.7), fade_out_ms=40.0)


def ward_hum(r: random.Random) -> list[float]:
    """A ward comes up: a short, soft hum that swells and settles (two close tones that beat, a faint shimmer)."""
    t = Track(0.50)
    n = count(0.46)
    swell = env_swell(n, 0.14, 0.18)
    t.add(mul(partials(0.46, [(196.0, 0.5, 0.5), (198.0, 0.5, 0.5), (392.0, 0.3, 0.12)]), swell), 0.0, 1.0)
    t.add(mul(sine_sweep(n, 100, 130), swell), 0.0, 0.5)
    t.add(mul(bpf(noise(r, n), 1800, 3.0), swell), 0.0, 0.3)
    return finish(exciter(t.data, 0.9, 300.0, 480.0), fade_out_ms=40.0)


def ward_break(r: random.Random) -> list[float]:
    """A ward collapses: a dull metallic pop, a deflating wobble and a scatter of sparks (shield_break is brighter)."""
    t = Track(0.62)
    t.add(nhp(r, 0.07, 0.014, 1400), 0.0, 1.0)
    n = count(0.50)
    t.add(mul(fm_sweep(n, 1800, 200, 1.5, 2.5, 0.0), env_exp(n, 0.12)), 0.0, 0.8)
    t.add(partials(0.40, [(1200, 0.08, 0.3), (1730, 0.06, 0.22), (2290, 0.05, 0.16)]), 0.0, 0.8)
    m = count(0.45)
    fizz = mul(hpf(noise(r, m), 2800), rand_gate(r, m, (3.0, 9.0), (3.0, 12.0)))
    t.add(mul(fizz, env_exp(m, 0.16)), 0.02, 0.8)
    t.add(thump(0.20, 150, 55, 0.06), 0.0, 0.7)
    return finish(softclip(t.data, 1.4), fade_out_ms=35.0)


def jammer_pop(r: random.Random) -> list[float]:
    """The jammer dies and its field collapses: a pop, a burst of radio static and a falling wobble."""
    t = Track(0.55)
    t.add(thump(0.15, 220, 70, 0.04), 0.0, 1.0)
    t.add(nbp(r, 0.10, 0.02, 1500, 1.5), 0.0, 1.0)
    m = count(0.45)
    static = mul(hpf(noise(r, m), 1800), rand_gate(r, m, (2.0, 9.0), (2.0, 10.0)))
    t.add(mul(static, env_exp(m, 0.14)), 0.0, 0.9)
    n = count(0.40)
    t.add(mul(fm_sweep(n, 900, 150, 2.3, 3.0, 0.5), env_exp(n, 0.10)), 0.02, 0.55)
    return finish(softclip(t.data, 1.5), fade_out_ms=30.0)


def borer_emerge(r: random.Random) -> list[float]:
    """A borer drills up through the floor: a grinding growl that rises, gravel, then the plating cracks open."""
    t = Track(0.80)
    n = count(0.62)
    grind = lpf(saw_sweep(n, 62, 120), 420)
    chop = [0.62 + 0.38 * math.sin(2.0 * math.pi * 22.0 * i / SR) for i in range(n)]
    t.add(mul(mul(grind, chop), env_swell(n, 0.50, 0.25)), 0.0, 0.9)
    t.add(mul(lpf(noise(r, n), 500), env_swell(n, 0.45, 0.25)), 0.0, 0.9)
    scatter(r, t, 16, 0.05, 0.62, (400.0, 1800.0), 2.5, 0.014, 0.35, power=0.8)
    t.add(nhp(r, 0.08, 0.016, 900), 0.60, 1.0)
    t.add(thump(0.22, 120, 50, 0.07), 0.60, 0.9)
    scatter(r, t, 6, 0.62, 0.78, (1200.0, 3500.0), 3.0, 0.01, 0.35)
    return finish(softclip(exciter(t.data), 1.6), fade_out_ms=40.0)


def mote_burn(r: random.Random) -> list[float]:
    """A mote burning out on the cage: a short fry with a soft pop and a dull contact (quiet; forty can arrive at once)."""
    t = Track(0.38)
    m = count(0.30)
    fry = mul(hpf(noise(r, m), 3800), rand_gate(r, m, (1.0, 3.5), (1.0, 5.0)))
    t.add(mul(fry, env_exp(m, 0.09)), 0.0, 1.0)
    k = count(0.12)
    t.add(mul(sine_sweep(k, 1100, 260), env_exp(k, 0.03)), 0.0, 0.6)
    t.add(thump(0.14, 120, 66, 0.04), 0.0, 0.5)
    scatter(r, t, 4, 0.02, 0.22, (4500.0, 7000.0), 6.0, 0.003, 0.4)
    return finish(softclip(t.data, 1.3), fade_out_ms=20.0)


def elite_spawn(r: random.Random) -> list[float]:
    """An elite enters: a low swelling pulse, a hard strike and a cold metallic ring (it also gets a ticker line)."""
    t = Track(0.95)
    n = count(0.55)
    pulse = lpf(saw_sweep(n, 55, 58), exp_curve(n, 160, 900))
    t.add(mul(pulse, env_swell(n, 0.30, 0.25)), 0.0, 0.8)
    t.add(mul(sine_sweep(n, 55, 55), env_swell(n, 0.30, 0.25)), 0.0, 0.7)
    t.add(thump(0.45, 110, 38, 0.12), 0.34, 1.2)
    t.add(nhp(r, 0.08, 0.012, 1000), 0.34, 0.9)
    t.add(partials(0.60, [(311, 0.30, 0.30), (466, 0.24, 0.22), (1337, 0.14, 0.12), (1910, 0.10, 0.08)]), 0.34, 0.9)
    t.add(bell(740, 0.50, 0.25, ratio=2.41, index=1.2), 0.36, 0.3)
    return finish(softclip(exciter(t.data), 1.5), fade_out_ms=60.0)


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "burster_arm": burster_arm,
    "blast_small": blast_small,
    "blast_big": blast_big,
    "spitter_shot": spitter_shot,
    "bolt_impact": bolt_impact,
    "splitter_split": splitter_split,
    "ward_hum": ward_hum,
    "ward_break": ward_break,
    "jammer_pop": jammer_pop,
    "borer_emerge": borer_emerge,
    "mote_burn": mote_burn,
    "elite_spawn": elite_spawn,
}
