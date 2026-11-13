"""Variety event sounds (VARIETY_SPEC 12.1, group Events): warnings, the chaos events, the crate and the hazards.

Same kit and rules as voices.py. Each warning sting differs in rhythm, not only in pitch, and nothing is melodic:
`warn_harm` two long low pulses; `warn_help` two short rising pips; `strike_call` a squelch, three beeps and a falling
whistle; `freight_horn` long-short-long on a two-tone horn; `recount_tick` four ticks that speed up and a clunk.
"""
from __future__ import annotations

import random
from typing import Callable

from blocks import bell, exciter, nbp, nhp, nlp, plateau, rand_gate, scatter, thump
from dsp import (
    Track, bpf, count, env_bump, env_exp, env_line, env_swell, exp_curve, finish, fm_sweep, hpf, lpf, mul, noise,
    partials, saw_sweep, sine_sweep, softclip,
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


def warn_help(r: random.Random) -> list[float]:
    """Two short rising pips: something useful is coming (a crate, a window, a surge). Bright, clean, not melodic."""
    t = Track(0.50)
    for at, f0, f1 in ((0.0, 1050.0, 1350.0), (0.19, 1600.0, 2050.0)):
        n = count(0.15)
        t.add(mul(sine_sweep(n, f0, f1), env_exp(n, 0.06, 0.004)), at, 0.9)
        t.add(partials(0.15, [(f1 * 2.0, 0.03, 0.18)]), at, 0.6)
        t.add(nbp(r, 0.02, 0.004, f1 * 2.0, 5.0), at, 0.5)
    return finish(softclip(t.data, 1.2), fade_out_ms=40.0)


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


def core_vent(r: random.Random) -> list[float]:
    """The player vents the core: a sub thump, then a long jet of steam through the cage that rattles its frame."""
    t = Track(1.15)
    t.add(thump(0.55, 95, 28, 0.15), 0.0, 1.2)
    t.add(nhp(r, 0.05, 0.01, 900), 0.0, 0.8)
    n = count(1.0)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 2300, 520), 1.0), env_exp(n, 0.34)), 0.0, 2.2)
    t.add(mul(lpf(noise(r, n), 380), env_exp(n, 0.30)), 0.0, 0.8)
    t.add(mul(partials(0.9, [(310, 0.12, 0.3), (470, 0.10, 0.22), (760, 0.08, 0.15)]), rand_gate(r, count(0.9), (4.0, 10.0), (2.0, 6.0))), 0.04, 0.6)
    return finish(softclip(t.data, 1.7), fade_out_ms=70.0)


def freight_horn(r: random.Random) -> list[float]:
    """A freight is coming: a two-tone horn, long - short - long (a warning about the rail, so it must not sound like the others)."""
    t = Track(1.25)
    for at, dur in ((0.0, 0.44), (0.54, 0.14), (0.78, 0.46)):
        n = count(dur)
        gate = plateau(n, 0.03, 0.05)
        horn = [a + b for a, b in zip(saw_sweep(n, 196, 196), saw_sweep(n, 247, 247))]
        t.add(mul(lpf(horn, 2300), gate), at, 0.8)
        t.add(mul(partials(dur, [(392, 5.0, 0.25), (494, 5.0, 0.25), (196, 5.0, 0.3)]), gate), at, 0.6)
        t.add(mul(bpf(noise(r, n), 1100, 2.0), gate), at, 0.35)
    return finish(softclip(t.data, 1.4), fade_out_ms=60.0)


def freight_pass(r: random.Random) -> list[float]:
    """The freight car crosses the yard in 1.2 s: a rumble that swells and fades, wheel clacks, a rushing whoosh."""
    t = Track(1.35)
    n = count(1.30)
    t.add(mul(lpf(noise(r, n), 380), env_bump(n)), 0.0, 1.5)
    t.add(mul(sine_sweep(n, 48, 38), env_bump(n)), 0.0, 0.8)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 300, 1600), 1.1), env_bump(n)), 0.0, 1.6)
    k = 0
    at = 0.06
    while at < 1.25:
        gain = 1.0 if k % 2 == 0 else 0.6
        t.add(thump(0.05, 180, 90, 0.015), at, 0.9 * gain)
        t.add(nbp(r, 0.03, 0.006, 1500, 3.0), at, 1.3 * gain)
        t.add(partials(0.08, [(640, 0.02, 0.2), (1010, 0.015, 0.14)]), at, 0.6 * gain)
        at += 0.075
        k += 1
    return finish(softclip(exciter(t.data), 1.5), fade_out_ms=70.0)


