# Test report - W3-A (gameplay integration and fixes)

Branch `task/W3-A`, from `main` at `1c68512`. Windows 11, Godot 4.7.2 stable (`Mobile` renderer, Vulkan), GdUnit4 6.2.3,
tests headless through `tools/test.ps1` / `tools/check.ps1` (`APPDATA` redirected to `build\test_appdata`). Desktop runs on an
Intel Iris Plus integrated GPU. **No Android emulator and no physical device was used**; every device row is NOT RUN.

## 1. Commands, exit codes, last lines

| Command (PowerShell, worktree root) | Exit | Last line |
|---|---|---|
| `tools\check.ps1` | 0 | `CHECK OK` (`tests run: 1063`, `TEST SUMMARY: tests=1063 failures=0 errors=0 skipped=0 exit=0`), 4 min 15 s |
| `tools\test.ps1 -Path res://tests/integration` | 0 | `TEST SUMMARY: tests=125 failures=0 errors=0 skipped=0 exit=0`, 2 min 13 s |
| `tools\balance_run.ps1 -Runs 20` | 0 | `BALANCE: PASS rows=10 pass=10 warn=0 fail=0 runs=40` (numbers identical to `BALANCE_REPORT.md`; no data changed) |
| `tools\sim_run.ps1 -Seed 1 -Policy greedy -Runs 5` | 0 | `SIM SUMMARY: runs=5 victories=5 defeats=0` |
| real process, fresh profile: `Godot --headless --fixed-fps 60 --path . -- --autoplay=greedy --seed=1 --mute --quit-after-run` | 0 | `[Game] quit after run` (see 4) |
| same command again on the same profile (relaunch) | 0 | `[Save] profile OK data=135 runs=1` at boot, `data=270 runs=2` after the second run |
| windowed `--debug-perf --scenario=hold50` for 36 s | killed by the script | six `[PERF]` lines (see 5) |

Gate time: the full gate took about 260 s on `main` (coordinator figure) and takes 255 s now with 71 more tests (1063 against 992).
The new end-to-end suites cost about 47 s of that (the 100-retry test 7 s, the main-scene greedy run 5 s, the rest under 2 s each).

## 2. Counts

| Folder | Tests |
|---|---:|
| `tests/integration/e2e` (**new**) | 47 |
| `tests/integration/game` | 49 |
| `tests/integration/sim` | 29 |
| `tests/stress` | 8 |
| `tests/unit/{shared,core}` | 12 + 10 |
| `tests/unit/content` | 75 |
| `tests/unit/sim` | 89 (4 new: `test_policy_bot_ids`) |
| `tests/unit/sim_nav` / `sim_combat` | 78 / 81 |
| `tests/unit/sim_flow` | 99 (5 new: `test_run_end_abilities`) |
| `tests/unit/save` | 64 (7 new: `test_save_dirty`) |
| `tests/unit/game` | 105 (8 new: `test_game_rewards_writes`, `test_run_controller_tick_sink`) |
| `tests/unit/{view,ui,audio}` | 146 / 110 / 61 (not touched) |
| **Total** | **1063** (992 before) |

New end-to-end suites (`tests/integration/e2e/`; helper classes `IntegrationKit`, `IntegrationMain`, `IntegrationShotLog`,
`IntegrationCountingFs`):

