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

---

# Part 3 - V5-C: the 15-wave game tuned with the scorecard (values only)

Branch `task/V5-C`, from `main` at `a3b177f`. Only numbers in `data/*.json` changed: 93 values in `run.json`, `enemies.json`,
`events.json`, `weapons.json` and `vertical_slice_balance.json`. No id, schema field, list length or list order changed (a
structural JSON diff against `a3b177f` lists value changes only). `directives.json` and `data/strings/` are untouched.
`tests/fixtures/data_variety/` is a byte copy of `data/` and `data/strings/` again. Part 2 (the earlier wave) is not in this
file on `a3b177f`; its "before" numbers are V5-A's scorecards (`C:\dev\tower-two-wt\V5-A\build\v5a\sc_base.txt`, `sc_full.txt`).

## 3.1 Verdict

`tools\scorecard_run.ps1 -Runs 30` (330 runs per pool, 8 policies plus balanced hot and other-pool variants), before (V5-A on
`a3b177f`) and after (this branch, `b093f3f` data):

| Row | Target | Base before | Base after | Full before | Full after |
|---|---|---|---|---|---|
| integrity | 0 unfinished, 0 unclean | PASS | PASS (0 / 0) | PASS | PASS (0 / 0) |
| S1 core spread at act I end | stdev >= 0.12 | PASS 0.332 | **WARN 0.004** | PASS 0.282 | WARN 0.055 |
| S2 duration spread | stdev >= 45 s | WARN 30.1 s | WARN 44.5 s | WARN 15.9 s | WARN 24.0 s |
| S3 build overlap | median <= 0.35 | WARN 0.368 | WARN 0.550 | PASS 0.167 | PASS 0.259 |
| S4 balanced wins | 40% to 70% | PASS 53% | PASS 63% | WARN 23% | **PASS 67%** |
| S5 random wins | <= 10% | PASS 0% | PASS 0% | PASS 0% | PASS 3% |
| S6 none always dies in act I | - | PASS | PASS | PASS | PASS |
| S7 greedy wins | 10% to 40% | WARN 0% | WARN 0% | WARN 0% | WARN 0% |
| S8 early deaths | 0 before w3, <= 2% before w4 | WARN 8 / 12% | **PASS 0 / 0%** (1 of 210) | WARN 9 / 12% | **PASS 0 / 0%** (1 of 210) |
| S9 where balanced loses | each act >= 15%, boss 25-50% | PASS 21/50/29, 43% | **WARN 0/0/100, 36%** | WARN 13/74/13, 9% | WARN 0/10/90, 20% |
| S10 other policies | 15% to 65% each | WARN 20/0/7/37 | WARN 33/3/13/43 | WARN 3/0/0/3 | WARN 27/3/10/50 |
| S11 build signatures | >= 8 at 4%, none > 25% | WARN 2, top 71% | WARN 5, top 66% | PASS 9, top 11% | PASS 12, top 19% |
| S12 weapon shares | none > 30%, all >= 3% | WARN AR 97% | WARN AR 91% | WARN LMG 56% | WARN LMG 38% |
| S13 directive swings | within +/-15 points | WARN +70 | WARN +66 | WARN +57 | WARN +86 |
| S14 hot routes pay | 25-65% both, hot more Data | WARN 60% 231 / 33% 152 | WARN 77% 268 / 50% 252 | WARN 20% 122 / 3% 72 | WARN 60% 242 / 50% 239 |
| S15 pools | within 5 points | WARN -30 | **PASS +3.3** | WARN -30 | **PASS +3.3** |
| S16 win length | median 780 to 1,020 s | WARN 569 s | **PASS 833 s** | WARN 600 s | **PASS 863 s** |
| S17 density table | within 20% | WARN 15 waves | WARN 15 waves | WARN 15 waves | WARN 15 waves |
| S18 greedy act I loss | <= 60% in one wave | WARN 100% | **PASS 42%** | WARN 99% | WARN 76% |
| **verdict** | | WARN 6 / 13 / 0 | **WARN 8 / 11 / 0** | WARN 6 / 13 / 0 | **WARN 9 / 10 / 0** |

