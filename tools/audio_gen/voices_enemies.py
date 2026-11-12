"""Variety enemy sounds (VARIETY_SPEC 12.1, group Enemies): the burster fuse, the two blast sizes, the mote burn-out.

Same kit and rules as voices.py: a recipe takes its own fixed-seed `random.Random` and returns a finished mono signal.
"""
from __future__ import annotations

import random
from typing import Callable

from blocks import nbp, nhp, nlp, rand_gate, scatter, taper, thump
from dsp import (
    Track, bpf, count, env_exp, env_line, env_swell, exp_curve, finish, hpf, lpf, mul, noise, partials, saw_sweep,
    sine_sweep, softclip,
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


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "burster_arm": burster_arm,
    "blast_small": blast_small,
    "blast_big": blast_big,
    "mote_burn": mote_burn,
}