def static_front(r: random.Random) -> list[float]:
    """The Static Front starts (a bed of 2 s, longer than an effect): crackle, a mains hum and a band of hiss that sputters."""
    t = Track(2.0)
    n = count(2.0)
    gate = plateau(n, 0.25, 0.7)
    crackle = mul(hpf(noise(r, n), 1600), rand_gate(r, n, (1.0, 7.0), (1.0, 9.0)))
    t.add(mul(crackle, gate), 0.0, 1.0)
    hiss = mul(bpf(noise(r, n), 3300, 0.8), rand_gate(r, n, (40.0, 140.0), (10.0, 60.0)))
    t.add(mul(hiss, gate), 0.0, 1.1)
    t.add(mul(partials(2.0, [(60, 6.0, 0.35), (120, 6.0, 0.22), (180, 6.0, 0.10)]), gate), 0.0, 0.7)
    scatter(r, t, 36, 0.1, 1.7, (2500.0, 7000.0), 5.0, 0.004, 0.45)
    return finish(softclip(t.data, 1.3), fade_out_ms=120.0)


def surge_up(r: random.Random) -> list[float]:
    """The core surges: a climbing electrical whine with arcs, then a hard thump as it locks into a steady buzz."""
    t = Track(1.05)
    n = count(0.65)
    ramp = env_line(n, 0.2, 1.0)
    t.add(mul(fm_sweep(n, 100, 1900, 2.0, 2.0, 5.0), ramp), 0.0, 0.7)
    t.add(mul(sine_sweep(n, 55, 220), ramp), 0.0, 0.6)
    m = count(0.65)
    arcs = mul(hpf(noise(r, m), 2800), rand_gate(r, m, (2.0, 8.0), (3.0, 12.0)))
    t.add(mul(arcs, ramp), 0.0, 0.9)
    t.add(thump(0.30, 120, 48, 0.08), 0.65, 1.1)
    t.add(nhp(r, 0.06, 0.01, 1500), 0.65, 0.8)
    k = count(0.40)
    t.add(mul(partials(0.40, [(100, 0.5, 0.4), (200, 0.4, 0.25), (300, 0.3, 0.15)]), env_exp(k, 0.3)), 0.65, 0.8)
    return finish(softclip(t.data, 1.5), fade_out_ms=70.0)


def brownout(r: random.Random) -> list[float]:
    """The power drops: a tone that falls and flickers out, a last twitch of static and a dull thud (overdrive_off is smoother)."""
    t = Track(1.25)
    n = count(0.95)
    fall = lpf(saw_sweep(n, 1100, 42), exp_curve(n, 3200, 140))
    flicker = rand_gate(r, n, (30.0, 90.0), (6.0, 60.0))
    t.add(mul(mul(fall, flicker), env_exp(n, 0.45)), 0.0, 0.9)
    t.add(mul(sine_sweep(n, 300, 38), env_exp(n, 0.35)), 0.0, 0.6)
    m = count(0.5)
    zap = mul(hpf(noise(r, m), 2200), rand_gate(r, m, (2.0, 6.0), (6.0, 24.0)))
    t.add(mul(zap, env_exp(m, 0.15)), 0.05, 0.7)
    t.add(thump(0.35, 85, 30, 0.1), 0.85, 1.1)
    t.add(nlp(r, 0.2, 0.06, 300), 0.85, 0.5)
    return finish(softclip(t.data, 1.5), fade_out_ms=80.0)


def breach_crack(r: random.Random) -> list[float]:
    """The floor splits open: two sharp cracks, a low groan, a long slide of gravel and tinks of falling pieces."""
    t = Track(1.0)
    t.add(nhp(r, 0.06, 0.008, 1100), 0.0, 1.0)
    t.add(nhp(r, 0.06, 0.008, 800), 0.11, 0.8)
    t.add(thump(0.25, 130, 44, 0.07), 0.0, 1.0)
    n = count(0.75)
    t.add(mul(lpf(saw_sweep(n, 78, 46), 320), env_swell(n, 0.30, 0.3)), 0.05, 0.8)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 1800, 200)), env_swell(n, 0.1, 0.3)), 0.05, 0.9)
    scatter(r, t, 18, 0.08, 0.80, (500.0, 2400.0), 3.0, 0.012, 0.4, power=0.9)
    for at, f in ((0.55, 3100.0), (0.68, 2400.0), (0.80, 3700.0)):
        t.add(partials(0.15, [(f, 0.03, 0.3)]), at, 0.5)
    return finish(softclip(exciter(t.data), 1.6), fade_out_ms=60.0)


def recount_tick(r: random.Random) -> list[float]:
    """The count of the spawn order: four dry ticks that speed up, then one low clunk (RECOUNT warns in this rhythm)."""
    t = Track(1.30)
    for k, at in enumerate((0.0, 0.34, 0.62, 0.84)):
        f = 1250.0 + 150.0 * k
        t.add(partials(0.07, [(f, 0.015, 0.6)]), at, 1.4)
        t.add(nbp(r, 0.03, 0.004, 3000, 5.0), at, 1.8)
        t.add(thump(0.05, 200, 120, 0.012), at, 0.25)
    t.add(thump(0.35, 130, 50, 0.09), 1.0, 0.9)
    t.add(partials(0.28, [(520, 0.08, 0.3), (780, 0.06, 0.2)]), 1.0, 0.9)
    t.add(nhp(r, 0.04, 0.008, 1200), 1.0, 0.6)
    return finish(softclip(t.data, 1.3), fade_out_ms=70.0)


