"""Variety weapon sounds (VARIETY_SPEC 12.1, group Weapons): the arc projector shot and chain crackle, the weapon swap.

Same kit and rules as voices.py: a recipe takes its own fixed-seed `random.Random` and returns a finished mono signal.
"""
from __future__ import annotations

import random
from typing import Callable

from blocks import nbp, nhp, rand_gate, scatter, thump
from dsp import (
    Track, bpf, count, env_bump, env_exp, exp_curve, finish, fm_sweep, hpf, mul, noise, partials, softclip,
)


def shot_arc(r: random.Random) -> list[float]:
    """A sharp crack with a descending electric tail (SPEC 3.5)."""
    t = Track(0.46)
    t.add(nhp(r, 0.05, 0.004, 2800), 0.0, 1.0)
    t.add(thump(0.14, 230, 70, 0.035), 0.0, 0.7)
    n = count(0.38)
    t.add(mul(fm_sweep(n, 3400, 320, 2.01, 3.2, 0.4), env_exp(n, 0.13)), 0.004, 0.55)
    m = count(0.36)
    crackle = mul(hpf(noise(r, m), 3200), rand_gate(r, m, (2.0, 7.0), (3.0, 14.0)))
    t.add(mul(crackle, env_exp(m, 0.13)), 0.012, 0.55)
    t.add(nbp(r, 0.10, 0.025, 1500, 3.0), 0.0, 0.5)
    return finish(softclip(t.data, 1.6))


def arc_chain(r: random.Random) -> list[float]:
    """The crackle of one chain jump: thinner and higher than the shot, no body, three jittered zips."""
    t = Track(0.30)
    m = count(0.28)
    crackle = mul(hpf(noise(r, m), 2600), rand_gate(r, m, (1.5, 5.0), (2.0, 9.0)))
    t.add(mul(crackle, env_exp(m, 0.09)), 0.0, 1.0)
    for at in (0.0, 0.055, 0.12):
        n = count(0.07)
        f0 = r.uniform(3200.0, 4800.0)
        t.add(mul(fm_sweep(n, f0, f0 * 0.28, 2.3, 2.5, 0.3), env_exp(n, 0.03)), at, 0.6)
    scatter(r, t, 5, 0.0, 0.2, (3000.0, 6500.0), 5.0, 0.004, 0.35)
    return finish(softclip(t.data, 1.3), fade_out_ms=25.0)


def weapon_swap(r: random.Random) -> list[float]:
    """Holster slide, latch click, seat: a two-stage "chk-chunk" (the reload sounds have one scrape and one click)."""
    t = Track(0.34)
    t.add(nbp(r, 0.03, 0.006, 2100, 4.0), 0.0, 0.8)
    t.add(thump(0.07, 150, 85, 0.02), 0.0, 0.7)
    n = count(0.10)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 900, 2800), 2.0), env_bump(n)), 0.03, 2.6)
    t.add(nbp(r, 0.04, 0.008, 3200, 6.0), 0.14, 1.0)
    t.add(partials(0.14, [(1650, 0.035, 0.4), (2480, 0.025, 0.25)]), 0.14, 0.7)
    t.add(thump(0.12, 120, 62, 0.035), 0.15, 0.9)
    t.add(nhp(r, 0.02, 0.004, 2000), 0.21, 0.5)
    return finish(softclip(t.data, 1.4))


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "shot_arc": shot_arc,
    "arc_chain": arc_chain,
    "weapon_swap": weapon_swap,
}
