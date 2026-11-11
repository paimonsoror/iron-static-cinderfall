"""DSP primitives for the Cinderfall audio generator (Python 3.12 standard library only).

Signals are plain lists of floats at SR Hz, nominally in -1..1. Every random choice goes through a
`random.Random` seeded from a fixed per-sound constant (`rng_for`), so the output is deterministic.
"""
from __future__ import annotations

import math
import random
import struct
import wave
import zlib
from pathlib import Path

SR = 22050
TWO_PI = 2.0 * math.pi
SEED_SALT = 0x51F7A11  # fixed; changing it changes every sound


def count(sec: float) -> int:
    """Number of samples in `sec` seconds."""
    return int(round(sec * SR))


def rng_for(name: str) -> random.Random:
    """The fixed-seed generator of one sound (never time or OS entropy)."""
    return random.Random(zlib.crc32(name.encode("utf-8")) ^ SEED_SALT)


# ---------------------------------------------------------------------------------------------------------
# sources
# ---------------------------------------------------------------------------------------------------------

def noise(r: random.Random, n: int) -> list[float]:
    rnd = r.random
    return [rnd() * 2.0 - 1.0 for _ in range(n)]


def sine_sweep(n: int, f0: float, f1: float) -> list[float]:
    """Sine whose frequency glides exponentially from f0 to f1 over n samples."""
    out = [0.0] * n
    ph = 0.0
    ratio = f1 / f0
    den = max(n - 1, 1)
    for i in range(n):
        f = f0 * ratio ** (i / den)
        ph += TWO_PI * f / SR
        out[i] = math.sin(ph)
    return out


def fm_sweep(n: int, f0: float, f1: float, ratio: float, idx0: float, idx1: float) -> list[float]:
    """Two-operator FM: carrier glides f0 -> f1, modulator at carrier * ratio, index idx0 -> idx1."""
    out = [0.0] * n
    pc = 0.0
    pm = 0.0
    fr = f1 / f0
    den = max(n - 1, 1)
    for i in range(n):
        t = i / den
        f = f0 * fr ** t
        idx = idx0 + (idx1 - idx0) * t
        pc += TWO_PI * f / SR
        pm += TWO_PI * f * ratio / SR
        out[i] = math.sin(pc + idx * math.sin(pm))
    return out


def saw_sweep(n: int, f0: float, f1: float) -> list[float]:
    """Naive sawtooth with exponential glide. Always low-pass it afterwards."""
    out = [0.0] * n
    ph = 0.0
    ratio = f1 / f0
    den = max(n - 1, 1)
    for i in range(n):
        f = f0 * ratio ** (i / den)
        ph += f / SR
        ph -= math.floor(ph)
        out[i] = ph * 2.0 - 1.0
    return out


def square_sweep(n: int, f0: float, f1: float) -> list[float]:
    return [1.0 if s >= 0.0 else -1.0 for s in sine_sweep(n, f0, f1)]


def partials(dur: float, parts: list[tuple[float, float, float]]) -> list[float]:
    """Sum of decaying sines. Each part is (frequency Hz, decay tau seconds, gain)."""
    n = count(dur)
    out = [0.0] * n
    for freq, tau, gain in parts:
        k = TWO_PI * freq / SR
        decay = math.exp(-1.0 / (tau * SR))
        amp = gain
        for i in range(n):
            out[i] += amp * math.sin(k * i)
            amp *= decay
            if amp < 1e-5:
                break
    return out


# ---------------------------------------------------------------------------------------------------------
# envelopes and arithmetic
# ---------------------------------------------------------------------------------------------------------

def env_exp(n: int, tau: float, attack: float = 0.0008) -> list[float]:
    """Linear attack, then exp(-t / tau)."""
    na = max(1, min(n, int(attack * SR)))
    k = 1.0 / (tau * SR)
    e = [math.exp(-i * k) for i in range(n)]
    for i in range(na):
        e[i] *= i / na
    return e


def env_swell(n: int, rise: float, tau: float) -> list[float]:
    """Smooth rise over `rise` seconds, then exponential decay with tau."""
    nr = max(1, min(n, int(rise * SR)))
    k = 1.0 / (tau * SR)
    out = [0.0] * n
    for i in range(n):
        up = 0.5 - 0.5 * math.cos(math.pi * min(i / nr, 1.0))
        out[i] = up * (math.exp(-(i - nr) * k) if i > nr else 1.0)
    return out


def env_line(n: int, a: float, b: float) -> list[float]:
    den = max(n - 1, 1)
    return [a + (b - a) * i / den for i in range(n)]


def env_bump(n: int) -> list[float]:
    """Half-sine hump from 0 to 1 to 0."""
    den = max(n - 1, 1)
    return [math.sin(math.pi * i / den) for i in range(n)]


def mul(a: list[float], b: list[float]) -> list[float]:
    return [x * y for x, y in zip(a, b)]


def scale(a: list[float], g: float) -> list[float]:
    return [x * g for x in a]