| Suite | Tests | What it drives |
|---|---:|---|
| `test_e2e_main_scene` | 5 | the real `scenes/main.tscn` and the `Game` autoload: fresh profile, `--autoplay=greedy --seed=1` on the tuned data, VICTORY, five waves and the Hulk, profile written, relaunch |
| `test_e2e_disk_profile` | 3 | the real `user://` files (redirected): write, `.bak` of the previous profile, relaunch, torn main file recovered |
| `test_e2e_defeat` | 3 | DEFEAT on the tuned data, 10 Data per cleared wave, written once, relaunch |
| `test_e2e_pause` | 6 | pause in PREPARING, SPAWNING, CLEARING, INTERMISSION; back gesture; commands during a pause |
| `test_e2e_abilities` | 6 | EMP, shield, overdrive: on cooldown, active, wrong phase, paused, duplicate id |
| `test_e2e_weapons` | 4 | SMG and turret purchases seen in the `shot_fired` stream (sources, cadence), third turret, double tap |
| `test_e2e_retry` | 1 | retry 100 times |
| `test_e2e_lifecycle` | 5 | app-pause / focus-out notifications pause and flush |
| `test_e2e_debug_wiring` | 8 | `--debug-perf`, `--debug-overlay`, the view built during the boot screen |
| `test_e2e_autoplay_ids` | 2 | bot and HUD share one command id counter |
| `test_e2e_warden_and_spawns` | 4 | no input moves or aims the Warden; locks only in range; spawn regions; walking to the core |

## 3. Matrix rows (A03, A05 to A15)

"PASS (headless)" means automated, deterministic, on this machine. Nothing here is a device result.

| Row | Status | Evidence |
|---|---|---|
| A03 Warden fixed, auto targets and shoots, no manual aim or move | PASS (headless) | `test_e2e_warden_and_spawns`: 5 rounds of touches, drags, mouse and key events over the whole window leave `warden.x/z` unchanged and the aim on the locked target; every lock is a living enemy within range; the Warden is silent until hostiles exist and then fires with no input. The HUD has no aiming control. Gameplay capture: not taken (W3-B owns captures) |
| A05 Hostiles spawn right / top-right and navigate to the core | PASS (headless) | `test_e2e_warden_and_spawns` (every new enemy inside the `right` or `upper_right` region, then closer to the core); `tests/unit/sim_nav` (spawn, flow field); visual part left to W3-B |
| A06 50 living enemies; pending queue keeps all | PASS (headless) | `test_e2e_main_scene` (peak 45 to 50 in wave 5, never above 50, nothing pending at the end, kills == scheduled); `tests/unit/sim_nav/test_spawn_system`, `tests/stress` (10 minutes at the cap). Device benchmark NOT RUN. Desktop numbers in 5 |
| A07 Five waves and the Hulk complete correctly | PASS (headless) | `test_e2e_main_scene` (VICTORY, 5 waves, 5 `wave_started`, 5 `wave_cleared`, 4 intermissions, one `boss_spawned`, Hulk killed once); `tests/integration/sim`; `balance_run` PASS |
| A08 Four archetypes behave differently | PASS (headless) | `tests/unit/sim_nav/test_archetypes` (unchanged this task); capture left to W3-B |
| A09 Scrap exactly once per kill | PASS (headless) | `test_e2e_main_scene` (`scrap_earned` == sum of kills times reward over a whole run); `tests/unit/sim_combat/test_damage_resolver`, `test_sim_world_core` |
| A10 Pistol to SMG, damage / rate / piercing purchases | PASS (headless) | `test_e2e_weapons` (after the SMG the Warden fires 60 to 76 shots in 900 ticks against 22 to 27 with the pistol, 9 to 10 ticks apart against 29 to 30; `weapon_changed` smg); `test_e2e_autoplay_ids`; `tests/unit/sim_flow/test_purchases` |
| A11 Up to 2 turrets, no third | PASS (headless) | `test_e2e_weapons` (`TURRET_0` then `TURRET_1` appear in `shot_fired`, 19 to 20 ticks apart; the third buy is refused with `MAX_LEVEL`, costs nothing) |
| A12 EMP, shield, overdrive | PASS (headless) | `test_e2e_abilities` (ON_COOLDOWN, ALREADY_ACTIVE, WRONG_STATE in PREPARING and INTERMISSION, PAUSED, DUPLICATE_COMMAND; a refusal never restarts or starts a cooldown); `tests/unit/sim_flow/test_ability_timers`; new `test_run_end_abilities` (D1) |
| A13 Pause freezes simulation and cooldowns | PASS (headless) | `test_e2e_pause` (state hash, tick, countdowns, cooldowns, scrap, event count identical after 600 frames of pause in all four phases; the run continues after RESUME); `test_e2e_lifecycle` (app pause). Background / resume on a device NOT RUN |
| A14 Core 0 defeats, wave 5 clearance wins | PASS (headless) | `test_e2e_defeat` (tuned data, no bot: DEFEAT in wave 3 or 4), `test_e2e_main_scene` (VICTORY with 30 to 80 % core, 704/1000 for seed 1); `tests/unit/sim_flow/test_phase_end` |
| A15 Save persists rewards once, corrupt backup recoverable | PASS (headless and real process) | `test_e2e_disk_profile`, `test_e2e_main_scene`, `test_e2e_defeat`; `tests/unit/save`; real relaunch in 4. Android restart NOT RUN |

