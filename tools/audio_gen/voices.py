"""The 29 sound effects of ARCH 10 as DSP recipes (noise bursts, filtered sweeps, FM tones, inharmonic partials).

Each recipe takes its own fixed-seed `random.Random` and returns a finished mono signal (see dsp.finish).
Bleak industrial: dry, metallic, close. No melody; the stingers are stacked fifths and pulses.
"""
from __future__ import annotations

import math
import random
from typing import Callable

from dsp import (
    SR, Track, bpf, count, env_bump, env_exp, env_line, env_swell, exp_curve, finish, fm_sweep, hpf, lp1, lpf, mul,
    noise, partials, saw_sweep, scale, sine_sweep, softclip, square_sweep,
)

# ---------------------------------------------------------------------------------------------------------
# building blocks
# ---------------------------------------------------------------------------------------------------------


def nhp(r: random.Random, dur: float, tau: float, fc: float) -> list[float]:
    """High-passed noise burst with an exponential decay."""
    n = count(dur)
    return mul(hpf(noise(r, n), fc), env_exp(n, tau))


def nlp(r: random.Random, dur: float, tau: float, fc: float) -> list[float]:
    n = count(dur)
    return mul(lpf(noise(r, n), fc), env_exp(n, tau))


def nbp(r: random.Random, dur: float, tau: float, fc: float, q: float = 2.0) -> list[float]:
    """Band-passed noise burst. A narrow band carries little energy, so the gain is compensated."""
    n = count(dur)
    comp = min(5.0, math.sqrt(SR * 0.5 / max(fc / q, 1.0)) * 0.6)
    return scale(mul(bpf(noise(r, n), fc, q), env_exp(n, tau)), comp)


def thump(dur: float, f0: float, f1: float, tau: float) -> list[float]:
    n = count(dur)
    return mul(sine_sweep(n, f0, f1), env_exp(n, tau, 0.001))


def bell(f: float, dur: float, tau: float, ratio: float = 1.41, index: float = 1.6) -> list[float]:
    """Metallic FM tone (inharmonic modulator) with a decaying index."""
    n = count(dur)
    return mul(fm_sweep(n, f, f, ratio, index, 0.0), env_exp(n, tau, 0.001))


def scatter(r: random.Random, t: Track, n: int, t0: float, t1: float, fc: tuple[float, float], q: float,
            tau: float, gain: float, power: float = 1.0) -> None:
    """n short band-passed clicks at random times in [t0, t1] (power > 1 clusters them toward t0)."""
    for _ in range(n):
        at = t0 + (t1 - t0) * (r.random() ** power)
        f = r.uniform(fc[0], fc[1])
        amp = gain * r.uniform(0.5, 1.0)
        t.add(nbp(r, 0.05, tau, f, q), at, amp)


def rand_gate(r: random.Random, n: int, on_ms: tuple[float, float], off_ms: tuple[float, float]) -> list[float]:
    """Smoothed on/off gate with random segment lengths (electrical stutter)."""
    g: list[float] = []
    on = True
    while len(g) < n:
        lo, hi = on_ms if on else off_ms
        g.extend([1.0 if on else 0.0] * max(1, int(r.uniform(lo, hi) * SR / 1000.0)))
        on = not on
    return lp1(g[:n], 700.0)


# ---------------------------------------------------------------------------------------------------------
# weapons
# ---------------------------------------------------------------------------------------------------------

def shot_pistol(r: random.Random) -> list[float]:
    t = Track(0.34)
    t.add(nhp(r, 0.10, 0.012, 1400), 0.0, 1.0)
    t.add(nbp(r, 0.20, 0.05, 900, 1.2), 0.0, 0.7)
    t.add(thump(0.20, 190, 52, 0.035), 0.0, 1.0)
    t.add(nbp(r, 0.25, 0.09, 2600, 9.0), 0.004, 0.45)
    t.add(nlp(r, 0.30, 0.12, 700), 0.01, 0.35)
    return finish(softclip(t.data, 1.7))


