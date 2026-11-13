"""Variety weapon sounds (VARIETY_SPEC 12.1, group Weapons): the 15 sounds of the ten weapons of the roster.

Same kit and rules as voices.py: a recipe takes its own fixed-seed `random.Random` and returns a finished mono signal.
`lmg_spin` and `torch_loop` are the two held loops (AudioHeldVoices): they are built so that the last sample flows into
the first (whole cycles per loop, events that wrap around the end, folded noise) and are not faded at their edges.
"""
from __future__ import annotations

import random
from typing import Callable

from beds import cycles
from blocks import exciter, finish_loop, mix_in, nbp, nhp, rand_gate, scatter, thump, with_rms, wrap_add
from dsp import (
    Track, bpf, count, env_bump, env_exp, env_line, env_swell, exp_curve, finish, fm_sweep, fold_loop, hpf, lpf, mul,
    noise, partials, saw_sweep, sine_sweep, sine_table, softclip,
)


def shot_scattergun(r: random.Random) -> list[float]:
    """A wide, low blast: a crack, a heavy body of noise and a spray of pellet ticks (the pistol is a sharp single crack)."""
    t = Track(0.52)
    t.add(nhp(r, 0.07, 0.008, 900), 0.0, 1.0)
    n = count(0.40)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 6000, 500), 0.9), env_exp(n, 0.10)), 0.0, 1.0)
    t.add(thump(0.30, 170, 42, 0.07), 0.0, 1.2)
    t.add(nbp(r, 0.15, 0.04, 1100, 1.5), 0.0, 0.8)
    scatter(r, t, 8, 0.02, 0.30, (1500.0, 4500.0), 3.0, 0.006, 0.3)
    return finish(softclip(t.data, 2.0), fade_out_ms=25.0)


def shot_rifle(r: random.Random) -> list[float]:
    """A hard, high crack with a ringing tail: less body than the pistol, more bite than the SMG."""
    t = Track(0.34)
    t.add(nhp(r, 0.06, 0.005, 2200), 0.0, 1.0)
    t.add(thump(0.12, 230, 85, 0.025), 0.0, 0.8)
    t.add(nbp(r, 0.10, 0.02, 3300, 6.0), 0.0, 0.8)
    t.add(partials(0.25, [(1850, 0.07, 0.25), (2740, 0.05, 0.18)]), 0.003, 0.6)
    t.add(nbp(r, 0.22, 0.07, 1300, 1.8), 0.01, 0.4)
    return finish(softclip(t.data, 1.6))


def shot_hornet(r: random.Random) -> list[float]:
    """A missile leaves the rack: a small thump, then a hiss that rises and fades with a thin whine under it."""
    t = Track(0.52)
    t.add(thump(0.10, 190, 80, 0.03), 0.0, 0.9)
    t.add(nbp(r, 0.04, 0.008, 1800, 3.0), 0.0, 0.8)
    n = count(0.42)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 800, 3400), 1.3), env_bump(n)), 0.02, 2.2)
    t.add(mul(lpf(saw_sweep(n, 320, 980), 1800), env_bump(n)), 0.02, 0.22)
    return finish(softclip(t.data, 1.3), fade_out_ms=25.0)


def hornet_pop(r: random.Random) -> list[float]:
    """One missile pops on its target (six arrive in a salvo): a small bright burst, quiet and short."""
    t = Track(0.22)
    t.add(mul(sine_sweep(count(0.12), 900, 200), env_exp(count(0.12), 0.025)), 0.0, 0.8)
    t.add(nbp(r, 0.08, 0.015, 2600, 3.0), 0.0, 1.0)
    t.add(nhp(r, 0.03, 0.005, 3500), 0.0, 0.5)
    scatter(r, t, 3, 0.01, 0.12, (3500.0, 6000.0), 5.0, 0.004, 0.3)
    return finish(softclip(t.data, 1.3), fade_out_ms=20.0)


def shot_lmg(r: random.Random) -> list[float]:
    """One round of the light machine gun (4 to 10 a second): heavier than the SMG, with a brass clink."""
    t = Track(0.20)
    t.add(nhp(r, 0.06, 0.007, 1700), 0.0, 1.0)
    t.add(thump(0.10, 200, 70, 0.022), 0.0, 0.9)
    t.add(nbp(r, 0.10, 0.03, 1000, 2.0), 0.0, 0.7)
    t.add(nbp(r, 0.08, 0.015, 3600, 6.0), 0.002, 0.5)
    t.add(partials(0.10, [(2500, 0.012, 0.3)]), 0.05, 0.4)
    return finish(softclip(t.data, 1.6), fade_out_ms=15.0)