Rows not covered here: A02, A16 to A18 are not W3-A; A01, A04, A19, A20 were not part of this task's report.

## 4. Real process, headless: fresh profile and relaunch

`build\relaunch_appdata` (redirected `APPDATA`, the real profile is untouched), exit code 0 both times.

```
[Content] content ok enemies=4 waves=5 hash=57fc88c957db
[Save] profile NEW_PROFILE data=0 runs=0
[Game] boot ok
[Game] run started id=1794415057-1 seed=1 autoplay=greedy scenario=
[Game] run finished result=VICTORY waves=5 core=704 data=+135 granted=true
[Game] results shown
[Game] quit after run
-- second launch, same profile --
[Save] profile OK data=135 runs=1
[Game] run finished result=VICTORY waves=5 core=704 data=+135 granted=true
```

`profile_v1.json` after launch 1: `data 135`, `runs_played 1`, `missions_completed 1`, `best_core_hp 704`, one awarded run id, three hints.
After launch 2: `data 270`, `runs_played 2`, two run ids; `profile_v1.json.bak` holds the previous profile.

## 5. Desktop performance (windowed, NOT a device)

`--debug-perf --scenario=hold50 --seed=1 --mute`, 36 s, window 540x960 (viewport 1080x1920), Intel Iris Plus Graphics, Vulkan
Forward Mobile. **Desktop numbers on an integrated GPU; they say nothing about a phone.**

```
[PERF] fps=27.6 min=15.5 frame_ms=36.27 p95_ms=35.95 tick_ms=0.28 enemies=50 draws=98  prims=29312 vid_mb=74.5
[PERF] fps=30.6 min=30.1 frame_ms=32.68 p95_ms=34.95 tick_ms=0.83 enemies=50 draws=132 prims=38869 vid_mb=74.5
[PERF] fps=30.8 min=30.3 frame_ms=32.47 p95_ms=35.11 tick_ms=0.66 enemies=50 draws=132 prims=38794 vid_mb=74.5
[PERF] fps=26.4 min=18.3 frame_ms=37.95 p95_ms=35.37 tick_ms=0.55 enemies=50 draws=131 prims=38646 vid_mb=74.5
[PERF] fps=31.0 min=30.2 frame_ms=32.22 p95_ms=34.78 tick_ms=0.51 enemies=50 draws=130 prims=38531 vid_mb=74.5
[PERF] fps=28.5 min=20.3 frame_ms=35.08 p95_ms=34.76 tick_ms=0.51 enemies=50 draws=130 prims=38553 vid_mb=74.5
```