def shot_smg(r: random.Random) -> list[float]:
    t = Track(0.18)
    t.add(nhp(r, 0.06, 0.006, 2500), 0.0, 1.0)
    t.add(thump(0.10, 260, 110, 0.02), 0.0, 0.8)
    t.add(nbp(r, 0.08, 0.02, 4200, 3.0), 0.0, 0.5)
    t.add(nbp(r, 0.12, 0.04, 3300, 7.0), 0.003, 0.35)
    return finish(softclip(t.data, 1.5))


def shot_turret(r: random.Random) -> list[float]:
    t = Track(0.30)
    n = count(0.25)
    t.add(mul(lpf(square_sweep(n, 98, 62), 420), env_exp(n, 0.08)), 0.0, 0.9)
    t.add(nbp(r, 0.15, 0.04, 1200, 2.0), 0.0, 0.8)
    t.add(nbp(r, 0.06, 0.012, 3000, 10.0), 0.045, 0.8)
    t.add(mul(lpf(saw_sweep(n, 640, 380), 1500), env_exp(n, 0.10)), 0.0, 0.15)
    t.add(thump(0.15, 120, 60, 0.05), 0.0, 0.6)
    return finish(softclip(t.data, 1.8))


def reload_start(r: random.Random) -> list[float]:
    t = Track(0.50)
    t.add(nbp(r, 0.05, 0.008, 2400, 5.0), 0.0, 1.0)
    t.add(thump(0.08, 140, 90, 0.02), 0.0, 0.5)
    n = count(0.26)
    scrape = bpf(noise(r, n), exp_curve(n, 800, 2800), 3.0)
    t.add(mul(scrape, env_bump(n)), 0.10, 2.2)
    t.add(nbp(r, 0.05, 0.01, 3200, 6.0), 0.37, 0.9)
    t.add(partials(0.12, [(1900, 0.03, 0.3)]), 0.37, 1.0)
    return finish(t.data)


def reload_done(r: random.Random) -> list[float]:
    t = Track(0.42)
    t.add(thump(0.15, 150, 70, 0.04), 0.0, 1.0)
    t.add(nhp(r, 0.04, 0.008, 1800), 0.0, 0.9)
    t.add(nbp(r, 0.05, 0.012, 2200, 6.0), 0.11, 0.9)
    t.add(partials(0.20, [(1450, 0.06, 0.3), (2210, 0.04, 0.2)]), 0.11, 1.0)
    t.add(thump(0.10, 110, 65, 0.03), 0.11, 0.6)
    return finish(softclip(t.data, 1.3))


# ---------------------------------------------------------------------------------------------------------
# impacts and deaths
# ---------------------------------------------------------------------------------------------------------

def hit_ceramic(r: random.Random) -> list[float]:
    t = Track(0.26)
    t.add(nhp(r, 0.06, 0.006, 2200), 0.0, 1.0)
    t.add(partials(0.24, [(2310, 0.05, 0.5), (3170, 0.045, 0.4), (4420, 0.035, 0.35), (5380, 0.03, 0.25)]), 0.0, 0.8)
    for _ in range(3):
        t.add(nbp(r, 0.03, 0.004, 5000, 4.0), r.uniform(0.01, 0.12), 0.4)
    return finish(t.data)


def hit_armor(r: random.Random) -> list[float]:
    t = Track(0.24)
    t.add(thump(0.14, 210, 120, 0.05), 0.0, 0.9)
    t.add(nlp(r, 0.10, 0.02, 1500), 0.0, 0.7)
    t.add(partials(0.20, [(640, 0.06, 0.35), (910, 0.05, 0.3), (1210, 0.04, 0.2)]), 0.0, 0.8)
    t.add(nhp(r, 0.02, 0.004, 1800), 0.0, 0.3)
    return finish(softclip(t.data, 1.2))


def death_small(r: random.Random) -> list[float]:
    t = Track(0.50)
    n = count(0.4)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 5000, 300), 0.9), env_exp(n, 0.12)), 0.0, 1.0)
    t.add(mul(sine_sweep(count(0.3), 380, 70), env_exp(count(0.3), 0.10)), 0.0, 0.5)
    scatter(r, t, 6, 0.0, 0.3, (3000, 5000), 4.0, 0.005, 0.3)
    t.add(thump(0.10, 120, 55, 0.04), 0.0, 0.6)
    return finish(softclip(t.data, 1.4))