def softclip(a: list[float], drive: float) -> list[float]:
    """tanh saturation. drive > 1 adds harmonics and compresses peaks."""
    return [math.tanh(drive * x) for x in a]


class Track:
    """A fixed-length mixing buffer. `add` sums a signal in at a time offset (seconds)."""

    def __init__(self, dur: float) -> None:
        self.n = count(dur)
        self.data = [0.0] * self.n

    def add(self, sig: list[float], at: float = 0.0, gain: float = 1.0) -> "Track":
        off = count(at)
        d = self.data
        n = self.n
        for i, s in enumerate(sig):
            j = off + i
            if j >= n:
                break
            d[j] += gain * s
        return self


# ---------------------------------------------------------------------------------------------------------
# filters
# ---------------------------------------------------------------------------------------------------------

def lp1(x: list[float], fc: float) -> list[float]:
    """One-pole low-pass (6 dB per octave)."""
    a = 1.0 - math.exp(-TWO_PI * fc / SR)
    y = 0.0
    out = [0.0] * len(x)
    for i, s in enumerate(x):
        y += a * (s - y)
        out[i] = y
    return out


def hp1(x: list[float], fc: float) -> list[float]:
    low = lp1(x, fc)
    return [s - l for s, l in zip(x, low)]


def _svf(x: list[float], fc: float | list[float], q: float, mode: str) -> list[float]:
    """Topology-preserving state-variable filter (stable for any cutoff below Nyquist).
    mode: 'low', 'band' (unity peak gain) or 'high'. `fc` may be a per-sample list."""
    k = 1.0 / q
    n = len(x)
    out = [0.0] * n
    ic1 = 0.0
    ic2 = 0.0
    varying = not isinstance(fc, (int, float))
    limit = SR * 0.45
    if not varying:
        g = math.tan(math.pi * min(float(fc), limit) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    for i in range(n):
        if varying:
            g = math.tan(math.pi * min(fc[i], limit) / SR)  # type: ignore[index]
            a1 = 1.0 / (1.0 + g * (g + k))
            a2 = g * a1
            a3 = g * a2
        s = x[i]
        v3 = s - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if mode == "low":
            out[i] = v2
        elif mode == "band":
            out[i] = k * v1
        else:
            out[i] = s - k * v1 - v2
    return out


def lpf(x: list[float], fc: float | list[float], q: float = 0.707) -> list[float]:
    return _svf(x, fc, q, "low")


def hpf(x: list[float], fc: float | list[float], q: float = 0.707) -> list[float]:
    return _svf(x, fc, q, "high")


def bpf(x: list[float], fc: float | list[float], q: float = 2.0) -> list[float]:
    return _svf(x, fc, q, "band")


def exp_curve(n: int, a: float, b: float) -> list[float]:
    """Per-sample exponential glide a -> b (for time-varying cutoffs)."""
    den = max(n - 1, 1)
    r = b / a
    return [a * r ** (i / den) for i in range(n)]


# ---------------------------------------------------------------------------------------------------------
# finishing, loops, output
# ---------------------------------------------------------------------------------------------------------

def peak_of(x: list[float]) -> float:
    return max((abs(s) for s in x), default=0.0)


def finish(x: list[float], peak: float = 0.89, fade_in_ms: float = 1.0, fade_out_ms: float = 10.0) -> list[float]:
    """Remove DC, fade the edges to exactly zero (no clicks), normalize to `peak`."""
    n = len(x)
    mean = sum(x) / max(n, 1)
    y = [s - mean for s in x]
    fi = min(n // 2, max(1, int(fade_in_ms * SR / 1000.0)))
    fo = min(n // 2, max(1, int(fade_out_ms * SR / 1000.0)))
    for i in range(fi):
        y[i] *= i / fi
    for i in range(fo):
        y[n - 1 - i] *= i / fo
    p = peak_of(y)
    g = peak / p if p > 1e-9 else 0.0
    return [s * g for s in y]


def fold_loop(buf: list[float], n: int, fade: int) -> list[float]:
    """Make a seamless loop of n samples from a buffer of n + fade samples.

    The first `fade` samples are cross-faded (equal power) with the `fade` samples that follow position n, so
    the last output sample is followed by the natural continuation of the source at the loop point."""
    out = buf[:n]
    for i in range(fade):
        t = i / fade
        w_in = math.sin(0.5 * math.pi * t)
        w_out = math.cos(0.5 * math.pi * t)
        out[i] = buf[i] * w_in + buf[n + i] * w_out
    return out


def sine_table(n: int) -> list[float]:
    """table[j] = sin(2 pi j / n): a partial with k cycles per loop is table[(k * i) % n]."""
    return [math.sin(TWO_PI * j / n) for j in range(n)]


def pcm16_bytes(x: list[float]) -> bytes:
    ints = [max(-32767, min(32767, int(round(s * 32767.0)))) for s in x]
    return struct.pack("<%dh" % len(ints), *ints)


def write_wav(path: Path, x: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm16_bytes(x))
