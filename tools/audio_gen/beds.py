"""The two seamless loops: `ambience` (rain, hum, far metal) and `combat_drone` (low tension layer).

Seamlessness by construction: every tonal or modulating component has a whole number of cycles per loop, scattered
events wrap around the end of the buffer, and filtered noise is cross-faded (dsp.fold_loop) so the last sample is
followed by the natural continuation of the source.
"""
from __future__ import annotations

import math

from dsp import SR, TWO_PI, count, fold_loop, hp1, lp1, noise, peak_of, rng_for, sine_table

AMBIENCE_SECONDS = 20.0
DRONE_SECONDS = 16.0
LOOP_PEAK = 0.5


def cycles(tab: list[float], k: int, n: int, offset: int = 0) -> list[float]:
    """sin(2 pi (k i + offset) / n) for i in 0..n-1: exactly k cycles per loop. The wave repeats every
    n / gcd(k, n) samples, so one short period is built and tiled."""
    p = n // math.gcd(k, n)
    one = [tab[(k * i + offset) % n] for i in range(p)]
    return (one * (n // p + 1))[:n]


def _wrap_add(buf: list[float], start: int, sig: list[float], gain: float) -> None:
    n = len(buf)
    for i, s in enumerate(sig):
        buf[(start + i) % n] += gain * s


def _axpy(dst: list[float], src: list[float], gain: float) -> list[float]:
    return [d + gain * s for d, s in zip(dst, src)]


def _finish_loop(x: list[float]) -> list[float]:
    """Remove the mean and set the peak. No fades: a loop must not fade at its edges."""
    mean = sum(x) / max(len(x), 1)
    y = [s - mean for s in x]
    g = LOOP_PEAK / max(peak_of(y), 1e-9)
    return [s * g for s in y]


def ambience() -> list[float]:
    r = rng_for("loop_ambience")
    n = count(AMBIENCE_SECONDS)
    fade = count(2.0)
    tab = sine_table(n)

    # rain wash: band-limited noise with slow, whole-cycle level movement
    wash = hp1(hp1(lp1(lp1(noise(r, n + fade), 6500.0), 6500.0), 700.0), 700.0)
    wash = fold_loop(wash, n, fade)
    lfo_a = cycles(tab, 3, n)
    lfo_b = cycles(tab, 7, n, n // 5)
    rain = [w * (0.80 + 0.12 * a + 0.08 * b) for w, a, b in zip(wash, lfo_a, lfo_b)]

    # droplets: tiny decaying plinks at random positions, wrapped around the loop end
    drops = [0.0] * n
    templates = []
    for freq in (1900.0, 2600.0, 3300.0, 4100.0, 5000.0):
        templates.append([math.sin(TWO_PI * freq * j / SR) * math.exp(-j / (0.004 * SR)) for j in range(count(0.03))])
    for _ in range(300):
        pos = int(r.random() * n)
        tpl = templates[int(r.random() * len(templates))]
        _wrap_add(drops, pos, tpl, r.uniform(0.15, 0.6))

    # machine hum: partials at multiples of 0.05 Hz (whole cycles in 20 s), slow level beat
    hum = [0.0] * n
    for hz, amp in ((50.0, 0.5), (100.05, 0.25), (150.0, 0.12), (201.1, 0.05)):
        hum = _axpy(hum, cycles(tab, int(round(hz * AMBIENCE_SECONDS)), n), amp)
    beat = cycles(tab, 2, n)
    hum = [h * (0.75 + 0.25 * b) for h, b in zip(hum, beat)]

    # far pumps: low-passed noise breathing at a whole number of cycles per loop
    rumble = fold_loop(lp1(lp1(noise(r, n + fade), 140.0), 140.0), n, fade)
    breath = cycles(tab, 7, n)
    rumble = [u * (0.5 + 0.5 * b) for u, b in zip(rumble, breath)]

    # far metal: a few distant, low-passed clangs (inharmonic partials) wrapped around the loop end
    clang = [0.0] * count(2.5)
    for freq, tau, gain in ((233.0, 0.9, 1.0), (351.0, 0.6, 0.7), (497.0, 0.5, 0.5), (811.0, 0.3, 0.3)):
        for j in range(len(clang)):
            clang[j] += gain * math.sin(TWO_PI * freq * j / SR) * math.exp(-j / (tau * SR))
    clang = lp1(clang, 1200.0)
    clangs = [0.0] * n
    for _ in range(5):
        _wrap_add(clangs, int(r.random() * n), clang, r.uniform(0.05, 0.1))

    mix = [0.55 * a + 0.35 * b + 0.22 * c + 2.2 * d + e for a, b, c, d, e in zip(rain, drops, hum, rumble, clangs)]
    return _finish_loop(mix)


def combat_drone() -> list[float]:
    r = rng_for("loop_combat_drone")
    n = count(DRONE_SECONDS)
    fade = count(2.0)
    tab = sine_table(n)

    def partial(hz: float) -> list[float]:
        return cycles(tab, int(round(hz * DRONE_SECONDS)), n)

    mix = [0.0] * n
    mix = _axpy(mix, partial(41.25), 0.8)
    # two detuned low saws as additive harmonics (1/h), 0.125 Hz apart: a slow beat that closes within the loop
    for h in range(1, 7):
        mix = _axpy(mix, partial(82.5 * h), 0.3 / h)
        mix = _axpy(mix, partial(82.625 * h), 0.3 / h)
    mix = _axpy(mix, partial(123.75), 0.12)
    mix = _axpy(mix, partial(131.0), 0.05)
    low_noise = fold_loop(lp1(lp1(lp1(noise(r, n + fade), 220.0), 220.0), 220.0), n, fade)
    mix = _axpy(mix, low_noise, 6.0)
    # breathing and a slow machine pulse (whole cycles per loop)
    breath = cycles(tab, 1, n, n // 3)
    pulse = cycles(tab, 24, n)
    mix = [m * (0.8 + 0.2 * b) * (0.85 + 0.15 * p) for m, b, p in zip(mix, breath, pulse)]
    return _finish_loop(mix)


LOOPS = {
    "ambience": ambience,
    "combat_drone": combat_drone,
}