def death_heavy(r: random.Random) -> list[float]:
    t = Track(0.90)
    t.add(mul(sine_sweep(count(0.7), 130, 38), env_exp(count(0.7), 0.22)), 0.0, 1.0)
    n = count(0.6)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 3500, 120), 0.9), env_exp(n, 0.30)), 0.0, 0.9)
    scatter(r, t, 12, 0.05, 0.55, (700, 2500), 3.0, 0.012, 0.4)
    t.add(mul(fm_sweep(count(0.5), 240, 110, 1.5, 3.0, 0.3), env_exp(count(0.5), 0.2)), 0.0, 0.3)
    return finish(softclip(t.data, 1.8))


def death_boss(r: random.Random) -> list[float]:
    t = Track(1.42)
    t.add(nhp(r, 0.20, 0.05, 600), 0.0, 1.0)
    t.add(mul(sine_sweep(count(1.3), 80, 24), env_exp(count(1.3), 0.55)), 0.0, 1.1)
    n = count(1.2)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 1200, 90), 0.9), env_exp(n, 0.60)), 0.0, 1.0)
    t.add(mul(fm_sweep(count(1.1), 170, 48, 1.5, 4.0, 0.5), env_exp(count(1.1), 0.45)), 0.0, 0.55)
    scatter(r, t, 30, 0.05, 1.05, (500, 2800), 3.0, 0.015, 0.4, power=1.6)
    return finish(softclip(t.data, 2.2), fade_out_ms=40.0)


# ---------------------------------------------------------------------------------------------------------
# enemy strikes
# ---------------------------------------------------------------------------------------------------------

def core_hit_light(r: random.Random) -> list[float]:
    t = Track(0.36)
    t.add(mul(sine_sweep(count(0.25), 120, 90), env_exp(count(0.25), 0.09)), 0.0, 1.0)
    t.add(partials(0.30, [(310, 0.15, 0.4), (520, 0.10, 0.3), (790, 0.08, 0.2)]), 0.0, 1.0)
    t.add(nhp(r, 0.03, 0.006, 1200), 0.0, 0.6)
    return finish(softclip(t.data, 1.3))


def core_hit_heavy(r: random.Random) -> list[float]:
    t = Track(0.66)
    t.add(mul(sine_sweep(count(0.5), 70, 38), env_exp(count(0.5), 0.20)), 0.0, 1.1)
    t.add(partials(0.60, [(160, 0.30, 0.5), (255, 0.22, 0.4), (410, 0.18, 0.3), (690, 0.12, 0.2)]), 0.0, 1.0)
    t.add(nlp(r, 0.20, 0.09, 900), 0.0, 0.8)
    t.add(nhp(r, 0.03, 0.006, 1000), 0.0, 0.7)
    return finish(softclip(t.data, 1.6))


def boss_stomp(r: random.Random) -> list[float]:
    t = Track(0.76)
    t.add(thump(0.50, 62, 30, 0.16), 0.0, 1.2)
    n = count(0.6)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 400, 80), 0.9), env_exp(n, 0.30)), 0.0, 0.7)
    t.add(thump(0.40, 55, 28, 0.14), 0.17, 0.55)
    t.add(nlp(r, 0.20, 0.06, 600), 0.17, 0.3)
    return finish(softclip(t.data, 1.8), fade_out_ms=30.0)


# ---------------------------------------------------------------------------------------------------------
# abilities
# ---------------------------------------------------------------------------------------------------------

def emp(r: random.Random) -> list[float]:
    t = Track(0.95)
    t.add(thump(0.30, 140, 40, 0.12), 0.0, 0.9)
    n = count(0.7)
    t.add(mul(fm_sweep(n, 2400, 160, 2.01, 2.5, 0.1), env_exp(n, 0.35)), 0.0, 0.7)
    m = count(0.8)
    crackle = mul(hpf(noise(r, m), 3000), rand_gate(r, m, (3.0, 9.0), (4.0, 18.0)))
    t.add(mul(crackle, env_exp(m, 0.40)), 0.0, 0.5)
    for _ in range(5):
        t.add(nbp(r, 0.05, 0.01, 2500, 3.0), r.uniform(0.05, 0.6), 0.5)
    return finish(softclip(t.data, 1.5))


