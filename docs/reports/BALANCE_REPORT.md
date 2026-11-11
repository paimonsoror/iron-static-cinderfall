# Balance report - W2-D (sim harness, determinism, tuning)

Every number below comes from a deterministic run of the real `SimWorld.step()` (60 ticks per second, same seed gives the same
hashes). Commands to reproduce, from the project root (use the worktree root in a worktree):

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\balance_run.ps1 -Runs 20              # the verdict below
powershell -NoProfile -ExecutionPolicy Bypass -File tools\sim_run.ps1 -Seed 1 -Policy greedy -Runs 5
powershell -NoProfile -ExecutionPolicy Bypass -File tools\balance_run.ps1 -Runs 20 -Data <dir>  # an experiment on a copy of data/
```

## 1. Verdict

With the **first lever only** (spawn counts, intervals and start offsets in `data/waves.json`) every GDD 8.4 target is met over
20 seeds. No enemy stat, weapon number, ability number or other `data/*.json` value was changed.

| GDD 8.4 target | Baseline data | Tuned data |
|---|---|---|
| First-win run length 270 to 360 s | 244 s (WARN) | **291 s** (289 to 294) PASS |
| Peak alive per wave 10 / 18 / 28 / 40 / 50, each +/-20% | 1 / 9 / 9 / 4 / 7 (5 x WARN) | **9 / 16 / 28 / 41 / 50** PASS |
| A bot that buys nothing loses (defeat by wave 3 or 4) | 20/20 defeated in wave 3, 134 s | 20/20 defeated in wave 3, 122 s PASS |
| Greedy bot wins with 30% to 80% core HP | 20/20 wins, core 92% (min 80, max 100) (WARN) | 20/20 wins, core **71%** (min 61, max 81) PASS |

`balance_run.ps1 -Runs 20`, last line on the tuned data: `BALANCE: PASS rows=10 pass=10 warn=0 fail=0 runs=40`
(on the baseline data: `BALANCE: WARN rows=10 pass=3 warn=7 fail=0 runs=40`).

What the targets cost (the trade-offs to review):

- Enemies per run 285 to 384 (+35%): wave 1 16 to 28, wave 2 36 (same count), wave 3 54 to 95, wave 4 76 to 96, wave 5 103 to 129.
- Scrap from a full clear 6,690 to 9,000 (+35%). Buying everything still costs 11,496, so a run still cannot buy it all (78%
  of the tree is affordable), but the choice is less tight than GDD 5.2 says.
- The duration floor margin is 21 s (291 s against 270 s). Duration is bounded by the total enemy work divided by the kill
  rate of the player (section 6).

Peaks, duration and core HP are measured on the **greedy bot** (the reference player). The no-buy bot sees peaks 10 / 17 / 40
in waves 1 to 3 because it kills slowly.

## 2. How the targets are measured

`SimHarness.run` plays one seed to the end with a `PolicyBot`; `BalanceTargets` turns 20 greedy and 20 no-buy runs into rows.

- PASS: inside the band. WARN: a measured value (duration, a peak, core HP, win rate, no-buy death wave) is outside its band; the
  number is printed, nothing is hidden. FAIL: a structural rule broke (a no-buy run wins, greedy wins under half its runs, a run did
  not finish, or a sim invariant was violated). `balance_run` exits 0 on PASS and WARN, 1 on FAIL.
- Peaks: the **median over seeds** of `stats.peak_alive_by_wave`, band target +/-20%.
- Duration and core HP: the **mean over greedy victories**; bands 270 to 360 s and 30% to 80%.
- No-buy bot: every run defeated, with `world.wave` 3 or 4 when the core fell.
- Greedy bot (`PolicyBot.Policy.GREEDY`): at most one purchase per tick, the cheapest upgrade that is buyable right now (ties:
  SMG, damage, fire rate, armor piercing, turret); never saves up. EMP at 12 or more attackers, shield when the core just lost
  integrity, overdrive when the boss is alive **and in the Warden's range** (ARCH 6.7 says "alive"; in range is the same trigger
  without wasting the 6 s window while the boss still walks). On the tuned data a greedy run buys 16 upgrades, fires EMP once,
  the shield 3 times, overdrive once, and spends 7,934 of 9,000 Scrap.
- Seeds change only the spawn-position jitter, so runs of one data set are close together (duration within 5 s, peaks within 1 to 3).

## 3. Baseline (untouched data = `docs/handoff/03_DATA`, 20 seeds)

| Wave | Greedy peak | Greedy clear (s) | Greedy core lost | Scrap | No-buy peak | No-buy core lost |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 25.9 | 0 | 320 | 1 | 0 |
| 2 | 9 | 45.9 | 0 | 810 | 12 | 719 |
| 3 | 9 | 43.2 | 0 | 1,260 | 23 | 281 (dead) |
| 4 | 4 | 39.0 | 0 | 1,610 | - | - |
| 5 | 7 | 55.2 | 78 | 2,690 | - | - |

The greedy bot clears every wave before the next crowd forms: the baseline is spawn-limited, not kill-limited. That is the
"density vs duration" risk of KNOWN_RISKS in numbers (GDD 7: the pistol kills a Skitter about every 1.1 s, the first buys make it
faster, and the baseline intervals 1.7 / 1.1 / 0.85 / 0.68 / 0.55 s never let a crowd form).

## 4. Tuned (same 20 seeds)

| Wave | Greedy peak | Greedy clear (s) | Greedy core lost (mean) | Scrap | No-buy peak | No-buy core lost |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 9 | 28.5 | 0 | 560 | 10 | 72 |
| 2 | 16 | 49.3 | 177.8 | 810 | 17 | 802.8 |
| 3 | 28 | 57.8 | 3.6 | 2,260 | 40 | 125.2 (dead, wave 3) |
| 4 | 41 | 58.9 | 93.6 | 2,080 | - | - |
| 5 | 50 | 59.5 | 14.4 | 3,290 | - | - |

Greedy purchases, seed 1 (wave @ tick): fire rate w1@704, damage w1@1222, armor piercing w1@1840, fire rate w2@3041, damage
w2@3835, SMG w2@5331, turret w3@6313, armor w3@6733, fire rate w3@7153, damage w3@7877, fire rate w3@9241, armor w4@10280,
turret w4@10828, damage w5@13899, fire rate w5@14540, armor w5@15510.
The queue behind the 50 cap is used lightly in the real game (`max_queue` 5 to 6 per greedy run, 0 stuck recoveries in seeds 1 to 5);
the 10-minute stress test fills it to 270 and sees 12 stuck recoveries, all handled.

## 5. Changes (`data/waves.json`, group by group)

Format: count x type @ start s / interval s. `region`, `peak_target` and `index` are unchanged.

| Wave | Group | Before | After |
|---|---|---|---|
| 1 | skitter | 16 @ 0 / 1.7 | 28 @ 0.5 / 0.75 |
| 2 | skitter | 30 @ 0 / 1.1 | 30 @ 0 / 0.52 |
| 2 | hollow_warden | 6 @ 8 / 4 | 6 @ 21.5 / 5.08 |
| 3 | skitter | 42 @ 0 / 0.85 | 71 @ 0 / 0.3 |
| 3 | hollow_warden | 12 @ 5 / 2.6 | 24 @ 8.5 / 1.8 |
| 4 | skitter | 58 @ 0 / 0.68 | 64 @ 0 / 0.12 |
| 4 | rusher | 18 @ 7 / 1.8 | 32 @ 6 / 1.7 |
| 5 | skitter | 72 @ 0 / 0.55 | 90 @ 0 / 0.1 |
| 5 | rusher | 20 @ 10 / 1.65 | 24 @ 8 / 1.8 |
| 5 | hollow_warden | 10 @ 14 / 3 | 14 @ 5 / 2.6 |
| 5 | siege_hulk | 1 @ 18 | 1 @ 45 |

The `note` string of `waves.json` now points at this report. Nothing else under `data/` changed.

Why each family of change (from the runs in section 7):

- **Intervals down** (0.55 s to 0.1 s in wave 5, 1.7 s to 0.75 s in wave 1): a crowd only forms when spawns outrun kills. Peaks go
  from 1 / 9 / 9 / 4 / 7 to 9 / 16 / 28 / 41 / 50. Wave 4 now sends 64 skitters in 7.7 s and wave 5 sends 90 in 9 s.
- **Counts up** (+35%): added to reach the duration floor (a wave lasts about its enemy count over the kill rate once a crowd exists).
  The search moved counts and intervals together, so their effects were not isolated in separate runs. Counts also raise Scrap; that is
  the price named in section 1.
- **Hollow Wardens later and wider apart in wave 2** (start 8 to 21.5 s, interval 4 to 5.08 s): with a 0.5 s skitter stream they
  arrived on top of it and the no-buy bot died in wave 2 (it must die in wave 3 or 4). Now it loses 72 / 803 / dead over waves 1 / 2 / 3.
- **Boss at 45 s instead of 18 s**: with this bot the Hulk lives 14.5 to 18.6 s from spawn to death (seeds 1 to 5), so the end of wave 5 is
  the boss start plus that, once the start is later than the escorts' tail. Measured on the final family, 2 seeds, whole-run seconds: boss
  start 18 s gives 282, 26 s 282, 34 s 284, 40 s 288, 44 s 293, 48 s 296. 45 s buys the duration margin; the greedy core mean (66% on those two
  seeds) and the wave 5 peak (50) did not change between 18 s and 48 s.

## 6. What would move the remaining margins

- **Duration (291 s, floor 270 s)**: more enemies in the last waves, or more Hollow Warden / Hulk HP (lever 2). A later boss start
  adds time roughly one for one past ~36 s (40 s to 48 s: 288 to 296 s) but the boss then arrives mostly alone.
- **Wave 5 is easy for the greedy bot** (14 core lost on average, boss dead in 14 to 19 s). It is the hardest wave for a player who
  did not buy (that player never reaches it).
- **Wave 1 peak 9 (band 8 to 12) and wave 2 peak 16 (band 14.4 to 21.6)** sit near the low edge of their bands; the economy path
  couples all waves (a small change in wave 1 shifted the wave 4 peak from 41 to 34.5 in an experiment below).
- The bot is a measuring stick, not a player. A human who reacts better than the greedy bot will see lower core losses; one who
  buys badly will see higher.

## 7. Experiments tried (greedy unless marked; 2 to 3 seeds)

| Experiment | Result |
|---|---|
| Intervals only, all waves shrunk (wave 1 0.45 s, wave 2 0.5 s, baseline counts) | Both bots defeated in wave 2 (core lost 944 to 988 in wave 2): the early bot is too weak for that density |
| The same plus Skitter speed 2.3 to 1.3 m/s (lever 2) | Greedy survives wave 2 (668 lost) and falls in wave 3; speed alone does not make the ramp fair, and it was not needed later |
| Per-wave annealing search over counts, starts and intervals, one wave at a time (earlier waves fixed) | Found waves 1 to 3 (peak 10 / 14 / 27, no extra core loss in wave 3). Waves 4 and 5 were then built by hand in the same family |
| First manual waves 4 and 5 (skitters 0.12 s / 0.1 s, rusher and hollow tails) | Peaks 10 / 14 / 29 / 41.5 / 50, 269 s, core 72%: 8 PASS, 2 WARN (wave 2 peak 14, duration 269 s) |
| Wave 2 skitter interval 0.50 s | Peak 16 but the no-buy bot died in wave 2 on one of two seeds (WARN) |
| Wave 2 skitter interval 0.54 s | 10/10 PASS: peaks 10 / 15 / 29 / 41 / 50, 282 s, core 56% (wave 2 peak nearer its floor) |
| Wave 2 at 0.52 s with wave 1 at 0.75 s | 10/10 PASS: 9 / 16 / 29 / 41 / 50, 282 s, core 66%. Kept |
| Wave 1 count 32 and wave 2 hollows 5.4 to 5.8 s apart | 289 to 290 s but the extra early Scrap shifted the economy: wave 2 peak 14, wave 4 peak 34.5 (WARN). Rejected |
| Boss start 18 / 26 / 34 / 40 / 44 / 48 s | See section 5; 45 s chosen |

The enemy table (HP, speed, armor, damage, period) and the weapon numbers were never needed and stay as in GDD 5 and 6.

## 8. Other measurements

- Speed: 0.09 to 0.28 ms per tick on a shared machine for whole runs (60x to 180x real time); the 10-minute stress run at the cap
  of 50 averages 0.12 to 0.53 ms per tick depending on machine load (limit 1.0 ms).
- `debug_damage_mult = 5`: the greedy bot wins with the core untouched (3 seeds: core 1000/1000, 263.6 to 264.0 s, peaks 1 / 2 / 3 / 8 / 6 to 7).
  The **no-buy bot is still defeated in wave 3 (116 s)**: with the tuned floods the pistol's cadence, not its damage, limits the kill rate.
  On the baseline data the same no-buy x5 run reached wave 5 (the coordinator's smoke test). The integration test therefore plays the greedy bot.
- Wide invariant sweep with `HarnessChecker` on the tuned data: 190 runs, 0 violations, 0 unfinished runs. Seeds 100 to 129 both policies
  (30/30 greedy wins, 30/30 no-buy defeats); damage x0.6, seeds 200 to 214 (0/15 greedy wins, 15/15 no-buy defeats); damage x2, seeds 300 to 314
  (15/15 greedy wins); start Scrap 3,000, seeds 400 to 414 (15/15); damage x5, seeds 500 to 509 (10/10); damage x0.4 with 1,500 start Scrap,
  seeds 600 to 609 (0/10). The no-buy bot lost in every case (also at damage x2 and x5); the greedy bot lost only with damage x0.6 or x0.4.
  The same sweep on the intermediate data (boss at 34 s) was also clean (190 runs).

## 9. Needs owner

- GDD section 7 (wave table: counts, intervals, Scrap column, totals 285 to 384, boss at 45 s), section 5.2 ("A full clear pays
  6,690" is now 9,000) and section 8.4 (note that the baseline reached none of the peak targets and the tuned data reaches all): not
  in W2-D's paths. The untouched baseline stays in `docs/handoff/03_DATA/` and `tests/fixtures/data_baseline/`.
- If the owner wants Scrap to stay near 6,690, the way to keep the targets is lever 2 (enemy HP up instead of counts up). That is a
  design decision and was not taken here.
