"""Variety UI sounds (VARIETY_SPEC 12.1, group UI): the draft opens, a directive is picked, a route is picked.

Same kit and rules as voices.py. Three distinct gestures: cards dealt (three snaps), a stamp, a track switch.
"""
from __future__ import annotations

import random
from typing import Callable

from blocks import nbp, nhp, thump
from dsp import (
    Track, bpf, count, env_bump, env_swell, exp_curve, finish, mul, noise, partials, sine_sweep, softclip,
)


def draft_open(r: random.Random) -> list[float]:
    """Air rises, then three cards snap into place (rising snaps, 85 ms apart)."""
    t = Track(0.62)
    n = count(0.40)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 400, 2600), 1.4), env_swell(n, 0.30, 0.1)), 0.0, 1.3)
    t.add(thump(0.18, 100, 58, 0.06), 0.0, 0.7)
    for k, at in enumerate((0.20, 0.285, 0.37)):
        f = 1700.0 + 650.0 * k
        t.add(nbp(r, 0.04, 0.007, f, 5.0), at, 2.0)
        t.add(partials(0.10, [(f * 0.5, 0.025, 0.4)]), at, 0.8)
        t.add(thump(0.06, 130, 80, 0.02), at, 0.6)
    return finish(softclip(t.data, 1.2), fade_out_ms=25.0)


def draft_pick(r: random.Random) -> list[float]:
    """A stamp: a solid thump with a short metallic ring."""
    t = Track(0.46)
    t.add(thump(0.20, 150, 62, 0.06), 0.0, 1.0)
    t.add(nhp(r, 0.03, 0.005, 1600), 0.0, 0.8)
    t.add(partials(0.40, [(740, 0.14, 0.4), (1110, 0.10, 0.28), (1530, 0.07, 0.2)]), 0.0, 0.9)
    t.add(nbp(r, 0.04, 0.008, 3600, 5.0), 0.05, 0.4)
    return finish(softclip(t.data, 1.3))


def route_pick(r: random.Random) -> list[float]:
    """A track switch: a lever clunk, a short whirr that rises, a blip."""
    t = Track(0.55)
    t.add(thump(0.14, 110, 52, 0.04), 0.0, 1.0)
    t.add(partials(0.22, [(230, 0.06, 0.5), (345, 0.05, 0.3), (590, 0.04, 0.2)]), 0.0, 0.8)
    t.add(nbp(r, 0.03, 0.006, 2400, 5.0), 0.0, 0.8)
    n = count(0.20)
    t.add(mul(sine_sweep(n, 420, 1500), env_bump(n)), 0.13, 0.5)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 700, 3000), 2.0), env_bump(n)), 0.13, 1.4)
    t.add(nbp(r, 0.04, 0.008, 3300, 6.0), 0.34, 0.9)
    t.add(partials(0.14, [(1760, 0.04, 0.4)]), 0.34, 0.8)
    return finish(t.data)


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "draft_open": draft_open,
    "draft_pick": draft_pick,
    "route_pick": route_pick,
}