At the cap of 50: about 130 draw calls, about 38,600 primitives, 74.5 MB video memory, sim 0.5 to 0.8 ms per tick (including the scenario's
top-up spawns), about 30 fps on this GPU (frame time 32 to 38 ms). A 14 s window with `--debug-overlay=all --debug-perf --scenario=hold20`
printed no error and one `[PERF]` line (`draws=94 prims=56895`, the overlay's four layers included).

## 6. Defects found and fixed (all functional)

| # | Defect | Fix | Test |
|---|---|---|---|
| D1 | `abilities.active_left` stayed above 0 after the run ended (a shield emptied by the killing blow, an overdrive that outlived the last enemy): `step()` is a no-op after the run | `AbilitySystem.end_all`, called by `PhaseSystem._finish_run` before `RUN_FINISHED`; pushes `ABILITY_ENDED` and `SHIELD_CHANGED` 0 | `test_run_end_abilities` (5) |
| D2 | The greedy bot counted command ids from 1 and so did the HUD: a tap during `--autoplay` repeated an id and the sim dropped it as `DUPLICATE_COMMAND` (a repeated CONTINUE has no answer at all). Found by reading the code; `test_two_private_counters_do_repeat_ids_which_is_why_game_shares_one` shows the duplicate answer. The old code was not re-run | `PolicyBot.id_source`; `GameLaunch` points it at `RunApi.next_command_id` | `test_policy_bot_ids` (4), `test_e2e_autoplay_ids` (2) |
| D3 | `GameRewards.grant` flushed the profile a second time after `Save.grant_run_reward` had already flushed it: the `.bak` became a copy of the new profile and the previous one was lost (found by reading the code; the new tests assert the fixed behaviour, the old code was not re-run) | `Save.profile_dirty()`; `GameRewards` reads it instead of flushing again | `test_game_rewards_writes` (4), `test_save_dirty` (7), `test_e2e_disk_profile` |
| D4 | `--debug-perf` printed no `[PERF]` lines (PerfHud was never set up or fed) and `--debug-overlay` did nothing in the game | `GameDebugTools`, `RunController.tick_sink`, `GameViewBuilder`, wired from `Game` | `test_e2e_debug_wiring` (5), `test_run_controller_tick_sink` (4); real run in 5 |
| D5 | ShaderWarmup ran at the first deploy, not during the boot screen (ARCH 8) | `Game` builds the first BattleView after the boot screen is up and the first deploy adopts it (`battle_view` stays null outside a run); no `src/view/**` change | `test_e2e_debug_wiring` (3); real log `battle view warmed up during boot` before `boot ok` |
| D6 | `MobileShell` could not be tested through its notifications on a desktop build | `lifecycle_enabled` (default unchanged) | `test_e2e_lifecycle` (5) |

Contract changes (all additive, contract test and ARCHITECTURE.md updated in the same change): `Save.profile_dirty()` (the one the task
asked for, `test_contracts.gd` row for `save_manager.gd`; ARCH 7.5), `AbilitySystem.end_all` (ARCH 6.6), `PolicyBot.id_source` (ARCH 6.7),
`RunController.tick_sink` and the W3-A paragraph on `Game` / `MobileShell` (ARCH 7.3, 7.4). No existing signature changed. `data/*.json`
was not touched; `balance_run` gives the same numbers as `BALANCE_REPORT.md`.

## 7. Retry x100 (one process)

`[e2e] retry x100  nodes 537 -> 537  connections 58 -> 58  orphans 0 -> 0  objects 3647 -> 3645  memory 89894514 -> 91210694 bytes`
(+1.5 %, limit 5 %). Over 400 retries the object and node counts stay flat and static memory moves by about 2 % in allocator steps. The
harness's own signal recorder grows with every event, so the test detaches it before measuring; it would otherwise read as a leak.

## 8. Known issues and not run

- NOT RUN: every device row (A02, A13 background / resume on Android, A15 Android restart, A18), the Android emulator, the
  time the first BattleView takes to build on a phone (it now happens during the boot screen; the progress bar may stall for
  that long), the physical lifecycle notifications (`NOTIFICATION_APPLICATION_PAUSED` is sent by hand in the tests).
- First-run hints each write the whole profile while the player is fighting (three writes on a fresh profile). Small file, rename
  dance; not a defect, but a candidate for batching if a device shows a hitch.
- `PerfHud.setup` re-anchors itself to the top (wide, 120 px), so the full-rect call made before it only matters until `setup` runs.
- The 100-retry test and the greedy main-scene run are the longest new tests (7 s and 5 s).