def relay_window(r: random.Random) -> list[float]:
    """The Relay Window opens (Scrap x2): a ratchet that speeds up and two bright clinks, like a counter turning over."""
    t = Track(0.95)
    at = 0.0
    gap = 0.075
    while at < 0.42:
        t.add(nbp(r, 0.02, 0.004, 2600, 5.0), at, 1.3)
        t.add(thump(0.03, 260, 150, 0.008), at, 0.5)
        at += gap
        gap = max(0.022, gap * 0.82)
    t.add(bell(1850, 0.55, 0.20, ratio=2.7, index=1.0), 0.50, 0.8)
    t.add(bell(2780, 0.45, 0.16, ratio=2.7, index=0.8), 0.60, 0.7)
    t.add(nbp(r, 0.03, 0.006, 5200, 4.0), 0.50, 0.4)
    k = count(0.45)
    t.add(mul(sine_sweep(k, 300, 900), env_bump(k)), 0.0, 0.25)
    return finish(softclip(t.data, 1.2), fade_out_ms=60.0)


def crate_land(r: random.Random) -> list[float]:
    """The supply crate drops in: a heavy thud, a clang of its frame, a puff of dust and a small bounce."""
    t = Track(0.75)
    t.add(thump(0.30, 120, 44, 0.09), 0.0, 1.2)
    t.add(nhp(r, 0.05, 0.01, 800), 0.0, 0.8)
    t.add(partials(0.45, [(420, 0.09, 0.3), (650, 0.08, 0.24), (980, 0.06, 0.18), (1370, 0.05, 0.12)]), 0.0, 0.8)
    n = count(0.5)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 2200, 300)), env_exp(n, 0.14)), 0.0, 0.8)
    t.add(thump(0.15, 105, 52, 0.04), 0.19, 0.6)
    t.add(nbp(r, 0.03, 0.005, 1800, 4.0), 0.19, 0.6)
    t.add(partials(0.30, [(2000, 0.08, 0.2)]), 0.34, 0.4)
    return finish(softclip(exciter(t.data), 1.5), fade_out_ms=50.0)


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


def crate_lost(r: random.Random) -> list[float]:
    """The crate is gone: a falling, flickering buzz, a hiss that drains away and a dull clunk (ui_deny is two short notes)."""
    t = Track(0.70)
    n = count(0.55)
    fall = lpf(saw_sweep(n, 420, 85), exp_curve(n, 2600, 220))
    t.add(mul(mul(fall, rand_gate(r, n, (25.0, 70.0), (8.0, 40.0))), env_exp(n, 0.25)), 0.0, 0.9)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 3000, 250), 1.2), env_exp(n, 0.22)), 0.0, 1.3)
    t.add(thump(0.25, 100, 42, 0.07), 0.42, 1.1)
    t.add(nlp(r, 0.15, 0.04, 500), 0.42, 0.5)
    return finish(softclip(t.data, 1.4), fade_out_ms=50.0)


def drum_blast(r: random.Random) -> list[float]:
    """A fuel drum goes off: a deep whoomph, a roar of flame, the clang of the torn shell and a hiss of burning slag."""
    t = Track(1.15)
    t.add(thump(0.75, 110, 30, 0.20), 0.0, 1.2)
    n = count(0.95)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 1900, 150), 0.9), env_swell(n, 0.05, 0.34)), 0.0, 1.2)
    t.add(nhp(r, 0.05, 0.01, 700), 0.0, 0.8)
    t.add(partials(0.6, [(190, 0.20, 0.30), (305, 0.16, 0.24), (520, 0.12, 0.18), (760, 0.08, 0.12)]), 0.0, 0.8)
    m = count(0.70)
    sizzle = mul(hpf(noise(r, m), 2800), rand_gate(r, m, (2.0, 8.0), (3.0, 12.0)))
    t.add(mul(sizzle, env_exp(m, 0.25)), 0.15, 0.7)
    scatter(r, t, 10, 0.05, 0.8, (600.0, 2800.0), 3.0, 0.012, 0.4, power=1.3)
    return finish(softclip(exciter(t.data), 1.9), fade_out_ms=70.0)


# The order of VARIETY_SPEC 12.1 (the group order of the table).
RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "warn_harm": warn_harm,
    "warn_help": warn_help,
    "strike_call": strike_call,
    "strike_impact": strike_impact,
    "core_vent": core_vent,
    "freight_horn": freight_horn,
    "freight_pass": freight_pass,
    "static_front": static_front,
    "surge_up": surge_up,
    "brownout": brownout,
    "breach_crack": breach_crack,
    "recount_tick": recount_tick,
    "relay_window": relay_window,
    "crate_land": crate_land,
    "crate_secured": crate_secured,
    "crate_lost": crate_lost,
    "drum_blast": drum_blast,
}
