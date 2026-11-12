"""Variety event sounds (VARIETY_SPEC 12.1, group Events): the harm warning, the Deadfall Strike call and impact, the crate.

Same kit and rules as voices.py. Each warning sting differs in rhythm, not only in pitch: `warn_harm` is two long low
pulses; `strike_call` is a squelch, three quick beeps and a falling whistle; nothing is melodic.
"""
from __future__ import annotations

import random
from typing import Callable

from blocks import bell, nbp, nhp, nlp, scatter, thump
from dsp import (
    Track, bpf, count, env_bump, env_exp, env_swell, exp_curve, finish, lpf, mul, noise, partials, saw_sweep,
    sine_sweep, softclip,
)


def warn_harm(r: random.Random) -> list[float]:
    """Two long low pulses (SPEC 12.1), slower and buzzier than the core's lub-dub. A saw up to 1.9 kHz carries it on a phone."""
    t = Track(0.86)
    for at in (0.0, 0.46):
        n = count(0.32)
        gate = env_bump(n)
        t.add(mul(lpf(saw_sweep(n, 165, 140), 1900), gate), at, 0.8)
        t.add(mul(sine_sweep(n, 82, 70), gate), at, 0.6)
        t.add(mul(partials(0.32, [(330, 0.14, 0.3), (495, 0.10, 0.25), (825, 0.08, 0.15)]), gate), at, 0.5)
        t.add(nlp(r, 0.04, 0.01, 900), at, 0.3)
    return finish(softclip(t.data, 1.5), fade_out_ms=35.0)


def strike_call(r: random.Random) -> list[float]:
    """The player calls the Deadfall Strike: radio squelch, three quick beeps, then the round's falling whistle."""
    t = Track(1.30)
    t.add(nbp(r, 0.10, 0.03, 1900, 1.5), 0.0, 1.2)
    for at in (0.10, 0.20, 0.30):
        t.add(partials(0.07, [(1480, 0.03, 0.6)]), at, 0.9)
        t.add(nbp(r, 0.02, 0.004, 3600, 5.0), at, 0.3)
    n = count(0.80)
    t.add(mul(sine_sweep(n, 2600, 520), env_swell(n, 0.2, 0.5)), 0.42, 0.45)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 3200, 700), 3.0), env_swell(n, 0.2, 0.5)), 0.42, 1.0)
    t.add(thump(0.12, 160, 70, 0.04), 0.42, 0.5)
    return finish(softclip(t.data, 1.2), fade_out_ms=40.0)


def strike_impact(r: random.Random) -> list[float]:
    """450 damage on a cluster: a sub-heavy slam with a ringing slab and a long rubble tail (blast_big is more noise)."""
    t = Track(1.40)
    t.add(nhp(r, 0.08, 0.015, 500), 0.0, 0.9)
    t.add(thump(0.90, 80, 22, 0.28), 0.0, 1.3)
    n = count(1.0)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 2600, 90), 0.9), env_exp(n, 0.36)), 0.0, 1.0)
    t.add(partials(1.2, [(112, 0.5, 0.35), (187, 0.4, 0.25), (310, 0.3, 0.2), (470, 0.2, 0.12)]), 0.0, 0.8)
    scatter(r, t, 20, 0.08, 1.1, (400.0, 2200.0), 3.0, 0.016, 0.35, power=1.5)
    k = count(0.9)
    t.add(mul(lpf(noise(r, k), 140), env_exp(k, 0.4)), 0.15, 0.8)
    return finish(softclip(t.data, 2.2), fade_out_ms=80.0)


def crate_secured(r: random.Random) -> list[float]:
    """Two clamp clacks and a short ring: the crate is banked (ui_purchase is a bell pair, this one starts mechanical)."""
    t = Track(0.62)
    for at in (0.0, 0.085):
        t.add(thump(0.06, 190, 90, 0.018), at, 1.2)
        t.add(nbp(r, 0.03, 0.006, 2700, 5.0), at, 1.7)
    t.add(bell(660, 0.50, 0.22, ratio=2.0, index=1.2), 0.17, 0.75)
    t.add(bell(990, 0.40, 0.16, ratio=2.0, index=1.0), 0.17, 0.35)
    t.add(nbp(r, 0.05, 0.01, 5200, 3.0), 0.17, 0.3)
    return finish(softclip(t.data, 1.25))


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "warn_harm": warn_harm,
    "strike_call": strike_call,
    "strike_impact": strike_impact,
    "crate_secured": crate_secured,
}
