"""Variety boss sounds (VARIETY_SPEC 12.1, group Bosses): the telegraphs and the blows of the four new bosses and the Hulk.

Same kit and rules as voices.py. The telegraphs are alert sounds and each differs in rhythm, not only in pitch:
`brood_hatch` is a hiss and three quick knocks, `lance_charge` one continuous three-second climb, `hulk_charge` a rough
engine rev, `aegis_exposed` three falling clacks and one long ring.
"""
from __future__ import annotations

import math
import random
from typing import Callable

from blocks import bell, exciter, nbp, nhp, nlp, rand_gate, scatter, thump
from dsp import (
    SR, Track, bpf, count, env_exp, env_line, env_swell, exp_curve, finish, fm_sweep, hpf, lpf, mul, noise,
    partials, saw_sweep, sine_sweep, softclip,
)


def brood_hatch(r: random.Random) -> list[float]:
    """The hatches open before a release: a hydraulic hiss, three quick knocks of the latches and a rattle inside."""
    t = Track(0.95)
    n = count(0.60)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 2600, 900), 1.2), env_swell(n, 0.05, 0.22)), 0.04, 1.8)
    for at in (0.0, 0.13, 0.26):
        t.add(thump(0.10, 150, 62, 0.03), at, 1.0)
        t.add(nbp(r, 0.05, 0.01, 900, 4.0), at, 1.3)
        t.add(partials(0.12, [(430, 0.03, 0.3), (1180, 0.02, 0.18)]), at, 0.7)
    m = count(0.5)
    t.add(mul(lpf(saw_sweep(m, 150, 85), 700), env_swell(m, 0.1, 0.25)), 0.35, 0.35)
    scatter(r, t, 14, 0.40, 0.90, (2500.0, 6500.0), 5.0, 0.004, 0.45)
    return finish(softclip(t.data, 1.4), fade_out_ms=45.0)


def lance_charge(r: random.Random) -> list[float]:
    """The Lance Platform charges for three seconds (SPEC 12.1: rising, stinger class): a hum that climbs into a scream
    with a hiss opening up and a sub swell, no pulses, so it cannot be mistaken for the other warnings."""
    t = Track(3.0)
    n = count(2.97)
    ramp = [x * x for x in env_line(n, 0.08, 1.0)]
    t.add(mul(fm_sweep(n, 90, 2300, 2.0, 0.8, 5.0), ramp), 0.0, 0.9)
    t.add(mul(lpf(saw_sweep(n, 55, 440), exp_curve(n, 180, 2600)), ramp), 0.0, 0.7)
    t.add(mul(sine_sweep(n, 45, 160), env_line(n, 0.4, 1.0)), 0.0, 0.4)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 600, 6200), 1.5), ramp), 0.0, 1.2)
    t.add(mul(partials(2.97, [(3300, 9.0, 0.10), (4450, 9.0, 0.07)]), ramp), 0.0, 0.8)
    return finish(softclip(t.data, 1.3), fade_out_ms=30.0)


def lance_fire(r: random.Random) -> list[float]:
    """The beam: a hard zap that falls from the top of the spectrum, a sub boom and a buzzing arc that burns out."""
    t = Track(1.0)
    n = count(0.35)
    t.add(mul(fm_sweep(n, 7000, 260, 2.01, 4.0, 0.3), env_exp(n, 0.10)), 0.0, 0.8)
    t.add(nhp(r, 0.10, 0.02, 1800), 0.0, 1.0)
    t.add(thump(0.60, 90, 26, 0.15), 0.0, 1.2)
    m = count(0.75)
    buzz = lpf(saw_sweep(m, 220, 190), 3200)
    t.add(mul(buzz, env_exp(m, 0.22)), 0.0, 0.7)
    crackle = mul(hpf(noise(r, m), 3000), rand_gate(r, m, (2.0, 6.0), (2.0, 10.0)))
    t.add(mul(crackle, env_exp(m, 0.25)), 0.02, 0.8)
    return finish(softclip(t.data, 1.8), fade_out_ms=50.0)