def lmg_spin(r: random.Random) -> list[float]:
    """HELD LOOP, 1 s: the barrel motor and the belt while the gun fires. Whole-cycle partials of 96 Hz, a 24 Hz chop and
    21 belt ticks a second at exact spacing, so the loop has no seam."""
    n = count(1.0)
    fade = count(0.25)
    tab = sine_table(n)
    motor = [0.0] * n
    for hz, amp in ((96, 0.8), (192, 0.45), (288, 0.30), (480, 0.18), (768, 0.08)):
        motor = mix_in(motor, cycles(tab, hz, n), amp)
    chop = cycles(tab, 24, n, n // 7)
    motor = [m * (0.78 + 0.22 * c) for m, c in zip(motor, chop)]
    belt = [0.0] * n
    step = n // 21
    for k in range(21):
        wrap_add(belt, k * step, nbp(r, 0.03, 0.006, r.uniform(1800.0, 3200.0), 4.0), r.uniform(0.6, 1.0))
    hiss = fold_loop(hpf(lpf(noise(r, n + fade), 4200.0), 900.0), n, fade)
    out = mix_in(mix_in(with_rms(motor, 0.30), with_rms(belt, 0.20), 1.0), with_rms(hiss, 0.10), 1.0)
    return finish_loop(out)


def shot_mortar(r: random.Random) -> list[float]:
    """The shell leaves the tube: a deep, hollow thunk with a long low tail and a thin whistle as it climbs."""
    t = Track(0.62)
    t.add(thump(0.45, 125, 36, 0.12), 0.0, 1.2)
    n = count(0.50)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 1400, 120), 0.9), env_exp(n, 0.13)), 0.0, 0.9)
    t.add(nbp(r, 0.10, 0.02, 650, 2.0), 0.0, 0.8)
    t.add(nhp(r, 0.03, 0.006, 1500), 0.0, 0.5)
    m = count(0.40)
    t.add(mul(sine_sweep(m, 700, 1500), env_swell(m, 0.15, 0.12)), 0.1, 0.12)
    return finish(softclip(exciter(t.data), 1.7), fade_out_ms=30.0)


def mortar_blast(r: random.Random) -> list[float]:
    """The slag shell lands: a heavy thump, a wet roar and a sizzle of the molten pool (blast_small has no sizzle)."""
    t = Track(1.05)
    t.add(thump(0.60, 105, 30, 0.16), 0.0, 1.2)
    n = count(0.80)
    t.add(mul(lpf(noise(r, n), exp_curve(n, 2400, 110), 0.9), env_exp(n, 0.22)), 0.0, 1.0)
    t.add(nhp(r, 0.05, 0.01, 800), 0.0, 0.8)
    m = count(0.80)
    fry = mul(hpf(noise(r, m), 2600), rand_gate(r, m, (2.0, 8.0), (3.0, 14.0)))
    t.add(mul(fry, env_exp(m, 0.28)), 0.08, 0.8)
    scatter(r, t, 10, 0.05, 0.70, (500.0, 2200.0), 3.0, 0.012, 0.35, power=1.3)
    return finish(softclip(exciter(t.data), 1.9), fade_out_ms=50.0)


