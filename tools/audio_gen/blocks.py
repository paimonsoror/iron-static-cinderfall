"""Building blocks shared by every voices_*.py recipe file (moved out of voices.py so each file stays small).

Noise bursts, thumps, FM bells, scattered clicks and an electrical stutter gate. Nothing here draws from time or
OS entropy: every random choice goes through the `random.Random` the recipe was given.
"""
from __future__ import annotations

import math
import random

from dsp import (
    SR, Track, bpf, count, env_exp, fm_sweep, hpf, lp1, lpf, mul, noise, scale, sine_sweep,
)


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


def taper(x: list[float], ms: float) -> list[float]:
    """Linear fade over the last `ms` of a signal that would otherwise stop with a step."""
    k = min(len(x), max(1, int(ms * SR / 1000.0)))
    out = list(x)
    for i in range(k):
        out[len(x) - 1 - i] *= i / k
    return out


def rand_gate(r: random.Random, n: int, on_ms: tuple[float, float], off_ms: tuple[float, float]) -> list[float]:
    """Smoothed on/off gate with random segment lengths (electrical stutter)."""
    g: list[float] = []
    on = True
    while len(g) < n:
        lo, hi = on_ms if on else off_ms
        g.extend([1.0 if on else 0.0] * max(1, int(r.uniform(lo, hi) * SR / 1000.0)))
        on = not on
    return lp1(g[:n], 700.0)


def wrap_add(buf: list[float], start: int, sig: list[float], gain: float = 1.0) -> None:
    """Adds `sig` into `buf` at sample `start`, wrapping around the end (events of a seamless loop)."""
    n = len(buf)
    for i, s in enumerate(sig):
        buf[(start + i) % n] += gain * s


def mix_in(dst: list[float], src: list[float], gain: float) -> list[float]:
    return [d + gain * s for d, s in zip(dst, src)]


def with_rms(x: list[float], target: float) -> list[float]:
    """Scales `x` to the given RMS, so the parts of a loop are balanced by level and not by filter gain."""
    rms = math.sqrt(sum(s * s for s in x) / max(len(x), 1))
    return scale(x, target / rms) if rms > 1e-9 else list(x)


def finish_loop(x: list[float], peak: float = 0.89) -> list[float]:
    """Seamless-loop finish: remove the mean and set the peak. No fades (a loop must not dip at its edges)."""
    mean = sum(x) / max(len(x), 1)
    y = [s - mean for s in x]
    top = max((abs(s) for s in y), default=0.0)
    g = peak / top if top > 1e-9 else 0.0
    return [s * g for s in y]


def plateau(n: int, attack_s: float, release_s: float) -> list[float]:
    """A gate envelope: a linear attack, a hold at 1, a linear release (a horn blast)."""
    na = max(1, int(attack_s * SR))
    nr = max(1, int(release_s * SR))
    return [max(0.0, min(1.0, i / na, (n - 1 - i) / nr)) for i in range(n)]


def exciter(x: list[float], gain: float = 0.6, lo: float = 260.0, hi: float = 420.0, drive: float = 6.0) -> list[float]:
    """Bass harmonics for small speakers (a phone plays almost nothing below 300 Hz): saturates the low band of `x` and
    adds only the new upper harmonics, at `gain` times the level of `x`."""
    low = lpf(x, lo)
    top = max((abs(s) for s in low), default=0.0)
    if top < 1e-9:
        return list(x)
    harm = hpf([math.tanh(drive * s / top) for s in low], hi)
    return mix_in(x, with_rms(harm, gain * math.sqrt(sum(s * s for s in x) / max(len(x), 1))), 1.0)