Verdict lines: base `SCORECARD: WARN rows=19 pass=8 warn=11 fail=0 runs=330`; full `SCORECARD: WARN rows=19 pass=9 warn=10 fail=0 runs=330`.
S10 lists hoarder / spammer / turret_rush / risk. Policies on base after: none 0%, greedy 0% (median death wave 6 -> 10),
random 0%, hoarder 33%, spammer 3%, turret_rush 13%, balanced 63% (median death wave 7 -> 13), risk 43%. On full: none 0%,
greedy 0% (6 -> 7), random 3%, hoarder 27%, spammer 3%, turret_rush 10%, balanced 67% (6 -> 12), risk 50%.

The headline: balanced wins 63% on base and 67% on full (both inside 40% to 70%), and a balanced win takes a median of
833 s of combat on base (863 s on full): 13.9 minutes, inside the owner's 13 to 17. 60-seed balanced-only screens on the same
values (the scratch harness `build/v5c/exp_run.gd`, the scorecard's job code with a policy filter) gave 63% / 834 s on base and
58% / 857 s on full.

`tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` (base pool, same `b093f3f` data), `SIM SUMMARY: runs=20 victories=13 defeats=7`:

| | Before (V5-A) | After |
|---|---|---|
| Wins | 11 | 13 |
| Win length (`seconds`) | 574 to 669 s, mean 621 s | 766 to 923 s, mean 877 s |
| Losses by death wave | 5 (1), 6 (3), 10 (3), 11 (2), 14 (1), 15 (2) | 11 (1), 12 (2), 13 (1), 14 (1), 15 (2) |
| Speed | 0.35 ms a tick | 0.382 ms a tick (375 s wall for 20 runs) |

NOT RUN on the final values (section 3.9): `scorecard_run -Runs 200` (both pools), `balance_run -Runs 20`, `check.ps1`, and the
test groups after the re-recorded numbers.

## 3.2 Method

- Every round changed a few related values and played them with the scorecard's own job code (`build/v5c/exp_run.gd` writes
  the same run records as `tools/scorecard_run.gd`; on the untouched data it reproduced V5-A's two cards row for row). A weapon
  bench (`build/v5c/bench.gd`: one weapon alone in slot 0, balanced, 8 seeds, waves 4 / 7 / 12, core lost) rated each weapon.
- What the runs showed about the bots, which decides what values can reach:
  1. `balanced` and `risk` change weapon only by the boss rule or the crowd rule (12 enemies in reach). `greedy`, `spammer`,
     `turret_rush` and `random` never change weapon: they fire slot 0, the pistol, until a second crate replaces it. A crate
     weapon goes to the empty slot 1, so act I is a pistol game for every bot.
  2. The salvage choice is tier-greedy: any T4 or T5 weapon replaces the assault rifle. On `a3b177f` the cutting torch, the
     rail lance and the hornet rack lost to the rifle alone (bench: core lost 1.0 at wave 12), so the full pool, which offers
     them, won 23% against 53%. That was most of the S15 gap.
  3. Waves are window-limited: a wave lasts its `window_s` plus a short tail, so the run length is about the sum of the windows.
  4. On the full pool both turret pads carry the arc and the mortar turret; the gun turret is never built there.
  5. Unfinished runs came from reclaimers parked 13 to 16 m from the Warden (out of reach of a 13 m weapon or a squall-shortened
     torch) healing each other as fast as one turret hurt them.

## 3.3 Changes (file, key, before, after, reason)

`waves[n]` is wave n and `acts[n]` is act n (the JSON index is n - 1). "Threat a second" is the wave budget over its window.

| File | Key | Before | After | Reason |
|---|---|---|---|---|
| run.json | `waves[1..5].window_s` | 22 / 26 / 28 / 30 / 40 | 33 / 39 / 42 / 45 / 80 | S16: wins took 569 s; normal waves x1.5, the boss wave inside SPEC 2.2's 70 to 100 s |
| run.json | `waves[6..10].window_s` | 30 / 32 / 34 / 36 / 50 | 45 / 48 / 51 / 54 / 90 | S16, as above (the windows now add up to 861 s, from 544 s) |
| run.json | `waves[11..15].window_s` | 36 / 38 / 40 / 42 / 60 | 54 / 57 / 60 / 63 / 100 | S16, as above |
| run.json | `waves[3].budget`, `waves[4].budget` | 46, 60 | 42, 66 | S8: 8 runs died before wave 3 and 25 before wave 4; wave 3 drops from 1.6 to 1.0 threat a second, wave 4 (45 s) carries the act |
| run.json | `waves[5].budget` | 36 | 50 | the act I boss wave lasts 80 s (was 40): the escort follows (0.9 -> 0.63 threat a second) |
| run.json | `waves[6].budget` | 78 | 80 | the wave 6 spike: 2.6 -> 1.8 threat a second in the longer window |
| run.json | `waves[7..9].budget` | 92 / 108 / 124 | 98 / 118 / 138 | act II stays a fight in the longer windows (3.0-3.4 -> 2.0-2.6 threat a second) |
| run.json | `waves[10].budget` | 70 | 100 | the act II boss wave lasts 90 s (was 50) |
| run.json | `waves[11..14].budget` | 140 / 156 / 172 / 190 | 185 / 210 / 235 / 265 | S4: balanced won 75 to 80% with the old act III; 3.4 to 4.2 threat a second (was 3.9 to 4.5) at x2.2 plating |
| run.json | `waves[15].budget` | 120 | 175 | the last boss wave lasts 100 s (was 60) |
| run.json | `waves[1].peak_minis` | 0 | 6 | S17, item 9: wave 1 is the fixed `pack_tide`, 30% motes (CONTENT 1.3), so 0 minis contradicts the spec; 6 is what its motes give in 33 s (measured median 5) |
| run.json | `acts[3].hp_mult` | 1.8 | 2.2 | S4: after the weapon fixes balanced won 75 to 80%; act III plating brings it to 63% without touching act I (S8, S18) |
| run.json | `pack_repair` shares reclaimer / hollow_warden | 0.15 / 0.45 | 0.10 / 0.50 | integrity: fewer reclaimers a wave to chain-heal (the pack still spends its budget) |
| run.json | `mod_squall` range | x0.7 | x0.8 | S14: hot routes won 33% against 60% |
| run.json | `mod_static_air` cooldown rate | x0.5 | x0.65 | S14, as above |
| run.json | `mod_low_power` turret_offline_ticks | 720 (12 s) | 480 (8 s) | S14: 12 s was a quarter of a 45 s wave without turrets |
| run.json | `weight_hot` rw_scrap / rw_rare_draft / rw_double_pick / rw_data | 10 / 20 / 12 / 8 | 5 / 18 / 20 / 15 | S14 "risk must pay": the hot table leans to Data and double picks |
| run.json | `rw_data` ops n | 15 | 25 | S14: the Data a hot route promises |
| run.json | `draft.buyout_base` / `buyout_step` | 250 / 100 | 350 / 150 | the longer, larger waves pay more Scrap: balanced bought an extra card in most drafts (S4 above 70%) |
| run.json | `draft.patch_base` / `patch_step` | 180 / 90 | 220 / 110 | as above, for core patches |
| enemies.json | `overrides.rusher.cost` | 1.5 | 2.0 | 23 core damage a second each (three skitters' worth); FAST BREACH in wave 2 killed 11 of 45 runs (S8) |
| enemies.json | `lance_platform` hp (enemy and boss) / armor / core_damage | 2000 / 10 / 160 | 1700 / 6 / 120 | the act I boss pair: the lance took 41% of balanced's core against 7% for the brood carrier, and all of a pistol build's (S18) |
| enemies.json | `brood_carrier` hp (enemy and boss) | 2400 | 2100 | S18: greedy lost 100% of its core in wave 5 with the pistol |
| enemies.json | `reclaimer` heal_per_s / tether_count / armor / cost | 14 / 3 / 4 / 5.0 | 5 / 2 / 2 / 6.0 | integrity: chained reclaimers out-healed one turret (still 24 HP a second for three of them at a first cut to 9); unfinished runs |
| enemies.json | `reclaimer.standoff_m` | 12.5 | 10.5 | integrity: parked inside the reach of a 13 m weapon; 10.5 m is the spitter ring (at most 15.1 m from the Warden) |
| enemies.json | `bosses.siege_hulk.hp` | 9000 | 10000 | the last boss after the weapon fixes (S4, act III share of the run) |
| events.json | `core_vent.core_cost_frac` | 0.08 | 0.04 | the spammer vented every wave and lost core for nothing (S10); 4% keeps it a cost |
| weapons.json | `scattergun` damage / pellets (L3) / range_m | 10 / 8 (12) / 9 | 16 / 10 (14) / 13 | S12 under 3%: at 9 m it fired only once the core was hit; never-swapping bots holding it died in waves 6 to 8 |
| weapons.json | `assault_rifle.damage` | 28 | 26 | S12: the rifle was in 97% of base wins |
| weapons.json | `lmg.damage` | 20 | 18 | S12: 56% of full-pool wins |
| weapons.json | `hornet_rack` damage / splash / shots_per_second | 24 / 10 / 0.45 | 48 / 18 / 0.5 | S15: a trap tier (bench 0.95 to 1.0 core lost) that the tier-greedy salvage takes over the rifle |
| weapons.json | `slag_mortar` damage / shots_per_second / area_m | 80 / 0.8 / 2.6 | 150 / 0.9 / 3.0 | S15, S12: bench 0.94 |
| weapons.json | `cutting_torch` damage / ramp / cap (L3) / range / heat | 4 / 0.5 / 16 (22) / 13 / 3 | 12 / 1.2 / 28 (34) / 20 / 2 | S15: the T4 trap (bench 1.0 -> 0.35); heat_per_shot must be an integer |
| weapons.json | `arc_projector` damage / heat_per_shot | 40 / 14 | 50 / 12 | S12, S15: bench 0.80 -> 0.53 |
| weapons.json | `rail_lance` damage / rate / magazine (L3) / reload / area / charge | 320 / 0.45 / 3 (4) / 2.6 / 0.5 / 1.0 | 240 / 1.2 / 6 (8) / 2.0 / 1.4 / 0.6 | S15: the T5 trap (bench 1.0 -> 0.12): one line every 2+ s lost to the rifle alone |
| weapons.json | `turret_gun.damage` | 12 | 15 | S10 turret_rush 7%; with reclaimers, one turret could not out-damage the heals |
| weapons.json | `turret_arc.range_m` | 12 | 14 | from a pad 2.9 m off the core, 12 m did not reach the far side of the 10.5 m ring (13.4 m) |
| weapons.json | `turret_mortar` damage / shots_per_second | 45 / 0.4 | 70 / 0.5 | S15: the full pool's pads carry the arc and mortar turrets only; the mortar pad was the weakest |
| vertical_slice_balance.json | `pistol` damage / shots_per_second | 30 / 2.0 | 34 / 2.2 | every bot fights act I with the pistol (S8, S18; greedy, spammer and turret_rush never swap) |
| vertical_slice_balance.json | `smg.damage` | 15 | 20 | S12 under 3% (bench 0.95 at wave 12) |
| vertical_slice_balance.json | `auto_turret.turret_damage` | 12 | 15 | the same gun turret as `turret_gun.damage` (kept equal) |

## 3.4 Rounds (balanced win rate, base / full; median win length)

| Round | What changed | Base / full | Note |
|---|---|---|---|
| V5-A | nothing (`a3b177f`) | 53 / 23, 569 s | the starting point |
| r1a | windows x1.45, boss 70/80/90 s, rusher cost 2, lance beam 120 | 73 / 33, 781 s | the full-pool gap stays: weapons |
| r1b, r1c | r1a plus budgets x1.25 / x1.45 in waves 4 to 15 | 63 / 20, 50 / 13 | budgets alone do not close S15 |
| r2a | windows x1.5, boss 80/90/100 s, a budget table, lance 1700 HP armor 6, brood 2100, vent 4%, first weapon pass | 80 / 60, 824 / 858 s | |
| r2b | r2a with harder late budgets | 73 / 53 | 3 unfinished runs (reclaimers) |
| r3a, r3b | second weapon pass, mortar 150, hornet 48, act III x2.0, hulk 10000; r3b turret 15 | 67 / 63, 73 / 63 | S18 0.54 PASS, 2 unfinished |
| r4a | the final act I-II budgets, reclaimer heal 5 / 2 tethers, arc turret 14 m, mortar turret 70 | 80 / 73 | clean; S18 0.42 |
| r4b | r4a plus the hot-route package | 77 / 83 | hot 304 Data against 269: hot pays, both above 65% |
| r5a | r4b plus standoff 10.5 m and the new prices | 80 / 70 | |
| r5b | dearer prices (450+200n), lighter act II bosses, hulk 12000 | 67 / 47 | rejected (full under 50%) |
| **r5c = final** | r5a plus act III budgets 185 to 265 and plating x2.2 (and the wave 1 mini cell) | 63 / 58 (60 seeds), 834 / 857 s | kept |

## 3.5 Rows that stay WARN, and why

- **S1 (base; it was PASS)**: balanced ends act I with 98 to 100% of the core in 28 of 30 runs (stdev 0.004). Items 3 and 2
  of the task (no early deaths, greedy under 60% in act I, no wave 6 spike) made act I safe, and balanced, which swaps to its
  crate weapon at the act I boss, now loses almost nothing there. Act I could hurt balanced only through values it shares with
  greedy, which is weaker and loses 42% already (limit 60%): any act I threat that spreads balanced's core lands harder on greedy
  first. With these bots S1 and S8 / S18 pull against each other. Full: stdev 0.055 (min 0.73).
- **S9 (base; it was PASS)**: all 11 balanced losses fall in act III (boss waves 36%); full: 0 / 10 / 90%, boss waves 20%.
  The same cause as S1: acts I and II are safe for balanced, so its losses moved to act III's density. Getting 15% of the losses
  into act I needs the act I threat S8 and S18 forbid for the weaker bots.
- **S18 (full only; base PASS 42%)**: 76% in wave 5. On the full pool greedy loses a median 25% of its core in wave 5, but 2 of
  its 30 runs lost 69% and 76% (seeds 21 and 20) and the row takes the worst run. Before: 99% in wave 2. On the full pool the
  pads carry the arc and mortar turrets (the gun turret's 15 does not help there) and greedy's crates (hornet rack, mortar,
  scattergun) sit in slots it never fires. Not tuned further: found on the last card, and the evidence runs were stopped
  (3.9). The next lever to try is the act I boss wave itself (wave 5 budget 50, brood and lance HP), which balanced does not
  feel (it ends act I untouched) and base S4 has room for (63%, limit 70%). A worst-run row will find more such seeds at 200 runs.
- **S2**: 44.5 s against 45 s (full 24.0 s). The run length is window-limited, so wins differ only by wave tails and boss times;
  more spread needs windows that vary by route or pack (a structure change), or longer boss fights.
- **S3 (base; full PASS 0.259)**: median Jaccard 0.55. A balanced run holds 16 of the 31 base-pool directives on average
  (measured 16.2); two random 16-of-31 sets already overlap about 0.35 (8.3 shared of 23.7). The full pool (59 directives)
  passes. Needs a larger base pool or fewer picks (spec).
- **S7, S10**: greedy 0% / 0%, spammer 3% / 3%, turret_rush 13% / 10% (base / full). These three never change weapon and fire
  the pistol in slot 0 unless a second crate overwrites it; greedy now dies at the act II boss and in act III (base median death
  wave 10, was 6). A pistol strong enough to carry act III for them would push balanced above 70%. Hoarder (33% / 27%) and risk
  (43% / 50%) are inside their bands.
- **S12, S11 (base)**: the base pool has four weapons (pistol, SMG, scattergun, assault rifle). "None above 30%" with four
  weapons means every weapon, the pistol included, needs about 10% of the wins as the main weapon, and the tier-greedy salvage
  replaces the pistol at the first crate and takes the rifle whenever one drops. The rifle went from 97% to 91% and the SMG
  to 9%; more needs a bot or pool change. On full, S11 passes (12 signatures at 4% or more, top 19%) and S12 moved from LMG
  56% to LMG 38%, torch 29%, rail 15%, rifle 8%, SMG 6% (the torch and the rail are real picks now); the pistol, scattergun,
  hornet rack, mortar and arc stay under 3% (S12 counts the weapon that dealt the most damage in a win, and balanced switches
  to its area weapon only for the boss or a crowd of 12).
- **S13**: the swing compares the win rate of runs that held a directive with runs that were offered it and passed, pooled over
  all policies. `random` (0% wins) and `balanced` (63%) pick differently, so the swing measures who picked, not the directive
  (base +66 executioner, full +86 incendiary_tips). `directives.json` was not changed: tuning a directive against a confounded
  number would move the wrong thing. Needs the row measured inside one policy (scorecard owner).
- **S14**: standard 77% / 268 Data, hot 50% / 252 Data on base; 60% / 242 and 50% / 239 on full (full is inside both bands, but
  hot does not bank more). Data is mostly banked by surviving (6 a wave, 30 and 45 for the act bosses, 100 plus up to 50 for a
  win), so the route that dies more banks less. In round r4b hot banked more (304 against 269) with both routes above 65%; the
  act III plating needed for S4 took the hot route down again. At 30 seeds a rate moves about 9 points; the 200-run card was not
  run.
- **S17**: the wave table's peaks are about three times what the budgets put on the field (bodied medians 2.5 to 23 against 10
  to 50), and only 4 of the 12 packs carry minis. Item 9 asked which side is right: the table is the spec's density target and
  the budgets are tuned for S4 / S8 / S18, so only the one cell that contradicted the spec's own pack (wave 1 minis) was changed.
  Either the table follows the budgets or the budgets and costs rise: a design decision (needs owner).

## 3.6 Tests re-recorded (numbers a tuned value moved; nothing loosened)

Commits `2617790`, `d16df0c`, `9cf7595`, `787cb42`, `cb394c4`; each commit message lists its numbers.

- `tests/unit/content/test_variety_loader.gd`: budgets [80, 100, 265, 175]; windows 100 s and 33 s; buyout 350; patch base+step
  330; pistol 34; arc heat 12; rail charge 36 ticks; pellets 10; hulk 10000; brood 2100.
- `tests/fixtures/data_bad_variety/standoff_inside_slots.json`: one more expected error (the reclaimer needs the 10.5 m ring too).
- `tests/unit/sim_plan/test_packs_and_modifiers.gd`, `test_plan_build.gd`: pack_repair shares, squall 0.8, static_air 0.65,
  low_power 480, hot weights, hunt budget 98, golden plans and groups (seeds 1 to 3).
- `tests/unit/sim_draft/test_directive_stats.gd`, `test_draft_prices.gd`, `test_kits.gd`: pistol 34 / 2.2, prices 350/500/650 and
  220/330/440 with the Scrap left after each.
- `tests/unit/sim_ai/test_policy_value_spend.gd`, `test_policy_swap_reach.gd`, `test_policy_balanced_loadout.gd`,
  `test_policy_boss.gd`: price thresholds, the scattergun's 13 m crowd radius (the "too far" crowd moves 14 -> 16 m), boss DPS.
- `tests/unit/sim/test_v5a_data_and_debug_start.gd`: rw_data 25.
- `tests/unit/sim_arsenal/` (13 files): the shot timelines and damage of the tuned weapons. One structural edit: the pistol and
  SMG comparison with the legacy world copies the tuned damage, rate, magazine and reload into the legacy world's weapon first,
  so it still compares the two code paths on equal numbers.
- `tests/unit/sim_enemies/` (3 files), `sim_boss/test_boss_lance_platform.gd`, `sim_events/` (4 files): reclaimer ring 10.5 m,
  2 tethers, heal 5; hulk 10000; lance beam 120; Core Vent 4%; turret 15; mortar turret 70; arc turret 14 m.
- `tests/unit/ui/variety_e_hud_test.gd` (vent price 4%), `tests/unit/view/vfx_zones.gd` (2 tethers; six reclaimers for the cap).

These were recorded from each test's failure output on the final data, but the groups were **not re-run** after the edit (3.9).

## 3.7 Needs owner

1. `src/audio/audio_variety_routes.gd` line 54 mirrors the wave budgets (code, not V5-C's). Proposal:
   `const WAVE_BUDGETS: PackedInt32Array = [24, 34, 42, 66, 50, 80, 98, 118, 138, 100, 185, 210, 235, 265, 175]`, then in
   `tests/unit/audio/test_variety_audio_ui.gd` the drone fractions `10.0 / 36.0` -> `10.0 / 42.0` and `22.0 / 36.0` -> `18.0 / 42.0`
   (comment "24, 34, 46, 60" -> "24, 34, 42, 66"). Until then `unit/audio` fails 2 test cases
   (`test_the_mirrored_wave_budgets_are_the_budgets_of_the_data`, `test_the_mirrors_follow_the_shipped_data_too_not_only_the_frozen_fixture`)
   and `check.ps1` cannot end with CHECK OK.
2. `data/strings/variety_en.json` (and its fixture copy) quotes old values: `boss.lance_platform.attack` "for 160" -> "for 120";
   `modifier.squall.desc` "-30%" -> "-20%"; `modifier.static_air.desc` "at half speed" -> "at 65% speed"; `modifier.low_power.desc`
   "first 12 s" -> "first 8 s"; `weapon.scattergun.desc` "Fires only at 9 m" -> "13 m"; `weapon.rail_lance.desc` "A one-second
   charge line" -> a 0.6 s charge.
3. `docs/design/VARIETY_CONTENT.md`: the tables of section 1.1 (windows now add up to 861 s, budgets), the weapons, bosses,
   reclaimer, rewards, modifiers and prices above.
4. Bots: a weapon-swap rule for greedy, spammer, turret_rush and random (they never swap), and a less tier-greedy salvage, are what
   S7, S10 and S11 / S12 need; values cannot reach them without breaking S4.
5. One more value round (V5-C or its successor) for S18 on the full pool (3.5), checked on both pools at 200 runs.
6. Scorecard and spec: S13 measured inside one policy; S17's table against the budgets; S1 and S9 against S8 / S18 with these bots;
   S3 on a 31-directive base pool.

## 3.8 What a human playtest should look at (bot balance is not human balance)

- Act I: the balanced bot finishes it untouched. Are waves 1 to 4 (33 to 45 s) slow or too easy for a person?
- Act III: every bot loss is there (plating x2.2, budgets 185 to 265). A climax or a wall?
- Length: about 14 minutes of combat plus drafts and salvage. Fatigue on a phone?
- Weapons: the pistol at 34 x 2.2/s; the scattergun at 13 m; the rail lance at 1.2 lines a second with a 0.6 s charge (does it
  still read as a lance?); the torch at 20 m; the hornet rack and mortar as real picks.
- Hot routes: worth taking for 25 Data and double picks? Do RAIN SQUALL / STATIC AIR / LOW POWER still feel like a risk?
- Reclaimers on the 10.5 m ring with 2 tethers: readable? The lance's 120 beam: still a threat?
- Scrap: buy-outs 350 / 500 / 650 and patches 220 / 330 / 440. A choice, or out of reach? The Core Vent at 4%: ever worth it?

## 3.9 NOT RUN on the final values

The machine ran short of memory during the final evidence; the harness stopped the test-group run (during `integration/sim`)
and the evidence script, and asked not to restart them unasked. The evidence script's own process outlived that stop and went
on to the full-pool card and `sim_run` (both in 3.1; all runs used a `git archive` copy of `b093f3f`, the final data); V5-C
ended it before `balance_run` and the 200-run cards could start. Not run: `scorecard_run -Runs 200` (base, full);
`balance_run -Runs 20` (on the shipped data it also judges S4, S6, S7, S16 and S17,
so S7 and S17 may show as WARN there); `check.ps1`; every test group after the re-recorded numbers; `integration/sim`,
`integration/game`, `integration/e2e` and `stress` on the final values at all. Run on the final data before the re-pins:
`unit/sim_flow`, `sim_nav`, `sim_combat`, `game`, `save`, `core`, `shared` passed (0 failures); the failures of the other unit
groups are the numbers listed in 3.6, plus the audio mirror of 3.7.