def torch_loop(r: random.Random) -> list[float]:
    """HELD LOOP, 1 s: a cutting flame. A wide hiss, a low roar, a 110 Hz hum with a slow flicker and sparks that wrap
    around the end of the buffer."""
    n = count(1.0)
    fade = count(0.25)
    tab = sine_table(n)
    hiss = fold_loop(bpf(noise(r, n + fade), 3300.0, 0.9), n, fade)
    roar = fold_loop(lpf(noise(r, n + fade), 280.0), n, fade)
    hum = mix_in(cycles(tab, 110, n), cycles(tab, 220, n), 0.55)
    flicker = [0.80 + 0.12 * a + 0.08 * b for a, b in zip(cycles(tab, 9, n), cycles(tab, 17, n, n // 3))]
    sparks = [0.0] * n
    for _ in range(14):
        wrap_add(sparks, int(r.random() * n), nbp(r, 0.03, 0.004, r.uniform(4200.0, 7000.0), 5.0), r.uniform(0.4, 1.0))
    body = mix_in(mix_in(with_rms(hiss, 0.22), with_rms(roar, 0.16), 1.0), with_rms(hum, 0.08), 1.0)
    body = [b * f for b, f in zip(body, flicker)]
    return finish_loop(mix_in(body, with_rms(sparks, 0.10), 1.0))


def rail_charge(r: random.Random) -> list[float]:
    """The one-second wind-up of the rail lance: a capacitor whine that climbs from a hum to a scream, hiss opening
    up with it, then a short hold at the top. A smooth rise (the Lance Platform's charge is three seconds, in voices_bosses)."""
    t = Track(1.0)
    n = count(0.97)
    t.add(mul(fm_sweep(n, 150, 2600, 2.0, 1.0, 4.5), env_line(n, 0.15, 1.0)), 0.0, 0.7)
    t.add(mul(sine_sweep(n, 60, 330), env_line(n, 0.3, 1.0)), 0.0, 0.7)
    t.add(mul(bpf(noise(r, n), exp_curve(n, 700, 5200), 1.6), env_line(n, 0.0, 1.0)), 0.0, 1.3)
    t.add(mul(partials(0.97, [(3100, 5.0, 0.12), (4200, 5.0, 0.08)]), env_line(n, 0.0, 1.0)), 0.0, 0.8)
    return finish(softclip(t.data, 1.4), fade_out_ms=20.0)


def shot_rail(r: random.Random) -> list[float]:
    """The line discharges: a sub slam, a bright zip down the barrel and a ringing rail that hangs in the air."""
    t = Track(0.95)
    t.add(nhp(r, 0.05, 0.008, 1500), 0.0, 0.9)
    t.add(thump(0.55, 85, 26, 0.13), 0.0, 1.3)
    n = count(0.30)
    t.add(mul(fm_sweep(n, 5200, 420, 2.01, 3.5, 0.2), env_exp(n, 0.07)), 0.0, 0.7)
    t.add(partials(0.80, [(1750, 0.20, 0.30), (2690, 0.16, 0.22), (3320, 0.12, 0.16), (940, 0.22, 0.22)]), 0.0, 0.8)
    m = count(0.70)
    t.add(mul(lpf(noise(r, m), exp_curve(m, 3500, 200), 0.9), env_exp(m, 0.14)), 0.0, 0.7)
    scatter(r, t, 6, 0.05, 0.5, (2500.0, 6000.0), 5.0, 0.006, 0.3)
    return finish(softclip(exciter(t.data), 1.8), fade_out_ms=60.0)


def weapon_vent(r: random.Random) -> list[float]:
    """A heat weapon vents: a valve clank, then a long steam hiss that thins out."""
    t = Track(1.10)
    t.add(thump(0.10, 150, 70, 0.03), 0.0, 0.9)
    t.add(nbp(r, 0.05, 0.01, 1300, 4.0), 0.0, 1.2)
    t.add(partials(0.20, [(820, 0.04, 0.3), (1190, 0.03, 0.2)]), 0.0, 0.7)
    n = count(1.0)
    jet = mul(bpf(noise(r, n), exp_curve(n, 3600, 1500), 1.1), env_swell(n, 0.08, 0.38))
    t.add(jet, 0.03, 2.4)
    t.add(mul(hpf(noise(r, n), 5200), env_swell(n, 0.05, 0.25)), 0.03, 0.4)
    return finish(softclip(t.data, 1.2), fade_out_ms=60.0)


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


# The order of VARIETY_SPEC 12.1 (the group order of the table).
RECIPES: dict[str, Callable[[random.Random], list[float]]] = {
    "shot_scattergun": shot_scattergun,
    "shot_rifle": shot_rifle,
    "shot_hornet": shot_hornet,
    "hornet_pop": hornet_pop,
    "shot_lmg": shot_lmg,
    "lmg_spin": lmg_spin,
    "shot_mortar": shot_mortar,
    "mortar_blast": mortar_blast,
    "torch_loop": torch_loop,
    "shot_arc": shot_arc,
    "arc_chain": arc_chain,
    "rail_charge": rail_charge,
    "shot_rail": shot_rail,
    "weapon_vent": weapon_vent,
    "weapon_swap": weapon_swap,
}

# Sounds that a held voice loops (AudioHeldVoices): seam-free by construction, so no fade at the edges.
HELD_LOOPS = ("lmg_spin", "torch_loop")
