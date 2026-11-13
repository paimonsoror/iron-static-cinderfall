"""Variety UI sounds (VARIETY_SPEC 12.1, group UI): the draft, the route, the salvage, the archive, the act, the resume.

Same kit and rules as voices.py. Gestures: cards dealt (three snaps), a stamp, a track switch, a riffle, a crate latch,
a punch-card stamp, an act banner, a data link.
"""
from __future__ import annotations

import random
from typing import Callable

from blocks import bell, exciter, nbp, nhp, nlp, scatter, thump
from dsp import (
    Track, bpf, count, env_bump, env_exp, env_swell, exp_curve, finish, fm_sweep, lpf, mul, noise, partials, saw_sweep,
    sine_sweep, softclip, square_sweep,
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


def draft_pick_corrupted(r: random.Random) -> list[float]:
    """The same stamp, but wrong: lower, with a tritone that grinds against the ring and a rasp underneath."""
    t = Track(0.72)
    t.add(thump(0.30, 110, 40, 0.09), 0.0, 1.1)
    t.add(nhp(r, 0.04, 0.006, 1200), 0.0, 0.8)
    t.add(partials(0.62, [(520, 0.20, 0.35), (735, 0.18, 0.30), (1050, 0.12, 0.2), (1470, 0.09, 0.14)]), 0.0, 0.9)
    n = count(0.55)
    rasp = lpf(square_sweep(n, 74, 58), 900)
    t.add(mul(rasp, env_exp(n, 0.2)), 0.0, 0.5)
    t.add(mul(fm_sweep(n, 330, 90, 1.41, 3.0, 0.5), env_exp(n, 0.18)), 0.04, 0.35)
    t.add(nlp(r, 0.2, 0.07, 700), 0.0, 0.5)
    return finish(softclip(t.data, 1.5), fade_out_ms=40.0)


def draft_reroll(r: random.Random) -> list[float]:
    """The deck is reshuffled: a riffle of card edges that rises, closed by one snap."""
    t = Track(0.52)
    for k in range(9):
        at = 0.035 * k
        f = 1500.0 + 260.0 * k
        t.add(nbp(r, 0.03, 0.005, f, 4.0), at, 1.3)
        t.add(thump(0.02, 200, 130, 0.006), at, 0.3)
    n = count(0.32)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 900, 3200), 1.2), env_bump(n)), 0.0, 1.0)
    t.add(nbp(r, 0.04, 0.008, 3000, 5.0), 0.36, 1.8)
    t.add(thump(0.08, 140, 80, 0.025), 0.36, 0.8)
    return finish(softclip(t.data, 1.2), fade_out_ms=30.0)


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


def salvage_open(r: random.Random) -> list[float]:
    """A crate is opened: a latch clack, a short hydraulic hiss, the lid thump and a rattle of the parts inside."""
    t = Track(0.78)
    t.add(nbp(r, 0.04, 0.008, 2200, 5.0), 0.0, 1.6)
    t.add(thump(0.08, 170, 80, 0.02), 0.0, 0.8)
    n = count(0.30)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 3000, 1200), 1.3), env_swell(n, 0.04, 0.12)), 0.08, 1.6)
    t.add(thump(0.20, 105, 48, 0.06), 0.30, 1.1)
    t.add(partials(0.30, [(380, 0.07, 0.3), (590, 0.05, 0.2), (880, 0.04, 0.14)]), 0.30, 0.7)
    scatter(r, t, 9, 0.36, 0.72, (1800.0, 5200.0), 5.0, 0.005, 0.5)
    return finish(softclip(t.data, 1.3), fade_out_ms=40.0)


def unlock_buy(r: random.Random) -> list[float]:
    """An Archive entry is bought: two punch-card stamps and a long, soft shimmer of inharmonic metal (not a chord)."""
    t = Track(0.95)
    for at, f in ((0.0, 150.0), (0.11, 190.0)):
        t.add(thump(0.12, f, 62, 0.035), at, 1.1)
        t.add(nbp(r, 0.03, 0.005, 2400, 5.0), at, 1.5)
    n = count(0.55)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 600, 3800), 1.5), env_bump(n)), 0.04, 0.9)
    t.add(partials(0.75, [(880, 0.30, 0.28), (1390, 0.26, 0.22), (1940, 0.20, 0.16), (2760, 0.14, 0.1)]), 0.24, 0.9)
    t.add(bell(1240, 0.5, 0.25, ratio=2.6, index=0.9), 0.24, 0.3)
    return finish(softclip(t.data, 1.2), fade_out_ms=60.0)


def act_start(r: random.Random) -> list[float]:
    """A new act begins: a low horn pulse that swells under a heavy metal strike, and air that opens above it."""
    t = Track(1.40)
    n = count(1.1)
    horn = [a + b for a, b in zip(saw_sweep(n, 55, 55), saw_sweep(n, 82.4, 82.4))]
    t.add(mul(lpf(horn, exp_curve(n, 160, 900)), env_swell(n, 0.55, 0.45)), 0.0, 0.7)
    t.add(mul(sine_sweep(n, 55, 55), env_swell(n, 0.5, 0.5)), 0.0, 0.7)
    t.add(thump(0.60, 100, 32, 0.16), 0.45, 1.2)
    t.add(nhp(r, 0.10, 0.02, 800), 0.45, 0.9)
    t.add(partials(0.90, [(165, 0.35, 0.32), (247, 0.30, 0.24), (415, 0.22, 0.18), (880, 0.12, 0.1)]), 0.45, 0.9)
    m = count(0.9)
    t.add(mul(bpf(noise(r, m), exp_curve(m, 500, 3500), 1.4), env_swell(m, 0.45, 0.3)), 0.2, 0.6)
    return finish(softclip(exciter(t.data), 1.5), fade_out_ms=80.0)


def resume_link(r: random.Random) -> list[float]:
    """The run is picked up again: three fast rising data blips, the thunk of a relay closing and a hum that locks."""
    t = Track(0.85)
    for at, f in ((0.0, 900.0), (0.07, 1300.0), (0.14, 1900.0)):
        n = count(0.05)
        t.add(mul(lpf(square_sweep(n, f, f * 1.05), 3200), env_exp(n, 0.03, 0.002)), at, 0.7)
        t.add(nbp(r, 0.02, 0.004, 4200, 5.0), at, 0.4)
    t.add(thump(0.20, 130, 52, 0.06), 0.28, 1.2)
    t.add(nbp(r, 0.04, 0.006, 1800, 4.0), 0.28, 1.2)
    n = count(0.45)
    t.add(mul(partials(0.45, [(110, 0.4, 0.35), (220, 0.3, 0.2), (330, 0.2, 0.1)]), env_swell(n, 0.06, 0.25)), 0.30, 0.9)
    return finish(softclip(t.data, 1.2), fade_out_ms=60.0)


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "draft_open": draft_open,
    "draft_pick": draft_pick,
    "draft_pick_corrupted": draft_pick_corrupted,
    "draft_reroll": draft_reroll,
    "route_pick": route_pick,
    "salvage_open": salvage_open,
    "unlock_buy": unlock_buy,
    "act_start": act_start,
    "resume_link": resume_link,
}