def shield_up(r: random.Random) -> list[float]:
    t = Track(0.78)
    n = count(0.55)
    t.add(mul(fm_sweep(n, 220, 880, 2.0, 1.2, 0.2), env_swell(n, 0.4, 0.15)), 0.0, 0.8)
    t.add(mul(sine_sweep(n, 110, 440), env_swell(n, 0.4, 0.15)), 0.0, 0.4)
    t.add(partials(0.28, [(880, 0.2, 0.3), (1320, 0.15, 0.2), (1760, 0.12, 0.15)]), 0.5, 1.0)
    t.add(nhp(r, 0.03, 0.004, 3000), 0.5, 0.4)
    return finish(t.data)


def shield_break(r: random.Random) -> list[float]:
    t = Track(0.66)
    t.add(nhp(r, 0.10, 0.02, 1800), 0.0, 1.0)
    n = count(0.5)
    t.add(mul(fm_sweep(n, 1500, 140, 1.4, 3.0, 0.0), env_exp(n, 0.20)), 0.0, 0.7)
    t.add(partials(0.5, [(2400, 0.09, 0.4), (3300, 0.08, 0.3), (4700, 0.06, 0.25)]), 0.0, 1.0)
    m = count(0.5)
    fizz = mul(bpf(noise(r, m), 3500, 2.0), rand_gate(r, m, (4.0, 10.0), (3.0, 12.0)))
    t.add(mul(fizz, env_exp(m, 0.30)), 0.0, 1.2)
    return finish(softclip(t.data, 1.4))


def overdrive_on(r: random.Random) -> list[float]:
    t = Track(0.86)
    n = count(0.70)
    whine = lpf(saw_sweep(n, 140, 1500), exp_curve(n, 500, 5000))
    t.add(mul(whine, env_line(n, 0.2, 1.0)), 0.0, 0.7)
    t.add(mul(sine_sweep(n, 70, 700), env_line(n, 0.3, 1.0)), 0.0, 0.5)
    t.add(mul(lpf(noise(r, n), 200), env_line(n, 0.4, 1.0)), 0.0, 0.8)
    t.add(nhp(r, 0.10, 0.03, 1500), 0.70, 0.8)
    t.add(partials(0.15, [(1500, 0.06, 0.4)]), 0.70, 1.0)
    return finish(softclip(t.data, 1.5))


def overdrive_off(r: random.Random) -> list[float]:
    t = Track(0.78)
    n = count(0.70)
    fall = lpf(saw_sweep(n, 1100, 70), exp_curve(n, 4000, 200))
    t.add(mul(fall, env_exp(n, 0.35)), 0.0, 0.8)
    t.add(mul(sine_sweep(n, 700, 60), env_exp(n, 0.30)), 0.0, 0.5)
    t.add(nbp(r, 0.05, 0.01, 2000, 3.0), 0.0, 0.7)
    t.add(thump(0.15, 90, 50, 0.05), 0.55, 0.7)
    return finish(softclip(t.data, 1.4))


# ---------------------------------------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------------------------------------

def ui_tap(r: random.Random) -> list[float]:
    t = Track(0.09)
    t.add(partials(0.08, [(1700, 0.012, 0.6)]), 0.0, 1.0)
    t.add(nbp(r, 0.03, 0.004, 3000, 4.0), 0.0, 0.5)
    return finish(t.data, fade_out_ms=8.0)


def ui_purchase(r: random.Random) -> list[float]:
    t = Track(0.46)
    t.add(bell(440, 0.30, 0.10), 0.0, 0.8)
    t.add(bell(660, 0.40, 0.20), 0.075, 1.0)
    t.add(nbp(r, 0.04, 0.01, 6000, 3.0), 0.075, 0.3)
    return finish(t.data)