def aegis_exposed(r: random.Random) -> list[float]:
    """The last pylon falls and the array is open: three falling clacks, then one long, clear ring (the window is ten seconds)."""
    t = Track(1.1)
    for k, at in enumerate((0.0, 0.085, 0.17)):
        t.add(thump(0.08, 240 - 40 * k, 90, 0.02), at, 1.0)
        t.add(nbp(r, 0.04, 0.008, 2400 - 400 * k, 5.0), at, 1.4)
    t.add(partials(0.85, [(1480, 0.35, 0.30), (2220, 0.28, 0.22), (3330, 0.18, 0.14), (740, 0.40, 0.2)]), 0.27, 0.9)
    t.add(bell(1480, 0.7, 0.3, ratio=1.5, index=0.9), 0.27, 0.35)
    t.add(nhp(r, 0.04, 0.008, 4000), 0.27, 0.4)
    return finish(softclip(t.data, 1.2), fade_out_ms=70.0)


def tremor_stomp(r: random.Random) -> list[float]:
    """The Tremor Rig stomps: a huge sub thump, a long rumble, two weaker aftershocks and a rattle of debris."""
    t = Track(1.4)
    t.add(thump(0.90, 58, 22, 0.24), 0.0, 1.3)
    n = count(1.2)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 700, 70), 0.9), env_exp(n, 0.42)), 0.0, 1.1)
    t.add(nhp(r, 0.06, 0.012, 500), 0.0, 0.7)
    t.add(thump(0.60, 52, 24, 0.17), 0.27, 0.8)
    t.add(thump(0.50, 48, 24, 0.14), 0.52, 0.5)
    scatter(r, t, 20, 0.05, 1.2, (300.0, 1800.0), 3.0, 0.016, 0.35, power=1.4)
    return finish(softclip(exciter(t.data), 2.1), fade_out_ms=80.0)


def hulk_charge(r: random.Random) -> list[float]:
    """The Hulk winds up its charge: a rough engine that revs from a growl to a roar, with a grinding chatter (one climb,
    shorter and rougher than lance_charge)."""
    t = Track(1.45)
    n = count(1.40)
    grind = [0.55 + 0.45 * math.sin(2.0 * math.pi * 27.0 * i / SR) for i in range(n)]
    ramp = env_line(n, 0.25, 1.0)
    engine = lpf(saw_sweep(n, 48, 150), exp_curve(n, 220, 1800))
    t.add(mul(mul(engine, grind), ramp), 0.0, 0.9)
    t.add(mul(sine_sweep(n, 40, 100), ramp), 0.0, 0.8)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 300, 1600)), mul(grind, ramp)), 0.0, 1.4)
    t.add(mul(fm_sweep(n, 120, 330, 1.41, 1.0, 3.5), env_swell(n, 1.2, 0.5)), 0.0, 0.25)
    t.add(thump(0.20, 100, 45, 0.06), 0.0, 0.7)
    return finish(softclip(exciter(t.data), 1.7), fade_out_ms=70.0)


def boss_phase(r: random.Random) -> list[float]:
    """A boss enters its next phase: plating tears off with a clang, then a rising growl locks in (a hit, not a warning)."""
    t = Track(1.2)
    t.add(nhp(r, 0.20, 0.04, 700), 0.0, 1.0)
    t.add(thump(0.40, 100, 36, 0.10), 0.0, 1.1)
    t.add(partials(0.90, [(142, 0.35, 0.35), (213, 0.30, 0.26), (331, 0.24, 0.20), (587, 0.15, 0.12)]), 0.0, 0.9)
    scatter(r, t, 12, 0.02, 0.45, (500.0, 2800.0), 3.0, 0.01, 0.4)
    n = count(0.80)
    growl = lpf(saw_sweep(n, 62, 140), exp_curve(n, 300, 1500))
    t.add(mul(growl, env_swell(n, 0.35, 0.3)), 0.25, 0.7)
    t.add(nlp(r, 0.50, 0.15, 600), 0.1, 0.5)
    return finish(softclip(exciter(t.data), 1.6), fade_out_ms=60.0)


RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "brood_hatch": brood_hatch,
    "lance_charge": lance_charge,
    "lance_fire": lance_fire,
    "aegis_exposed": aegis_exposed,
    "tremor_stomp": tremor_stomp,
    "hulk_charge": hulk_charge,
    "boss_phase": boss_phase,
}