def ui_deny(r: random.Random) -> list[float]:
    t = Track(0.28)
    for f, at in ((150.0, 0.0), (112.0, 0.11)):
        n = count(0.14)
        t.add(mul(lpf(square_sweep(n, f, f * 0.97), 750), env_exp(n, 0.07)), at, 0.9)
    t.add(nlp(r, 0.04, 0.01, 800), 0.0, 0.3)
    return finish(t.data)


def ui_drawer(r: random.Random) -> list[float]:
    t = Track(0.34)
    t.add(thump(0.08, 110, 80, 0.03), 0.0, 0.6)
    n = count(0.22)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 350, 1400), 1.5), env_bump(n)), 0.02, 2.5)
    t.add(nbp(r, 0.04, 0.008, 2800, 5.0), 0.25, 0.8)
    return finish(t.data)


def wave_start(r: random.Random) -> list[float]:
    t = Track(1.30)
    n = count(1.1)
    horn = [a + b for a, b in zip(saw_sweep(n, 98, 110), saw_sweep(n, 98.7, 111))]
    horn = lpf(horn, exp_curve(n, 300, 900))
    gate = [0.0] * n
    for lo, hi in ((0.0, 0.5), (0.55, 1.05)):
        a, b = count(lo), count(hi)
        for i, v in enumerate(env_bump(b - a)):
            gate[a + i] = v
    t.add(mul(horn, gate), 0.0, 0.7)
    t.add(mul(sine_sweep(n, 49, 55), gate), 0.0, 0.6)
    t.add(partials(0.5, [(147, 0.5, 0.4), (220, 0.4, 0.3)]), 0.0, 1.0)
    t.add(nhp(r, 0.08, 0.02, 500), 0.0, 0.7)
    return finish(softclip(t.data, 1.4), fade_out_ms=40.0)


def wave_clear(r: random.Random) -> list[float]:
    t = Track(1.0)
    t.add(bell(392, 0.60, 0.35), 0.0, 0.8)
    t.add(bell(587, 0.80, 0.50), 0.14, 0.9)
    n = count(0.8)
    t.add(mul(partials(0.8, [(196, 0.6, 0.4), (294, 0.5, 0.25)]), env_swell(n, 0.25, 0.4)), 0.0, 0.8)
    t.add(thump(0.20, 100, 60, 0.05), 0.0, 0.6)
    t.add(nbp(r, 0.04, 0.01, 3000, 4.0), 0.14, 0.4)
    return finish(t.data, fade_out_ms=40.0)


def intermission_tick(r: random.Random) -> list[float]:
    t = Track(0.12)
    t.add(partials(0.10, [(1100, 0.02, 0.6)]), 0.0, 1.0)
    t.add(nbp(r, 0.03, 0.004, 1800, 4.0), 0.0, 0.5)
    return finish(t.data, peak=0.6, fade_out_ms=12.0)


# ---------------------------------------------------------------------------------------------------------
# alerts and stingers
# ---------------------------------------------------------------------------------------------------------

def core_low(r: random.Random) -> list[float]:
    t = Track(0.78)
    t.add(thump(0.30, 68, 44, 0.09), 0.0, 1.0)
    t.add(nlp(r, 0.10, 0.05, 200), 0.0, 0.5)
    t.add(thump(0.28, 62, 40, 0.08), 0.24, 0.75)
    t.add(nlp(r, 0.10, 0.05, 200), 0.24, 0.4)
    t.add(partials(0.70, [(88, 0.30, 0.15)]), 0.0, 1.0)
    return finish(softclip(t.data, 1.3), peak=0.85, fade_out_ms=30.0)


def boss_stinger(r: random.Random) -> list[float]:
    t = Track(2.40)
    n = count(1.7)
    swell = env_swell(n, 1.6, 100.0)
    drone = [a + b for a, b in zip(saw_sweep(n, 41.2, 41.2), saw_sweep(n, 41.9, 41.9))]
    t.add(mul(lpf(drone, exp_curve(n, 120, 900)), swell), 0.0, 0.8)
    t.add(mul(sine_sweep(n, 41.2, 41.2), swell), 0.0, 0.7)
    t.add(mul(partials(1.7, [(220, 5.0, 0.2), (233.1, 5.0, 0.2)]), swell), 0.0, 0.8)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 400, 3000), 2.5), env_line(n, 0.0, 1.0)), 0.0, 1.4)
    t.add(thump(0.90, 90, 26, 0.30), 1.6, 1.2)
    t.add(partials(0.80, [(220, 0.5, 0.4), (331, 0.4, 0.3), (553, 0.3, 0.25)]), 1.6, 1.0)
    t.add(nhp(r, 0.30, 0.08, 600), 1.6, 0.8)
    t.add(nlp(r, 0.70, 0.30, 250), 1.6, 0.6)
    return finish(softclip(t.data, 1.6), fade_out_ms=120.0)


def victory(r: random.Random) -> list[float]:
    t = Track(3.20)
    for at, (fa, fb) in ((0.0, (220, 330)), (0.32, (330, 495)), (0.64, (440, 660))):
        t.add(bell(fa, 1.2, 0.5, ratio=2.0, index=1.4), at, 0.8)
        t.add(bell(fb, 1.2, 0.5, ratio=2.0, index=1.4), at, 0.7)
    n = count(2.5)
    trem = [0.85 + 0.15 * math.sin(2.0 * math.pi * 5.0 * i / SR) for i in range(n)]
    shimmer = partials(2.5, [(440, 1.2, 0.35), (660, 1.2, 0.3), (880, 1.0, 0.2), (1320, 0.8, 0.12)])
    t.add(mul(shimmer, trem), 0.64, 0.8)
    t.add(thump(0.50, 110, 55, 0.15), 0.64, 0.9)
    m = count(1.2)
    t.add(mul(bpf(noise(r, m), exp_curve(m, 800, 4000), 2.0), env_swell(m, 0.6, 0.4)), 0.5, 0.8)
    return finish(softclip(t.data, 1.2), fade_out_ms=200.0)


def defeat(r: random.Random) -> list[float]:
    t = Track(3.40)
    n = count(1.5)
    fall = lpf(saw_sweep(n, 320, 38), exp_curve(n, 2500, 90))
    t.add(mul(fall, mul(env_line(n, 1.0, 0.3), env_exp(n, 1.0))), 0.0, 0.9)
    t.add(mul(sine_sweep(n, 160, 30), env_exp(n, 0.9)), 0.0, 0.6)
    t.add(partials(3.0, [(110, 1.0, 0.35), (116.5, 1.0, 0.30), (220, 0.8, 0.15)]), 0.3, 1.0)
    t.add(thump(0.90, 80, 26, 0.30), 1.55, 1.1)
    t.add(nlp(r, 0.80, 0.30, 300), 1.55, 0.7)
    t.add(mul(fm_sweep(count(0.5), 880, 220, 1.41, 2.0, 0.0), env_exp(count(0.5), 0.2)), 0.0, 0.2)
    scatter(r, t, 10, 1.6, 2.6, (400, 1500), 3.0, 0.02, 0.3)
    return finish(softclip(t.data, 1.4), fade_out_ms=300.0)


# Order = ARCH 10 order. `finish` fixes the peak per sound, so relative loudness is tuned in the game's mix table.
RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "shot_pistol": shot_pistol,
    "shot_smg": shot_smg,
    "shot_turret": shot_turret,
    "reload_start": reload_start,
    "reload_done": reload_done,
    "hit_ceramic": hit_ceramic,
    "hit_armor": hit_armor,
    "death_small": death_small,
    "death_heavy": death_heavy,
    "death_boss": death_boss,
    "core_hit_light": core_hit_light,
    "core_hit_heavy": core_hit_heavy,
    "boss_stomp": boss_stomp,
    "emp": emp,
    "shield_up": shield_up,
    "shield_break": shield_break,
    "overdrive_on": overdrive_on,
    "overdrive_off": overdrive_off,
    "ui_tap": ui_tap,
    "ui_purchase": ui_purchase,
    "ui_deny": ui_deny,
    "ui_drawer": ui_drawer,
    "wave_start": wave_start,
    "wave_clear": wave_clear,
    "intermission_tick": intermission_tick,
    "core_low": core_low,
    "boss_stinger": boss_stinger,
    "victory": victory,
    "defeat": defeat,
}

STINGERS = ("boss_stinger", "victory", "defeat")
