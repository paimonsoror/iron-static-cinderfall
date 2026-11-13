# IRON STATIC: CINDERFALL - Work Plan for parallel implementation agents

Version 1.1, 2026-11-11. Read with `ARCHITECTURE.md` (contracts, cited as ARCH n) and `GAME_DESIGN.md`
(rules, cited as GDD n). Handoff files are cited as `handoff/<path>` and live in `docs/handoff/` in the project.

Project root: **`C:\dev\tower-two`** (Git Bash: `/c/dev/tower-two`). Every owned path below is relative to it.
The original game at `C:\dev\tower` is **read-only**. Never read `secrets.local.json`, `C:\dev\keys` or any keystore.

**Two milestones.** *Milestone 1* is the five-wave vertical slice (waves 0 to 4, sections 2 to 7); it is the history of the
repository and its tasks stay below unchanged. **Milestone 2: Variety** is the owner-approved replacement of the five scripted
waves by a generated 15-wave, three-act run with 1-of-3 directive drafts, ten weapons, new enemies, bosses, chaos events, an
Archive of unlocks and resume (decisions D1 to D8 approved 2026-11-11, GDD 14). Its design is
`docs/design/VARIETY_PITCH.md` (owner summary), `VARIETY_SPEC.md` (rules, contracts and plan; cited as SPEC n) and
`VARIETY_CONTENT.md` (every id and first-pass number; cited as CONTENT n). Its waves (V1 to V6), task cards, rule changes and
acceptance rows are in section 2.1, section 8, section 6 and section 7 (rows B01 to B12). ARCH and GDD already describe the
milestone (marked **(V)** in ARCH).

**Status (2026-11-11), milestone 1.** Wave 0, Wave 1, Wave 2 and W3-A are merged on `main`. **W3-C** (the Warden look-dev
spike, added after this plan was written) is merged and frozen at v4; the shipped character look is STYLISED (ARCH 8).
**W3-D** (the look rolled out to the turret, the enemies and the Hulk) has since been merged into `main` (merge `44997d0`);
**W3-E** (the environment look) is in progress on its own branch, not merged. W3-B (presentation integration) and W4-A
(release QA) have not been run: their remaining scope is taken over by V5-B and V6-Q. The first real-device numbers are in
`docs/reports/PHONE_PERF.md` (ARCH 13.1). The Warden triangle budget is **2,500 now** (W3-C, `ActorMeshes.TRI_BUDGET`); SPEC Q4
proposes a split of body 2,300 plus a weapon budget of 350, to be decided by the owner of `TRI_BUDGET` after the captures
(section 6).

---

## 1. Rules for every task

1. **Own only your paths.** Create, edit and delete files only under the "Owned paths" of your task. Everything
   else is read-only. If you need a change elsewhere, stop and report it; do not make it.
2. **Contracts are frozen.** Signatures, signal names, field names, file paths and JSON schemas in
   ARCHITECTURE.md do not change. `tests/unit/core/test_contracts.gd` enforces the signatures; never edit it.
3. **Never edit**: `project.godot`, `export_presets.cfg` (except its owner), `src/shared/**`,
   `src/content/defs/**`, `src/sim/sim_world.gd`, `src/sim/stores/**`, `src/core/event_bus.gd`,
   `src/core/main.gd`, `src/game/run_api.gd`, `src/view/battle_view.gd`, `tools/**` (except the owner),
   unless your task lists the file. **Milestone 2 adds the shared files of section 8.2** (`src/shared/{ids,reason,damage_source}.gd`;
   `src/content/defs/**`, `content_loader.gd`, `content_validator.gd`; `src/sim/{sim_world,sim_command,sim_event_kind,sim_config,run_stats,run_summary}.gd`;
   `src/core/event_bus.gd`, `src/game/{run_api,game_event_relay}.gd`, `src/debug/fake_run_api.gd`;
   `tests/unit/core/test_contracts.gd`, `tests/fixtures/test_content.gd`; `src/audio/audio_catalog.gd`, `tools/audio_gen/voices.py`;
   `src/view/vfx/vfx_layer.gd`, `src/view/actors/{actor_layer,enemy_pool}.gd`; `src/ui/combat/combat_hud.gd`;
   `data/strings/variety_en.json`; `data/{run,enemies,weapons,directives,events}.json`; nobody changes `project.godot` or
   `export_presets.cfg` in this milestone). They are extended once, as complete contracts, by V1-S; the owner-per-wave exceptions are in the table of 8.2. A needed
   change elsewhere is reported as "needs owner" and made by the coordinator between waves.
4. **Verify with the wrappers, never with raw Godot.** Headless Godot can exit 0 after an error. A check
   passes only when the command exits 0 **and** prints the stated last line.
5. **Unit tests use frozen data.** Build content with `TestContent.baseline()` (`tests/fixtures/test_content.gd`,
   reads `tests/fixtures/data_baseline/`). Never assert on values from `res://data/` in a unit test: those
   files get tuned in Wave 2. **Milestone 2:** the baseline fixture (the five-wave handoff data) stays untouched, so the 1,063
   existing tests keep guarding the sim core on it. New unit tests of variety behaviour build content with
   `TestContent.variety()` (same file), which reads a **second frozen fixture**, `tests/fixtures/data_variety/`: created by V1-S
   with the slice data, frozen by V3-I as the first complete variety data set, and refreshed only by an explicit task (V5-C);
   golden values recorded on it are re-recorded when it is refreshed. No unit test reads `res://data/`; the e2e suites do, on
   purpose.
6. Typed GDScript, warnings are errors. No `class_name` clash with an autoload name (`Log`, `Events`,
   `Content`, `Save`, `Sfx`, `Game`). Do not name a variable `set`, `seed`, `name` or `position` where it
   would shadow a member or global.
7. Write files with the Write tool (UTF-8, no BOM, LF). Do not create `.tscn` content beyond a root node with
   a script unless the task says so; build children in code.
8. Do not pass `-d` to Godot. Do not run two Godot processes on the same checkout at once.
9. **Only the task that says so may use the Android emulator.** It is a single shared device. **Milestone 2:** the physical
   phone (Pixel 11 Pro Fold, `docs/reports/PHONE_PERF.md`) may be used only by **V2-P** and **V6-Q**, one at a time; the emulator
   cannot present Vulkan, so every other task reports device checks as **NOT RUN**.
10. Report with `handoff/05_AGENT_PROMPTS/REVIEW_TEMPLATE.md`: files changed, decisions, each command run
    with its exit code and last line, screenshots, known defects. Never report a check you did not run.
    Physical-device checks that were not run are reported as **NOT RUN**.

### 1.1 Commands (PowerShell 5.1; callable from Git Bash as shown)

```
# Full gate: import + compile (warnings as errors) + layer lint + all tests. Pass = exit 0 and last line "CHECK OK".
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\check.ps1

# Scoped tests. Pass = exit 0 and last line "TEST SUMMARY: tests=N failures=0 errors=0 skipped=S exit=0", N > 0.
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\test.ps1 -Path res://tests/unit/sim_nav

# Desktop screenshot through the real renderer (opens a window briefly; not headless). Pass = exit 0, "CAPTURE OK <path>".
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out C:\dev\tower-two\build\shots\view.png -Size 1080x2400

# Raw import, only as a diagnostic (do not judge by its exit code):
"C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path C:\dev\tower-two --import

# (Milestone 2) Headless runs with any of the 8 bot policies. Pass = exit 0, a "SIM SUMMARY: runs=N victories=V defeats=D" line.
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20

# (Milestone 2) The predictability scorecard (ARCH 12, GDD 8.4). -Pool base|full. The gate version is -Runs 30, the full card
# -Runs 200. Pass = exit 0 (exit 1 on FAIL) and last line "SCORECARD: PASS|WARN|FAIL rows=.. pass=.. warn=.. fail=.. runs=..".
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\scorecard_run.ps1 -Runs 30 -Pool base

# (Milestone 2) Print the whole plan of a seed (bosses, both options of every wave, events) for bug reports and design review.
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\plan_dump.ps1 -Seed 1
```

If a task runs in a git worktree, replace `C:\dev\tower-two` with the worktree root. The tools resolve the
project from their own location.

### 1.2 Notes for the coordinator

- **Isolation.** Run each task of a wave in its own git worktree (branch `task/<ID>`), then merge the
  branches. Path ownership is disjoint, so merges are clean. Agents sharing one working tree would break each
  other's compile gate with half-written files and would fight over `.godot/`. Wave 0 therefore ends with
  `git init` and one commit.
- **Emulator.** One user per wave: W1-H in Wave 1, nobody in Wave 2, W3-B is desktop-only, W4-A in Wave 4.
- **Merge check.** After merging a wave, run `check.ps1` on `main` before starting the next wave.
- **Cross-boundary defects** found by a task are listed in its report under "needs owner"; route them to the
  next wave's owner of that path.

---

## 2. Wave overview

| ID | Title | Owned paths (summary) | Depends on | Goal |
|---|---|---|---|---|
| **W0-S** | Scaffold | whole repo | - | Project, contracts as compiling stubs, data, tools, test harness, sandboxes |
| W1-A | Sim: arena, navigation, spawning | `src/sim/nav/`, `src/sim/systems/{spawn,movement}_system.gd`, `data/arena.json`, `data/content_ext.json`, `tests/unit/sim_nav/` | W0-S | Enemies spawn, flow to the core, take slots; cap and queue |
| W1-B | Sim: targeting, weapons, damage, core attacks | `src/sim/systems/{targeting,weapon_system,turret_system,damage_resolver,core_attack_system,combat_state}.gd`, `tests/unit/sim_combat/` | W0-S | Warden and turrets kill; enemies hurt the core |
| W1-C | Sim: commands, economy, abilities, phases | `src/sim/systems/{command_system,economy_system,ability_system,phase_system,phase_state}.gd`, `tests/unit/sim_flow/` | W0-S | Purchases, abilities, wave and win/lose flow |
| W1-D | Content validation and save system | `src/content/content_{loader,validator,db}.gd`, `src/save/`, `src/core/strings.gd`, `data/strings/content_en.json`, `tests/unit/{content,save}/`, `tests/fixtures/data_bad/` | W0-S | Strict data checks; profile save with backup and reward-once |
| W1-E | View: camera, arena, kit | `src/view/camera/`, `src/view/arena/`, `src/view/kit/`, `tests/unit/view/camera_*`, `tests/unit/view/kit_*` | W0-S | The yard, the core, lighting, fitted camera |
| W1-F | View: actors and VFX | `src/view/actors/`, `src/view/vfx/`, `tests/unit/view/actors_*`, `tests/unit/view/vfx_*` | W0-S | Pooled enemies, Warden, turrets, tracers, bursts |
| W1-G | UI: combat HUD | `src/ui/combat/`, `assets/icons/`, `data/strings/combat_en.json`, `tests/unit/ui/combat_*` | W0-S | Top HUD, upgrade drawer, ability bar, pause overlay |
| W1-H | Android pipeline | `export_presets.cfg`, `tools/{run_emulator,deploy_android,smoke_android}.ps1`, `docs/reports/BUILD_INSTRUCTIONS.md` | W0-S | Scaffold APK builds, installs and boots on the emulator |
| W2-A | Game flow and run controller | `src/game/`, `src/core/game.gd`, `tests/unit/game/`, `tests/integration/game/` | Wave 1 | Menu to results, playable end to end |
| W2-B | Meta screens and theme | `src/ui/screens/`, `src/ui/kit/`, `data/strings/{screens,lore}_en.json`, `tests/unit/ui/screens_*`, `tests/unit/ui/kit_*` | Wave 1 | Boot, menu, briefing, results, settings; final theme |
| W2-C | Audio | `src/audio/`, `assets/audio/`, `tools/audio_gen/`, `tests/unit/audio/` | Wave 1 | Synthesized SFX and loops, event-driven playback |
| W2-D | Sim harness, determinism, balance tuning | `src/sim/**` (except `sim_world.gd`, `stores/`), `data/*.json` (not `strings/`), `tools/{sim_run,balance_run}.*`, `tests/integration/sim/`, `tests/stress/`, `tests/unit/sim*/`, `docs/reports/BALANCE_REPORT.md` | Wave 1 | Replay, bot, stress, tuned waves |
| W2-E | View integration, quality tiers, perf HUD | `src/view/**` (except `battle_view.gd`), `src/debug/**`, `tests/unit/view/` | Wave 1 | Readable at 50 enemies, tiers, `[PERF]` |
| W3-A | Gameplay integration and fixes | `src/{sim,game,core,content,save,shared}/**`, `data/*.json`, `tests/**` except `tests/unit/{view,ui,audio}/` | Wave 2 | Full-run tests green; functional defects fixed |
| W3-B | Presentation integration and fixes | `src/{view,ui,audio,debug}/**`, `assets/**`, `data/strings/**`, `tests/unit/{view,ui,audio}/`, `docs/reports/screenshots/` | Wave 2 | Screenshot set, safe areas, accessibility audit |
| **W4-A** | Release QA and Android evidence | whole repo | Wave 3 | Full suite, APK, emulator run, evidence reports |

Five waves: 0 (1 task), 1 (8 tasks), 2 (5 tasks), 3 (2 tasks), 4 (1 task). This table is milestone 1 and is history; its status
is in the header. (W3-C, W3-D and W3-E, the look-dev tasks added during Wave 3, are not in the table.)

### 2.1 Milestone 2: Variety (waves V1 to V6)

Style and rules are those of section 1 (own only your paths, contracts frozen after the scaffold, verify with the wrappers,
one worktree per task at `C:\dev\tower-two-wt\<ID>\`, branch `task/<ID>`, merge, then `check.ps1` on `main`). Effort is in
agent-hours and is an estimate, not a measurement. The cards are in section 8.

| ID | Title | Owned paths (summary) | Depends on | Hours |
|---|---|---|---|---:|
| **V1-S** | Contract scaffold | the shared and frozen files of 8.2, every new file as a compiling stub, the slice data, fixtures | - | 12 |
| V2-A | Sim: run plan, wave builder, phases and awaits | `src/sim/plan/`, `src/sim/systems/{run_plan_system,wave_builder,phase_system,phase_state,spawn_system}.gd`, `tests/unit/sim_plan/` | V1-S | 9 |
| V2-B | Sim: drafts, directives, modifiers | `src/sim/systems/{draft_system,mod_system,command_system,economy_system}.gd`, `src/sim/stores/{draft_state,mod_state}.gd`, `tests/unit/sim_draft/` | V1-S | 8 |
| V2-C | Sim: arsenal, arc projector, blasts, burster, salvage | `src/sim/systems/{arsenal_system,weapon_system,damage_resolver,area_damage,hazard_system,status_system,death_hooks,salvage_system,core_attack_system}.gd`, `src/sim/systems/fire/{fire_hitscan,fire_arc}.gd`, `src/sim/stores/{arsenal_state,hazard_state,enemy_ext_state,salvage_state}.gd`, `tests/unit/sim_arsenal/` | V1-S | 12 |
| V2-D | Game flow, run file, resume | `src/game/**`, `src/core/game.gd`, `src/save/**`, `tests/unit/{game,save}/`, `tests/integration/game/`, `tests/fixtures/saves/` | V1-S | 10 |
| V2-E | UI: draft, route, salvage overlays, weapon bar | `src/ui/run/**`, `src/ui/combat/**`, `assets/icons/`, `data/strings/variety_en.json`, `tests/unit/ui/` | V1-S | 12 |
| V2-F | View: arc projector, burster, minis, blast and arc effects | `src/view/**` except `battle_view.gd`, `tests/unit/view/` | V1-S | 10 |
| V2-G | Audio: slice sounds and voice classes | `src/audio/**`, `tools/audio_gen/**`, `assets/audio/**`, `tests/unit/audio/` | V1-S | 5 |
| V2-H | Bots and tools for drafts | `src/sim/ai/**`, `tools/{sim_run,balance_run,plan_dump}.*`, `tests/unit/sim_ai/` | V1-S | 6 |
| V2-P | Phone baseline and mini stress (uses the device) | `src/debug/**`, `docs/reports/PERFORMANCE_REPORT.md` | V1-S | 5 |
| **V3-I** | Slice integration and owner playtest build | `src/**`, `data/**`, `tests/**` (fixes only), `tests/fixtures/data_variety/` | Wave V2 | 10 |
| V4-W | Sim: the other 7 weapons and weapon levels | `src/sim/systems/fire/{fire_cone,fire_line,fire_shell,fire_missiles,fire_beam}.gd`, `src/sim/systems/{arsenal_system,shot_hooks}.gd`, `data/weapons.json`, `tests/unit/sim_arsenal/` | V3-I | 12 |
| V4-N | Sim: the other 8 enemy types, elites | `src/sim/systems/{status_system,elite_system,movement_system,core_attack_system,targeting}.gd`, `src/sim/nav/**`, `data/{enemies,arena}.json`, `tests/unit/sim_enemies/`, `tests/unit/sim_nav/` | V3-I | 14 |
| V4-L | Sim: bosses | `src/sim/systems/boss_system.gd`, `src/sim/systems/bosses/**`, `src/sim/stores/boss_state.gd`, `tests/unit/sim_boss/` | V3-I | 12 |
| V4-V | Sim: events and hazards | `src/sim/systems/{event_system,hazard_system,ability_system,turret_system}.gd`, `src/sim/systems/events/**`, `src/sim/stores/event_state.gd`, `data/events.json`, `tests/unit/sim_events/` | V3-I | 11 |
| V4-C | Sim: the other 52 directives, packs, modifiers, kits | `src/sim/systems/{mod_system,draft_system,death_hooks,core_hooks,wave_builder,run_plan_system}.gd`, `data/{directives,run}.json`, `tests/unit/sim_draft/`, `tests/unit/sim_plan/` | V3-I | 10 |
| V4-M | Save v2, unlocks, rewards, daily seed | `src/save/**`, `src/game/{game_rewards,game_launch}.gd`, `data/unlocks.json`, `tests/unit/save/`, `tests/fixtures/saves/` | V3-I | 8 |
| V4-U | UI: Archive, kits, results, ticker, boss bar, hints | `src/ui/**`, `assets/icons/`, `data/strings/{variety,screens,combat,lore}_en.json`, `tests/unit/ui/` | V3-I | 14 |
| V4-R | View: weapon, enemy and boss models | `src/view/actors/**`, `tests/unit/view/actors_*` | V3-I | 14 |
| V4-X | View: effects, zones, events, cosmetic chaos, tiers | `src/view/{vfx,arena,kit}/**`, `tests/unit/view/{vfx,arena,kit}_*` | V3-I | 12 |
| V4-A | Audio: the remaining sounds | as V2-G | V3-I | 6 |
| V4-T | Bots, scorecard tool | `src/sim/ai/**`, `tools/{scorecard_run,sim_run,balance_run}.*`, `tests/unit/sim_ai/` | V3-I | 8 |
| V5-A | Gameplay integration and cleanup | `src/{sim,game,core,content,save,shared}/**`, `data/*.json`, `tests/**` except view, ui, audio | Wave V4 | 10 |
| V5-B | Presentation integration, captures, accessibility | `src/{view,ui,audio,debug}/**`, `assets/**`, `data/strings/**`, `tests/unit/{view,ui,audio}/`, `docs/reports/screenshots/` | Wave V4 | 10 |
| V5-C | Balance with the scorecard | `data/*.json` (values only), `docs/reports/BALANCE_REPORT.md`, `tests/fixtures/data_variety/` (refresh) | V5-A | 14 |
| **V6-Q** | Release QA, device evidence | whole repo (fixes only); uses the device and the emulator | Wave V5 | 8 |

Totals: 26 tasks, about **262 agent-hours**. Six waves after the design task V0: V1 (1 task), V2 (9 in parallel), V3 (1), V4 (11
in parallel), V5 (2 in parallel, then 1), V6 (1). The slice (V1 to V3) is playable after about 100 hours.

**Critical path** (longest chain of dependent work): V1-S 12 -> V2-C 12 -> V3-I 10 -> V4-N 14 -> V5-A 10 -> V5-C 14 -> V6-Q 8 =
**80 hours** of sequential agent time, plus two owner playtests (after V3-I and after V4) and the merges. The third playtest is
the gate after V5-C.

**What to cut first if time is short** (in this order, each cut independent): (1) the Daily Run; (2) turret types and the third
sling; (3) cosmetic chaos beyond scorch marks; (4) `jammer` and `borer` (and `floor_breach`; the Tremor Rig's breaches become a
second stomp); (5) two weapons (`cutting_torch`, `hornet_rack`); (6) the second boss of each act pool; (7) the unlock packs
`u_p_corrupted` and `u_p_proto`. **Never cut:** the run plan, drafts, two weapon slots, bursters and minis, resume, the scorecard.

---

## 3. Wave 0

### W0-S Scaffold

**Goal.** A Godot 4.7.2 project at `C:\dev\tower-two` in which every contract in ARCHITECTURE.md exists as
compiling code, the data loads, the test harness works, and a desktop capture shows a 3D scene.

**Owned paths.** The whole repository.

**Read first.** ARCH (all). GDD 4, 5, 6, 7. `handoff/00_START_HERE/*`, `handoff/03_DATA/*`.
From the original (read-only): `C:\dev\tower\CLAUDE.md` (gotchas log), `tools\_common.ps1`, `tools\test.ps1`,
`tools\test_runner.py`, `tools\compile_check.gd`, `tools\compile_gate.py`, `docs\setup\gdunit4.md`.

**Deliverables.**

1. Folder tree of ARCH 3. `.gitignore`, `.gitattributes`, `.editorconfig` modelled on the original's.
   `build/.gdignore`, `docs/handoff/.gdignore`. `icon.svg` (simple amber hex ring on obsidian).
2. `project.godot` exactly as ARCH 1.1. `scenes/main.tscn` + `src/core/main.gd` (ARCH 7.4).
3. Copies (plain file copies, no edits to the sources):
   - `C:\dev\tower\addons\gdUnit4\` to `addons/gdUnit4/`; write `tools/GDUNIT_VERSION` (`6.2.3`), `tools/GODOT_VERSION`.
   - `C:\dev\tower\assets\fonts\{Oxanium-Variable.ttf, ShareTechMono-Regular.ttf, OFL-*.txt, LICENSES.md}` to `assets/fonts/`.
   - The extracted handoff folder `\\wsl.localhost\Ubuntu-24.04\home\paimo\tower-two\handoff\IRON_STATIC_CINDERFALL_AGENT_PACKAGE_v2\*`
     to `docs/handoff/` (all 26 files, PNGs included; the `.gdignore` keeps Godot from importing them).
   - `\\wsl.localhost\Ubuntu-24.04\home\paimo\tower-two\docs\*.md` to `docs/`.
   - `docs/handoff/03_DATA/{vertical_slice_balance,waves,visual_tokens}.json` to `data/` **and** to
     `tests/fixtures/data_baseline/` (the fixture copy is never tuned).
4. `data/content_ext.json` and `data/arena.json` verbatim from ARCH 5.2 (also copied into
   `tests/fixtures/data_baseline/`). `data/strings/{content,combat,screens,lore}_en.json` with the keys the
   stubs use (`content_en.json` complete: enemy, weapon, upgrade, ability and reason names).
5. `src/shared/**` complete (ARCH 4, 4.1). `src/content/defs/**` complete (ARCH 5.3).
6. `ContentLoader.build` and `load_from_dir` **working** (straight mapping and conversion; only basic checks:
   file present, JSON parses, ids known). `ContentValidator.validate` returns an empty list (W1-D fills it).
   `Content` autoload loads at boot and logs `content ok ...`. `Strings.t` working.
7. `src/sim/` complete for: `sim_world.gd` (full `step()` in the ARCH 6.2 order, all shared mutators and
   queries, `state_hash`, `summary`), `sim_config`, `sim_command`, `command_log`, `sim_event*`, `sim_events`,
   `sim_rng`, `state_hasher`, `formulas`, `run_stats`, `run_summary`, all `stores/`.
   Every system, `NavState`, `CombatState`, `PhaseState`, `Replay`, `PolicyBot` exist with the ARCH 6.6 and
   6.7 signatures and bodies that compile, do nothing and return neutral values (`Reason.Id.WRONG_STATE` for
   commands, `0`, `false`, `-1`), each marked `# TODO(<task id>)`.
8. Autoload stubs: `Log` (working), `Events` (all signals, complete), `Save` (in-memory default profile;
   API present), `Sfx` (no-ops), `Game` (`boot` shows the stub `BootScreen` over the `view_sandbox`, logs
   `game boot ...` then `boot ok`; other methods are no-ops that log).
9. `src/game/run_api.gd` complete; other `src/game/` files as compiling stubs.
10. `src/view/`: `battle_view.gd` composer complete; `MatLib`, `MeshBuilder`, `MeshKit`, `VisualQuality`
    **working** (flat palette materials; box, cylinder, prism, sphere, quad merging); `CameraRig` minimal but
    working (orthographic, 60 degrees down, fixed size that shows the arena); `ArenaView` stub (flat ground
    quad + a cylinder for the core); `ActorLayer` stub (one box per alive enemy, no pooling); `VfxLayer` no-op.
11. `src/ui/kit/` working basics (`UiTheme.build` with the two fonts and palette colors, `UiKit` helpers,
    `SafeArea.margins`, `HudLayout`). Stub scenes for every screen and overlay in ARCH 9: a full-rect
    `Control` with a title label and one button per signal, emitting that signal.
12. `src/debug/`: `DebugArgs` (parses ARCH 11), `CaptureRunner`, `SimPuppet`, `FakeRunApi`, `PerfHud` (empty),
    `view_sandbox.tscn`, `hud_sandbox.tscn`.
13. `tools/`: `_common.ps1`, `test.ps1`, `test_runner.py`, `compile_check.gd`, `compile_gate.py` adapted from
    the original (drop Sentry and canary-copy specifics you do not need; keep output parsing, the `APPDATA`
    redirect, the non-console exe for imports, the timeout and process-tree kill); `lint_layers.py` (ARCH 2
    table); `check.ps1` (import, compile gate, layer lint, tests, prints `CHECK OK`); `capture.ps1`.
    `tests/canary/test_canary_fail.gd` and `test.ps1 -Canary` proving a failing test yields a non-zero exit.
14. Tests: `tests/fixtures/test_content.gd` (`TestContent.baseline() -> ContentSet`);
    `tests/unit/shared/` (state machine: every legal and a sample of illegal transitions);
    `tests/unit/sim/test_formulas.gd` (all golden values of ARCH 6.5);
    `tests/unit/sim/test_stores.gd` (alloc/free/index_of, hash changes with state);
    `tests/unit/sim/test_sim_world_core.gd` (`kill_enemy` twice pays Scrap once and pushes one event;
    `add_scrap` clamps; `spawn_enemy` at capacity returns -1; `step` on stubs advances `tick` and is
    deterministic; `set_phase` rejects illegal transitions);
    `tests/unit/content/test_loader_baseline.gd` (4 enemies, 5 waves, wave totals 16/36/54/76/103, 64 slots,
    tick conversions);
    `tests/unit/core/test_contracts.gd` (for every class in ARCH 4 to 10: the script loads and has each listed
    method and signal; uses `get_script_method_list()` / `has_signal`).
15. `CLAUDE.md` for this project: the rules of section 1, the commands of 1.1, the layering table, and the
    relevant inherited gotchas (exit codes, `-d`, BOM, `.gdignore`, Variant-to-typed assignment,
    `integer_division`, `set_anchors_and_offsets_preset`, console exe hang, UNC paths).
    `README.md`: what it is, how to run the gate, pointers to docs.
16. `git init`, branch `main`, one commit `scaffold: project, contracts, harness`.

**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Imports and compiles with warnings as errors; all tests pass | `check.ps1` exits 0, last line `CHECK OK`; at least 40 tests | A01 |
| The wrapper detects failures | `test.ps1 -Canary` prints `CANARY OK` | A20 |
| Contracts present | `test.ps1 -Path res://tests/unit/core` passes | - |
| Data loads | output of `check.ps1` contains `content ok enemies=4 waves=5` | A07 |
| 3D renders on desktop | `capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out C:\dev\tower-two\build\shots\w0_view.png -Size 1080x2400` prints `CAPTURE OK`; open the PNG: ground, core cylinder and boxes visible from a high angle | A04 |
| HUD sandbox renders | same with `res://src/debug/hud_sandbox.tscn`, `w0_hud.png` | - |
| Clean tree | `git -C C:\dev\tower-two status --short` is empty after the commit | - |

---

## 4. Wave 1 (eight tasks in parallel; all depend only on W0-S)

Every Wave 1 task ends with: `check.ps1` exits 0 with `CHECK OK` (run in its own worktree).

### W1-A Sim: arena, navigation, spawning

**Goal.** Enemies enter from the two regions, cross the yard without lanes, queue at the cap, take attack slots.
**Owned.** `src/sim/nav/**`, `src/sim/systems/spawn_system.gd`, `src/sim/systems/movement_system.gd`,
`data/arena.json`, `data/content_ext.json` (values only, no schema change), `tests/unit/sim_nav/**`.
**Read.** ARCH 5.2, 5.3, 6.1 to 6.4, 6.6 "Nav and spawn". GDD 4.2, 6, 7. `handoff/02_TECHNICAL/ARCHITECTURE.md`
"Continuous arena movement". `handoff/03_DATA/README.md`.
**Deliverables.** `ArenaGrid`, `FlowField`, `SpatialHash`, `AttackSlots`, `NavState` (with `hash_into`),
`NavSystemHooks`, `SpawnSystem`, `MovementSystem` as specified. A debug dump
`FlowField.to_ascii() -> String` for reports.
**Tests to add (`tests/unit/sim_nav/`).**
- Flow field: every spawn-region cell reachable; directions point downhill; blocked cells are never entered.
- Spawn: wave 1 schedule yields 16 spawns at ticks 0, 102, 204, ...; same-tick order is group then ordinal;
  wave 5 totals 103; ids are strictly increasing; positions lie on the region segment; the same seed gives
  the same positions, a different seed differs.
- Cap and queue: force 50 alive, schedule 10 more: none spawn, `pending_count == 10`; kill 3: exactly 3 enter
  on the next tick(s); nothing is lost (`spawned + pending == scheduled` at every tick).
- Movement: a lone Skitter from the right region reaches a slot within 15% of straight-line time; it becomes
  `ST_ATTACKING` with `attack_cd == attack_period_ticks`; a stunned enemy does not move; displacement per tick
  is bounded; no position is NaN or outside the grid over 3,600 ticks with 50 mixed enemies.
- Slots: 50 enemies all get distinct slots; the Hulk holds 3 adjacent slots; a killed enemy's slot is free
  the same tick.
- Archetypes: Rusher arrives first, Hollow Warden is displaced less than a Skitter by the same neighbor
  push, the Hulk is never displaced (A08).
- Stuck: an enemy pinned by a test obstacle gets `ENEMY_STUCK` and resumes progress; it is still alive.
- Determinism: two worlds, same seed, 3,600 ticks with spawns: identical `state_hash()`.
**Acceptance.** `test.ps1 -Path res://tests/unit/sim_nav` passes with at least 25 tests (A05, A06, A08).
A micro-benchmark test asserts `MovementSystem.step` with 50 enemies averages under 1.0 ms on the dev machine.

### W1-B Sim: targeting, weapons, damage, core attacks

**Goal.** The Warden and turrets pick targets by the priority rule and kill; enemies in slots damage the core.
**Owned.** `src/sim/systems/{targeting,weapon_system,turret_system,damage_resolver,core_attack_system,combat_state}.gd`,
`tests/unit/sim_combat/**`.
**Read.** ARCH 6.2 to 6.6 "Combat", 6.5. GDD 5.1, 5.3, 6. `handoff/02_TECHNICAL/ARCHITECTURE.md` "Targeting", "Combat formula".
**Notes.** Tests place enemies by writing the store directly (`world.spawn_enemy` then set `x`, `z`, `state`,
`path_dist`); do not rely on W1-A's movement.
**Tests to add.**
- Ranking: attacking beats moving; lower ETA bucket beats higher; Rusher beats non-Rusher in the same bucket;
  nearer beats farther; lower id wins a full tie; out-of-range and dead enemies are never picked.
- Lock: the target is kept for 24 ticks even when a better one appears; it is dropped the tick it dies.
- Cadence: over 3,600 ticks the pistol's shot count equals the exact number derived from the ARCH 6.5 cadence rule;
  magazine 12 then a 75-tick reload; SMG 6 shots/s, 30 rounds, 96-tick reload; fire-rate level 1 gives 2.3
  shots/s (exact shot count over 6,000 ticks); overdrive doubles the rate and still reloads.
- Damage: golden values of ARCH 6.5 through `DamageResolver.hit`; hp never below 0; overkill does not pay
  twice; two sources killing on the same tick pay Scrap once (A09).
- Turret: inactive turrets never fire; an active turret fires 3 shots/s at range 17 from its pad, ignores
  the damage level, benefits from armor piercing; events carry `TURRET_0` or `TURRET_1`.
- Core: a Skitter in a slot hits for 12 every 90 ticks, first hit at tick 90 after arrival; a stunned
  attacker's timer is frozen; with `shield_hp = 100` a 90 hit leaves shield 10 and core unchanged, the next
  90 hit removes 10 shield and 80 core; `debug_invulnerable_core` leaves the core untouched.
**Acceptance.** `test.ps1 -Path res://tests/unit/sim_combat` passes with at least 30 tests (A03, A09, A10 firing part, A11 firing part).

### W1-C Sim: commands, economy, abilities, phases

**Goal.** Purchases are atomic and idempotent, abilities follow their timers, the run moves through its phases.
**Owned.** `src/sim/systems/{command_system,economy_system,ability_system,phase_system,phase_state}.gd`,
`tests/unit/sim_flow/**`.
**Read.** ARCH 4.1, 6.2, 6.3, 6.6 "Economy, abilities, flow". GDD 3, 5.2, 5.4, 7, 8. `handoff/02_TECHNICAL/ARCHITECTURE.md`
"Purchase transactions". `handoff/02_TECHNICAL/INTERFACES_AND_EVENTS.md` "State machine".
**Notes.** Tests drive `SpawnSystem` through its contract only where needed; to test phases without W1-A,
use the debug hook `world.phase_state.force_wave_spawned: bool` (you own `PhaseState`; when true,
`PhaseSystem` treats the wave as fully spawned) and kill enemies with `world.kill_enemy`.
**Tests to add.**
- Purchase: exact cost per level for all five upgrades; insufficient Scrap, max level, wrong state, unknown
  id and `min_wave` each return the right `Reason` and change nothing; the same `command_id` twice gives one
  purchase and one `DUPLICATE_COMMAND`; two different command ids for the same upgrade in one tick buy once
  (A10); third turret is refused with `MAX_LEVEL` and pads 0 then 1 activate in order (A11); SMG purchase
  sets weapon 1, magazine 30, clears a reload.
- Abilities (A12): EMP sets 180 ticks on normals and 60 on the boss, cooldown 2,100 from activation; a
  second EMP during a stun does not extend a longer stun; boss immunity lasts 300 ticks after its stun ends;
  shield sets 100 for 480 ticks, ends early at 0, cooldown 3,000 starts at the end; overdrive active 360,
  cooldown 3,600 from the end; activation on cooldown, while active, in INTERMISSION, PREPARING and after
  the run each reject without starting a cooldown.
- Phases (A07, A14): PREPARING lasts 180 ticks; SPAWNING to CLEARING only when fully spawned; CLEARING to
  INTERMISSION only at 0 alive; INTERMISSION lasts 480 ticks or ends on skip; skip outside INTERMISSION is
  `WRONG_STATE`; after wave 5 clear the phase is VICTORY with `waves_completed == 5`; core at 0 gives DEFEAT
  the same tick, even when the last enemy dies on that tick; `RUN_FINISHED` is pushed exactly once; `step()`
  after the end changes nothing (hash stable).
- Commands are applied in submission order at the next tick and logged with that tick.
**Acceptance.** `test.ps1 -Path res://tests/unit/sim_flow` passes with at least 35 tests.

### W1-D Content validation and save system

**Goal.** Bad data is rejected with clear messages; the profile survives corruption and never double-pays.
**Owned.** `src/content/content_loader.gd`, `src/content/content_validator.gd`, `src/content/content_db.gd`,
`src/core/strings.gd`, `src/save/**`, `data/strings/content_en.json`, `tests/unit/content/**`,
`tests/unit/save/**`, `tests/fixtures/data_bad/**`, `tests/fixtures/saves/**`.
**Read.** ARCH 5, 7.5. GDD 8.2, 8.3. `handoff/03_DATA/README.md`, `handoff/02_TECHNICAL/ARCHITECTURE.md` "Persistence".
The original's `C:\dev\tower\src\save\save_store.gd` and `src\core\disk_save_fs.gd` for the atomic-write pattern (read-only).
**Deliverables.** Full `ContentValidator` (every rule of ARCH 5.4; the reachability rule may call
`FlowField.build`, which is a stub until W1-A merges: guard with "skip when the field has no cells" and leave
a test marked to enable in Wave 2). Loader error messages with file and JSON path. `Profile`, `ProfileCodec`,
`SaveFs`, `DiskSaveFs`, `MemorySaveFs`, `Save` autoload complete.
**Tests to add.**
- One bad fixture per validation rule (unknown enemy id, negative hp, NaN, duplicate wave index, missing
  wave, zero count, unknown region, wrong schema version, tick-rate mismatch, too few slots, missing palette
  token), each producing exactly the expected error.
- Baseline loads with zero errors; unknown top-level key is reported.
- Save (A15): round trip; first run gives `NEW_PROFILE`; truncated main file recovers from `.bak`; both bad
  gives `RESET_AFTER_CORRUPTION` and keeps a `.corrupt` copy; `schema_version` 99 gives
  `NEWER_SCHEMA_SET_ASIDE` and the original bytes are preserved in `.newer`; wrong types and negative numbers
  are sanitized; a failed write (fs returns false) leaves the previous file intact.
- Reward once: `grant_run_reward` with the same run id twice adds Data once and returns false the second
  time; victory updates `missions_completed` and `best_core_hp` (max); defeat does not; the awarded list is
  capped at 64.
- Settings: unknown key rejected; type checked; `settings_changed` emitted; values survive reload.
- One test with `DiskSaveFs` on `user://` (the wrapper redirects it) proving rename-over-existing works on Windows.
**Acceptance.** `test.ps1 -Path res://tests/unit/content,res://tests/unit/save` passes with at least 35 tests.

### W1-E View: camera, arena, kit

**Goal.** The yard looks like the approved reference from the approved angle, on every aspect ratio.
**Owned.** `src/view/camera/**`, `src/view/arena/**`, `src/view/kit/**`, `tests/unit/view/camera_*.gd`,
`tests/unit/view/kit_*.gd`, optional generated `assets/textures/**`.
**Read.** ARCH 8, 13. GDD 4.1, 4.2, 12. `handoff/02_TECHNICAL/ART_DIRECTION.md`. View
`docs/handoff/04_VISUAL_REFERENCES/topdown_approved.png` and `environment_mood.png` with the Read tool.
Section 6 of this plan (placeholder art).
**Deliverables.** `CameraFit.solve` (pure) and `CameraRig`; `ArenaView` with: ground (concrete, seams, puddle
gloss, hazard stripes, "B-4" stencil via `Label3D` or generated texture), the four props from `arena.json`,
out-of-bounds dressing (containers, gantry legs, pipes, lamp posts), Relay Core B-4 with the label
"RELAY CORE B-4", turret pads (empty and occupied look), Warden ring, light pools as additive quads, one
directional light, `WorldEnvironment`; `set_core_state` (dim, flicker, dead); quality tiers; `ShaderWarmup`;
`MatLib` and `MeshBuilder` extended as needed (signatures unchanged).
**Tests to add.** `CameraFit`: pitch within 55 to 65; for viewports 1080x1920, 1080x2340, 1080x2400 and
1080x1120 all four arena corners and the spawn-region ends project inside the band between `top_px` and
`viewport_h - bottom_px` and inside the width; `px_per_meter` >= 40 on the three phone sizes;
`world_to_screen` round trip. Kit: `MeshBuilder` merges N primitives into one mesh with one surface per
material; `MatLib.mat` returns the same instance for the same id; palette colors match the tokens.
`ArenaView.setup` under the headless renderer creates no more than 60 nodes and does not error.
**Acceptance.**
- `test.ps1 -Path res://tests/unit/view` passes (your files) with at least 12 tests (A04).
- `capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out ...\build\shots\w1e_1080x2400.png -Size 1080x2400`
  and the same at `1080x1920` and `1080x1120`. Open each PNG and confirm: core at the left, pads and Warden
  ring visible, whole playable rectangle inside the middle band, label reads "RELAY CORE B-4", palette roles
  respected, no concept image used as a texture (A04, A17). Attach the three PNG paths.

### W1-F View: actors and VFX

**Goal.** Fifty individually readable enemies, a Warden that turns and fires, turrets, and pooled effects.
**Owned.** `src/view/actors/**`, `src/view/vfx/**`, `tests/unit/view/actors_*.gd`, `tests/unit/view/vfx_*.gd`.
**Read.** ARCH 8, 13, 11 (`SimPuppet`). GDD 6, 12.3, 12.4, 2.4 (no skull faces). View
`docs/handoff/04_VISUAL_REFERENCES/enemy_roster.png` and `topdown_approved.png`. Section 6 of this plan.
**Deliverables.** `ActorMeshes` (procedural merged meshes for the four enemies, Warden lower and upper body,
pistol, SMG, turret); enemy pool keyed by enemy id with interpolation, facing, procedural motion per
archetype, hit flash by material swap, death release; blob-shadow and health-bar MultiMeshes; `WardenView`
(yaw to `aim`, recoil on `shot_fired`, weapon swap on `weapon_changed`, reload pose); `TurretView` (deploy on
`turret_deployed`, yaw, recoil); `VfxLayer`: tracers, muzzle flashes, impact sparks, death bursts, floating
"+Scrap" texts (`Label3D` pool or projected 2D labels), EMP ring, shield dome on the core, overdrive glow,
core-hit sparks, boss footfall dust; `set_reduced_flash`; quality tiers. Everything pooled to the sizes in ARCH 13.
`SimPuppet` is owned by Wave 0 and is read-only for you. Drive your tests by writing the stores and emitting
`Events` yourself.
**Tests to add.** Spawn 50 via the store then `bind`: 50 visible actors; kill 10: 10 released; 500 cycles of
spawn and kill leave the node count unchanged (no leak); interpolation at alpha 0, 0.5, 1 gives prev, mid,
current; unknown id in `enemy_killed` is ignored; `unbind` hides everything; tracer pool never exceeds 48;
reduced flash disables the full-screen flash node; silhouettes differ: bounding-box height ratio Hollow
Warden / Skitter >= 1.6 and Hulk footprint >= 4x Hollow Warden.
**Acceptance.**
- `test.ps1 -Path res://tests/unit/view` passes (your files) with at least 14 tests.
- `capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out ...\build\shots\w1f_50.png -Size 1080x2400 -Frames 240`
  (the sandbox puppet holds 50 mixed enemies). Open the PNG and confirm each archetype is distinguishable,
  every enemy shows a red optic and a shadow, tracers are amber, the Warden faces its target (A08, A17).

### W1-G UI: combat HUD

**Goal.** The whole combat interface, driven only by `RunApi` and `Events`.
**Owned.** `src/ui/combat/**`, `assets/icons/**`, `data/strings/combat_en.json`, `tests/unit/ui/combat_*.gd`.
**Read.** ARCH 7.1, 7.2, 9. GDD 4.3, 5.2, 5.4, 9, 10.1, 10.3, 10.4. `handoff/03_DATA/visual_tokens.json`.
View `docs/handoff/04_VISUAL_REFERENCES/armory_style.png` and `topdown_approved.png` (style and zones only).
**Deliverables.** `CombatHud` (top bar: pause, core bar with percent and shield overlay, wave n/5, Scrap;
boss bar; wave banner and whisper line; hint line; low-core warning), upgrade tab with affordable count,
upgrade drawer with five cards (icon, name, level/max, next effect, cost, reason line, disabled look),
"COMBAT CONTINUES" strip, intermission panel with countdown and CONTINUE, ability bar (three buttons with
radial cooldown, seconds, active drain, state text), magazine/reload readout, `PauseOverlay`. SVG icons for
the five upgrades, three abilities, Scrap, core, pause (flat two-tone, 128x128). All text through `Strings`.
Each tap mints one `next_command_id()` and issues one command.
**Tests to add (with `FakeRunApi`).** Tapping an affordable card issues exactly one `purchase_upgrade` with a
fresh id; a disabled card issues none and shows the reason text; card text shows exact cost and level; at max
level the cost is hidden and "MAX" shows; the affordable count matches; ability button states for ready,
active and cooling; a tap while cooling issues no command; boss bar visible only when `boss_hp() >= 0`; the
strip is visible only when the drawer is open in SPAWNING or CLEARING; the intermission panel opens on
`intermission_started` and CONTINUE calls `skip_intermission` once; every interactive control is at least
132x132 px; safe-area margins move the top bar down by the given inset; no label is empty at any state.
**Acceptance.**
- `test.ps1 -Path res://tests/unit/ui` passes with at least 20 tests (A16 automated part).
- `capture.ps1 -Scene res://src/debug/hud_sandbox.tscn -Out ...\build\shots\w1g_hud_1080x2400.png -Size 1080x2400`
  and at `1080x1920` and `1080x1120`. Open them: top band about 11%, bottom band about 23%, nothing clipped
  or overlapping, text legible, no weapon-card strip, no Data counter (A16, A17).

### W1-H Android pipeline

**Goal.** Prove early that this project exports, installs and renders 3D on the `tower_phone` emulator.
**Owned.** `export_presets.cfg`, `tools/run_emulator.ps1`, `tools/deploy_android.ps1`,
`tools/smoke_android.ps1`, `docs/reports/BUILD_INSTRUCTIONS.md`, `docs/reports/android_w1h/**`.
**Uses the emulator (exclusive in this wave).**
**Read.** ARCH 1, 1.2, 5.1, 11, 12. `handoff/02_TECHNICAL/ANDROID_BUILD.md`. From the original (read-only):
`C:\dev\tower\tools\{run_emulator,deploy_android,smoke_android}.ps1`, `docs\setup\DEV_ENVIRONMENT.md`,
`docs\setup\android_export.md`, and the Android gotchas in `C:\dev\tower\CLAUDE.md`.
**Deliverables.** The preset of ARCH 1.2. The three scripts adapted (package and preset defaults for
Cinderfall; `-Serial` support kept; smoke checks: process alive, no `SCRIPT ERROR` / `FATAL` /
`ERROR: Content:` in logcat, log contains `content ok` and `boot ok`, screenshot not blank and contains
palette amber or cyan; optional `-MinFps` parsing of `[PERF]`). `BUILD_INSTRUCTIONS.md`: versions actually
found (Godot, templates, JDK, SDK, build-tools, NDK), exact commands, emulator notes, how to target a phone.
**Acceptance.**
| Check | Command | Matrix |
|---|---|---|
| Emulator up | `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\run_emulator.ps1` then wait 25 s | - |
| Export, install, launch | `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\deploy_android.ps1 -ProjectPath C:\dev\tower-two -Package com.normalexception.games.cinderfall.dev -Preset Cinderfall -LogSeconds 40` ends with `== RUNNING (pid n)` | A02 (emulator) |
| Smoke | `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\smoke_android.ps1 -SkipDeploy` prints `SMOKE OK` | A02 |
| Data is in the APK | `py -3.12 -I -c "import zipfile,sys; n=zipfile.ZipFile(sys.argv[1]).namelist(); print([x for x in n if 'data/' in x and x.endswith('.json')])" C:\dev\tower-two\build\com.normalexception.games.cinderfall.dev.debug.apk` lists the six data files and the strings | A07 |
| Permissions | `aapt2 dump permissions <apk>` (from `%LOCALAPPDATA%\Android\Sdk\build-tools\36.0.0`) shows `android.permission.VIBRATE` and no `INTERNET` | A19 |
| Screenshot | `cmd /c "cd /d C:\ && adb exec-out screencap -p > C:\dev\tower-two\build\shots\w1h_emulator.png"`; the 3D sandbox is visible in portrait | A02, A04 |
The renderer is **Mobile (Vulkan)** by owner decision. Also verify in logcat that the boot line reports the Mobile/Vulkan
renderer and that no OpenGL fallback happened (fallback counts as a FAIL for this task). If the emulator cannot render
the 3D scene under Vulkan (black screen, Vulkan errors, or a fallback), record the log and the emulator's
`-gpu` mode, try `-gpu host` and then `-gpu swangle_indirect`, and report the result to the coordinator as a blocker.
Do not change the renderer yourself; the coordinator will take it to the owner.

---

## 5. Waves 2 to 4

### Wave 2 (five tasks in parallel; all depend on the merged Wave 1)

Every Wave 2 task ends with `check.ps1` exiting 0 with `CHECK OK`.

#### W2-A Game flow and run controller

**Goal.** One continuous playable loop on desktop: boot, menu, briefing, run, pause, results, retry.
**Owned.** `src/game/**` (except `run_api.gd`), `src/core/game.gd`, `tests/unit/game/**`, `tests/integration/game/**`.
**Read.** ARCH 4.1, 7 (all), 9 (screen table), 11. GDD 3, 10.2.
**Deliverables.** `TickDriver`, `RunController` (event drain to `Events` in order, with id-to-`StringName`
mapping), `SimRunApi`, `Game` (state machine mirroring, screen swaps using the Wave 0 stub screens or the
W2-B screens through the same contract, camera fit on resize using `CombatHud.top_band_px/bottom_band_px`,
`--seed`, `--autoplay`, `--scenario=hold<N>`, `--quality`, `--debug-perf` wiring to `PerfHud`), `MobileShell`,
`BackPolicy`, `Haptics`. Reward grant on `RUN_FINISHED` before `Events.run_finished`. Clean teardown: after
`quit_to_menu` or retry there are no leftover nodes, connections or sim references.
**Tests to add.** `TickDriver`: 1.0 s of 60 FPS frames and of 30 FPS frames both give 60 ticks; a 1 s hitch
runs at most 4 ticks and drops the rest; paused runs 0 ticks (A13). `RunController`: every `SimEventKind`
maps to its signal with the right payload; commands while paused are rejected with `Reason.Id.PAUSED` and
never reach the sim; pausing for 600 frames leaves `state_hash()` and all cooldowns unchanged (A13).
`BackPolicy` table. Integration (headless, real sim, stub or real screens, `MemorySaveFs`): a boosted-damage
autoplay run reaches VICTORY, grants `100 + floor(core_hp/20)` once, and calling the grant path again grants
nothing (A14, A15); a `--autoplay=none` run reaches DEFEAT and grants `10 * waves_completed`; retry 20 times
leaves the node count and `Events` connection count unchanged.
**Acceptance.** `test.ps1 -Path res://tests/unit/game,res://tests/integration/game` passes with at least 20
tests. `capture.ps1` cannot drive the main scene; instead run the game for 20 s with
`"C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path C:\dev\tower-two -- --autoplay=greedy --seed=1 --mute --quit-after-run`
(implement `--quit-after-run`: quit with code 0 after the results state is reached) and attach the log lines
`boot ok`, `run started`, `run finished result=...`.

#### W2-B Meta screens and theme

**Goal.** Boot, menu, briefing, results and settings in the armory panel style, with all lore text.
**Owned.** `src/ui/screens/**`, `src/ui/kit/**`, `data/strings/screens_en.json`, `data/strings/lore_en.json`,
`tests/unit/ui/screens_*.gd`, `tests/unit/ui/kit_*.gd`.
**Read.** ARCH 7.5, 9. GDD 2, 8.2, 10.2, 10.3, 12.1. View `armory_style.png`. From the original (read-only):
`C:\dev\tower\src\ui\theme_builder.gd`, `safe_area.gd` for patterns.
**Deliverables.** The five screens per the ARCH 9 table (signatures unchanged). `UiTheme` final (chamfered
panels as `StyleBoxFlat` or drawn, cyan rim, amber accents, high-contrast variant), `UiKit` components.
Results: count-up of Data (skipped under reduced motion is not required), kills by type, time, core
remaining. Settings writes through `Save.set_setting` and applies at once. Lore strings from GDD 2.3.
Do not change `UiKit`/`UiTheme` function signatures (the combat HUD uses them).
**Tests to add.** Each screen: `setup` with baseline data fills every label (no `#key#` placeholders); each
button emits its signal once; all controls at least 132 px; settings toggles call `Save.set_setting` with the
right key and type; results shows the reward passed in and never calls `Save.grant_run_reward` (grep-style
assertion on the script source is acceptable); theme text colors reach contrast 4.5:1 against panel
background (compute from the palette).
**Acceptance.** `test.ps1 -Path res://tests/unit/ui` passes (all UI tests, at least 15 new).
Captures of each screen at 1080x2400 via a small sandbox you add under `src/ui/screens/_sandbox/`
(`capture.ps1 -Scene res://src/ui/screens/_sandbox/menu_sandbox.tscn ...`); open and review them (A16, A17).

#### W2-C Audio

**Goal.** Every listed sound exists and plays from events, with caps and toggles.
**Owned.** `src/audio/**`, `assets/audio/**`, `tools/audio_gen/**`, `tests/unit/audio/**`.
**Read.** ARCH 10, 7.1. GDD 11. From the original (read-only): `C:\dev\tower\src\audio\{audio_director,sfx_pool,voice_gate,audio_event_router}.gd` for patterns.
**Deliverables.** `tools/audio_gen/gen.py` (Python 3.12 standard library only: `wave`, `math`, `random` with
fixed seeds; run with `py -3.12 -I`) writing all 29 SFX (mono 16-bit, 22.05 or 44.1 kHz, each under 1.5 s
except stingers) and the two loops (seamless, 12 to 24 s) into `assets/audio/`. `Sfx` autoload: 16-voice
pool, per-id cap of 3 starts per frame and a per-id minimum interval, pitch jitter from its own RNG, router
from `Events` (shots, hits by armor, deaths by class, core hits, abilities, reload, waves, boss, low core,
victory, defeat), ambience and intensity by wave, `pause_all`/`resume_all`, settings, `--mute`.
`assets/audio/LICENSE.md` stating all audio is generated by the project script.
**Tests to add.** Every id in ARCH 10 has a loadable stream; `play` of an unknown id logs once and does not
crash; 100 `play(&"shot_smg")` calls in one frame start at most 3 voices; `disabled` plays nothing;
`sound_on = false` silences SFX; the router maps `enemy_killed` of a Hulk to `death_boss`; `pause_all` stops
position advance. Generator: running it twice produces byte-identical files.
**Acceptance.** `test.ps1 -Path res://tests/unit/audio` passes with at least 12 tests.
`py -3.12 -I C:\dev\tower-two\tools\audio_gen\gen.py --check` exits 0 (regenerates to a temp dir and compares hashes).

#### W2-D Sim harness, determinism, balance tuning

**Goal.** Prove the full simulation: five waves end to end, reproducible, stable under stress, and tuned.
**Owned.** `src/sim/**` except `sim_world.gd` and `stores/**`; `data/vertical_slice_balance.json`,
`data/waves.json`, `data/content_ext.json`, `data/arena.json`; `tools/sim_run.gd`, `tools/sim_run.ps1`,
`tools/balance_run.gd`, `tools/balance_run.ps1`; `tests/integration/sim/**`, `tests/stress/**`,
`tests/unit/sim*/**`; `docs/reports/BALANCE_REPORT.md`.
**Read.** ARCH 6 (all). GDD 7, 8.4. `handoff/06_QA_AND_RELEASE/{TEST_PLAN,KNOWN_RISKS}.md`. From the original
(read-only): `C:\dev\tower\tools\sim_run.gd`, `balance_run.gd`, `src\sim\ai\policy_bot.gd` for patterns.
**Deliverables.** `Replay.run`, `PolicyBot` (NONE, GREEDY). `sim_run` (prints per run: result, ticks,
seconds, peak alive per wave, Scrap earned and spent, purchases, `state_hash`, `event_hash`; last line
`SIM SUMMARY: runs=N victories=V defeats=D`). `balance_run` (20 seeds x {none, greedy}; compares with GDD 8.4;
last line `BALANCE: PASS|WARN|FAIL ...`; exit 0 on PASS or WARN). Fix sim defects found in the Wave 1
systems. Tune `data/*.json` toward GDD 8.4 using the allowed levers; record every change, with before and
after numbers, in `BALANCE_REPORT.md`. Enable W1-D's reachability test.
**Tests to add.**
- Integration (TEST_PLAN "Integration"): seeded five-wave run with `debug_damage_mult = 5` reaches VICTORY;
  no wave completes while pending or alive > 0 (assert at every tick); the cap of 50 is never exceeded and
  `spawned == scheduled` per wave; boss and escorts must all die before VICTORY; a no-purchase run reaches
  DEFEAT; Scrap earned equals the sum of kills times reward (A06, A07, A09, A14).
- Determinism: same seed and command log twice gives identical `state_hash` and `event_hash` at ticks 600,
  6,000 and the end; `Replay.run` of a greedy bot's log reproduces the same final hash; 10 different seeds
  give at least 9 distinct hashes.
- Stress (TEST_PLAN "Stress"): hold 50 alive with spawn and death churn for 36,000 ticks (10 minutes): no
  NaN or infinite position, no enemy `ST_MOVING` longer than `2 * stuck_ticks` without an `ENEMY_STUCK`
  event, store `high_water` never above capacity, average tick time under 1.0 ms (A06).
- Seed sweep: 20 seeds, greedy bot: no script error, every run terminates before tick 60,000.
**Acceptance.**
- `test.ps1 -Path res://tests/unit/sim,res://tests/unit/sim_nav,res://tests/unit/sim_combat,res://tests/unit/sim_flow,res://tests/integration/sim,res://tests/stress` passes.
- `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\sim_run.ps1 -Seed 1 -Policy greedy -Runs 5` exits 0; paste the output.
- `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\balance_run.ps1 -Runs 20` exits 0; paste the
  `BALANCE:` line. If peaks or duration cannot reach the targets with the allowed levers, report measured
  values and the gap; do not fake it (A07, risk "density vs duration").

#### W2-E View integration, quality tiers, perf HUD

**Goal.** The battlefield stays readable and within budget at 50 enemies, on three quality tiers.
**Owned.** `src/view/**` except `battle_view.gd`; `src/debug/**`; `tests/unit/view/**`.
**Read.** ARCH 8, 11, 13. GDD 6, 10.3, 12. `handoff/06_QA_AND_RELEASE/KNOWN_RISKS.md` (accessibility, camera).
**Deliverables.** Merge fixes between arena, actors and VFX (z-fighting, scale, light pools vs actors).
`VisualQuality` tiers wired through `BattleView.set_quality`. `PerfHud` and the `[PERF]` line (frame avg, p95,
worst second, sim tick ms, enemies, draw calls, primitives, video memory). High-contrast mode for actors
(brighter optics, rim). Boss world marker. Debug overlay toggles: flow field arrows, attack slots, stuck
enemies, spawn regions (handoff P2 gate "visible debug paths"). `SimPuppet` scenarios `hold10`, `hold28`,
`hold50`, `boss`. Draw-call and node budgets met.
**Tests to add.** With 50 enemies bound under the headless renderer: node count under 400; pools at budget;
`set_quality(LOW)` removes omni lights and rain; debug overlay toggles create and free their nodes; `PerfHud`
formats the `[PERF]` line so the regex in `smoke_android.ps1` matches.
**Acceptance.** `test.ps1 -Path res://tests/unit/view` passes. Captures at 1080x2400 of `hold10`, `hold28`,
`hold50`, `boss` and of the debug overlay; open them and confirm individual enemies are countable at 50, the
boss reads at a glance, palette roles hold (A06 visual part, A08, A17). Report draw calls and primitives
from a desktop `--debug-perf --scenario=hold50` run of 30 s (desktop numbers, labelled as such).

### Wave 3 (two tasks in parallel; depend on the merged Wave 2)

#### W3-A Gameplay integration and fixes

**Goal.** The real game, through `Game` and `RunController`, satisfies every functional acceptance row.
**Owned.** `src/sim/**`, `src/game/**`, `src/core/**`, `src/content/**`, `src/save/**`, `src/shared/**`,
`data/*.json`, `tests/**` except `tests/unit/{view,ui,audio}/**`, `tools/{sim_run,balance_run}.*`.
(Contract files in these paths may be changed only to fix a defect, with the contract test and ARCHITECTURE.md
updated in the same change and the change listed in the report.)
**Read.** `handoff/06_QA_AND_RELEASE/{ACCEPTANCE_MATRIX,TEST_PLAN}.md`. All Wave 2 reports ("needs owner" lists).
**Deliverables.** End-to-end tests through the main scene in headless mode (TEST_PLAN "Integration"): fresh
profile, autoplay greedy, VICTORY, profile on disk updated once, relaunch (new `Save` load) shows the same
totals; DEFEAT path; pause in every phase freezes the hash; purchase of the SMG and a turret changes
`shot_fired` sources and cadence in the event stream (not only UI labels); each ability tapped on cooldown
and while paused is rejected; **retry 100 times** in one process without growth in node count, connections
or memory beyond 5%; app-pause notification pauses and flushes. Fix all functional defects found, rerun
`balance_run`, update `BALANCE_REPORT.md` if data changed. Write `docs/reports/TEST_REPORT.md` (commands,
counts, exit codes, per-row status for A03, A05 to A15).
**Acceptance.** `check.ps1` exits 0 with `CHECK OK`. `balance_run.ps1 -Runs 20` exits 0.
`test.ps1 -Path res://tests/integration` passes with the new end-to-end suite (at least 12 tests).

#### W3-B Presentation integration and fixes

**Goal.** What the player sees and hears is correct, legible and consistent on every supported screen shape.
**Owned.** `src/view/**`, `src/ui/**`, `src/audio/**`, `src/debug/**`, `assets/**`, `data/strings/**`,
`tests/unit/{view,ui,audio}/**`, `docs/reports/screenshots/**`, `docs/reports/ASSET_LICENSES.csv`.
**Desktop only. Does not use the emulator.**
**Read.** GDD 10, 11, 12. `handoff/02_TECHNICAL/ART_DIRECTION.md`. All five reference PNGs. Wave 2 reports.
**Deliverables.** A scripted capture mode (`--autoplay=greedy --seed=1 --capture-run=<dir>`, implemented in
`src/debug/`, saving the window image at fixed moments: menu, briefing, wave 1, upgrade drawer open during
combat, intermission, wave 4 swarm, wave 5 with boss and 40+ enemies, pause, victory results, and a second
run for defeat results) at 1080x2400, plus the HUD at 1080x1920, 1080x2340 and 1080x1120.
Review every image against GDD 10 and 12 and fix: clipped or overlapping UI, text under 30 px, contrast
failures, wrong palette roles, enemy optics that read as paired eyes, the core label, missing feedback
(purchase pulse, deny shake, low-core warning, boss bar), reduced-flash and high-contrast modes, audio
routing gaps. `ASSET_LICENSES.csv`: one row per asset group (fonts OFL, GdUnit4 MIT, generated audio,
procedural meshes, icons) with source and license; mirrors `handoff/06_QA_AND_RELEASE/ASSET_MANIFEST.csv`
ids with the status `placeholder-procedural`.
**Acceptance.** `check.ps1` exits 0 with `CHECK OK`. The screenshot set exists under
`docs/reports/screenshots/` (at least 14 PNGs), each opened and listed in the report with a pass or issue
note (A04, A16 desktop part, A17). No file from `docs/handoff/04_VISUAL_REFERENCES/` is referenced by any
resource: `grep -r "04_VISUAL_REFERENCES" C:\dev\tower-two\src C:\dev\tower-two\assets` returns nothing.

### Wave 4 (single task)

#### W4-A Release QA and Android evidence

**Goal.** The handoff's final delivery list, with honest evidence.
**Owned.** Whole repository (fixes limited to defects found here). **Uses the emulator.**
**Read.** `handoff/06_QA_AND_RELEASE/*`, `handoff/02_TECHNICAL/ANDROID_BUILD.md`, `handoff/05_AGENT_PROMPTS/REVIEW_TEMPLATE.md`,
`docs/reports/*`. `C:\dev\tower\tools\smoke_android.ps1` (soak and `-MinFps` parts, read-only).
**Steps and acceptance.**

| # | Step | Command / evidence | Matrix |
|---|---|---|---|
| 1 | Full gate | `check.ps1` exits 0, `CHECK OK`; record the test count | A01 |
| 2 | Canary | `test.ps1 -Canary` prints `CANARY OK` | A20 |
| 3 | Balance | `balance_run.ps1 -Runs 20` exits 0; `sim_run.ps1 -Seed 1 -Policy greedy -Runs 5` | A07 |
| 4 | Export and deploy | `run_emulator.ps1`; wait 25 s; `deploy_android.ps1 -ProjectPath C:\dev\tower-two -Package com.normalexception.games.cinderfall.dev -Preset Cinderfall -LogSeconds 40` ends with `== RUNNING` | A02 |
| 5 | Smoke | `smoke_android.ps1 -SkipDeploy` prints `SMOKE OK` | A02 |
| 6 | Full run on the emulator | Temporarily set the preset's `command_line/extra_args` to `-- --autoplay=greedy --seed=1 --debug-perf`, deploy, wait for `run finished result=` in `adb logcat -s godot`, then **revert the preset**. Save the log | A03, A07, A14 |
| 7 | Manual-path run by input | Drive one run with `adb shell input tap` on START, DEPLOY, an upgrade card, each ability, pause, resume; screenshot after each; confirm no tap can aim or move the Warden | A03, A16 |
| 8 | Save and relaunch | After a finished run: `adb shell am force-stop <pkg>`, relaunch, screenshot the menu: Data total persisted | A15 |
| 9 | Lifecycle | During combat: `adb shell input keyevent KEYCODE_HOME`, wait 10 s, relaunch: paused overlay, state intact; `KEYCODE_BACK` in combat pauses | A13 |
| 10 | Perf soak | `--scenario=hold50 --debug-perf` for 5 minutes: `smoke_android.ps1 -SkipDeploy -Soak 300 -MinFps 20`; record `[PERF]` lines at 10, 28 and 50 enemies | A06, A18 (emulator only) |
| 11 | Offline and permissions | `aapt2 dump permissions`; run steps 6 and 8 with `adb shell svc wifi disable; svc data disable` | A19 |
| 12 | Aspect ratios | `adb shell wm size 1080x2340` then `1080x2400`, screenshot combat; `adb shell wm size reset` | A16 |
| 13 | Evidence | `docs/reports/TEST_REPORT.md`, `PERFORMANCE_REPORT.md`, `KNOWN_ISSUES.md`, `ASSET_LICENSES.csv`, `BUILD_INSTRUCTIONS.md`, screenshots, and the APK SHA-256 (`certutil -hashfile <apk> SHA256`) | A20 |

Reporting rules: A02 and A18 are **PASS (emulator)** at best; "physical device" is **NOT RUN** unless a phone
was connected and used with `-Serial`. Emulator frame rates are not representative of phones and must be
labelled as such. Never leave debug `extra_args` in `export_presets.cfg`. Final `check.ps1` after all fixes.

---

## 6. Placeholder art strategy (from `handoff/06_QA_AND_RELEASE/ASSET_MANIFEST.csv`)

Nothing blocks on external assets. Every item is generated in code or by a project script, uses only palette
materials from `MatLib`, and sits behind an id so an authored asset can replace it later without touching
gameplay. No concept PNG is ever used as a texture, sprite or background.

| Manifest id | Owner | Placeholder (procedural) | Motion (code) | Replace later via |
|---|---|---|---|---|
| `warden_defender` | W1-F | Two merged meshes: legs/hips (gunmetal boxes, wide stance) and torso/arms/head (ceramic plates, cyan visor strip and shoulder light), about 1.9 m tall | Upper-body yaw to aim, recoil kick, reload dip, idle sway | `ActorMeshes.warden_*` |
| `skitter` | W1-F | Low wedge body 0.9 m long, four angled leg boxes, long forelimb prisms, small head with one red emissive slit | Scuttle bob, lateral weave lean | `ActorMeshes.enemy(&"skitter")` |
| `hollow_warden` | W1-F | Upright biped 1.7 m: slab chest plate, broad shoulder boxes, red visor bar | Slow stride bob, attack arm swing | same |
| `rusher` | W1-F | Lean biped 1.4 m pitched forward 25 degrees, swept-back spine prisms with red emissive ridge | Fast bob, forward lean, spark trail quad | same |
| `siege_hulk` | W1-F | 3.4 m hunched brute: huge shoulder blocks, fore-arms as pillars, red chest core sphere, cable cylinders | Heavy stomp with camera-free dust puff, stagger on EMP, slow collapse on death | same |
| `pistol`, `smg` | W1-F | Small box assemblies on the Warden's hand mount; SMG longer with a magazine box; muzzle marker node | Recoil, swap on `weapon_changed` | same |
| `auto_turret` | W1-F | Tripod of three prisms, squat cylinder head, twin barrel boxes, cyan light; hex pad by W1-E | Deploy rise, yaw, recoil | `ActorMeshes.turret()` |
| `relay_core_b4` | W1-E | Caged cylinder: amber emissive column inside eight gunmetal ribs, ring base, cable cylinders, `Label3D` "RELAY CORE B-4" | Pulse; dim and flicker by hp; dark with sparks on defeat | `ArenaView` |
| `industrial_kit` | W1-E | Ground quad with a simple shader or generated texture (seams, puddle roughness, hazard stripes, "B-4"); containers as ribbed boxes (dull red, grey); jersey barriers as extruded prisms with red-white chevrons; crate stacks; drums; gantry legs; pipes; lamp posts with amber heads; additive light-pool quads; optional rain streak quads on HIGH | Lamp flicker, rain scroll | `ArenaView` props keyed by `obstacle.visual` |
| `combat_hud` | W1-G, W2-B | Godot `Control` nodes, `Theme` built in code, Oxanium and Share Tech Mono (OFL), flat SVG icons authored by the agent | Tweens for pulses and sweeps | `UiTheme`, `assets/icons/` |
| `vfx_bundle` | W1-F | Pooled quads and thin boxes with additive unshaded materials: tracers, muzzle star, sparks, debris cubes, EMP ground ring (scaled torus or ring mesh), shield dome (transparent sphere), overdrive glow, floating texts | Scale and fade over fixed lifetimes | `VfxLayer` |
| `audio_bundle` | W2-C | Synthesized WAVs from `tools/audio_gen/gen.py` (noise bursts, filtered sweeps, FM tones) | - | `assets/audio/` by id |

Budgets for placeholders (source of truth `ActorMeshes.TRI_BUDGET`): Skitter at most 450 triangles, Hollow Warden 500,
Rusher 500, Hulk 1,500, turret 600 (W3-D raised these for the hard-surface looks from 300, 400, 400, 900 and 300; the
CURRENT meshes stay far below them), Warden 2,500 (every body part plus the weapon in hand; it went 700 to 2,000 to 2,500 in
W3-C), each as one mesh with at most 3 surfaces (the Warden is 11 mesh instances with at most 3 surfaces each). Arena total at most 25 k triangles.
**The Warden budget is 2,500 now** (it uses 2,448 triangles with the pistol and 2,472 with the SMG); milestone 2 needs room for
long weapons, and SPEC Q4 proposes a body budget of 2,300 plus a separate weapon budget of 350 (the body must lose about 150
triangles, or the budget rises to 2,650). The owner of `ActorMeshes.TRI_BUDGET` decides after a look at the captures; until then
2,500 stands.

Readability rules for all placeholder actors: dark blob shadow, one emissive accent in the faction color,
silhouette differences in height and footprint first, detail second. Faction color is never the only cue.

### 6.1 Milestone 2 additions

New assets, same rules (procedural, hard-surface kit, **palette materials only**: `ceramic`, `dark_frame`, `gunmetal`, `hazard`,
`emit_red` for enemies; `add_cyan`, `add_amber`, `add_red`, `add_white` for effects). The one new material is the red hatch for
danger decals (unshaded, alpha), which must be added to `ShaderWarmup`. Models and sounds per weapon: GDD 12.5.

| Asset | Owner | Triangle budget | Note |
|---|---|---:|---|
| 8 new weapons (`scattergun`, `assault_rifle`, `hornet_rack`, `lmg`, `slag_mortar`, `cutting_torch`, `arc_projector`, `rail_lance`) | V2-F (arc projector), V4-R (the other seven) | 350 each | The Warden budget becomes body 2,300 + weapon in hand 350 only if the owner of `TRI_BUDGET` decides so (SPEC Q4) |
| Holstered weapon on the pack | V4-R | reuses the weapon mesh | MID and HIGH only |
| `mote`, `shard` | V2-F (mote), V4-R (shard) | 40 each | One mesh, 2 surfaces (ceramic, `emit_red`), drawn as a transform-only MultiMesh (40 instances each) |
| `burster`, `spitter`, `borer`, `jammer` | V2-F (burster), V4-R (the rest) | 400 each | One mesh, 3 surfaces, pooled like today's enemies |
| `splitter`, `shieldbearer`, `reclaimer` | V4-R | 500 each | Same |
| `ward_pylon` | V4-R | 150 | Orbits the Aegis Array |
| 4 new bosses (`brood_carrier`, `lance_platform`, `aegis_array`, `tremor_rig`) | V4-R | 900 each (SPEC 12.2) | The Hulk's budget when the spec was written; `TRI_BUDGET` has since raised the Hulk to 1,500 (W3-D), so V4-R fixes the budget of the new bosses with the owner of `TRI_BUDGET`; one pooled node each |
| Crate (with its ring), freight car, fuel drum, strike beacon | V2-F (crate), V4-X (the rest) | 200, 600, 80, 100 | Arena props; the rail lines are faint ground marks |
| About 20 tag, rarity and category icons and 10 weapon silhouettes | V2-E, V4-U | - | SVG, 128x128; the 60 directive icons are not hand-authored (8 tag glyphs x 4 rarity frames plus a category corner mark) |
| 60 new sound ids | V2-G (14 for the slice), V4-A (the rest) | - | `tools/audio_gen/voices.py` recipes, deterministic; `gen.py --check` stays byte-identical |

Readability rules of the new content (tests, not prose): one red optic per enemy and nothing else on an enemy glows; every
damage zone that hurts the player's side is a red hatched ground decal, every zone that hurts enemies is cyan or amber with no
hatch; at most 3 ticker lines and 1 banner; no damage numbers; a flash over 5% of the screen lasts at most 0.25 s (GDD 6.7, 12.3).

---

## 7. Acceptance matrix coverage

| ID | Requirement (handoff) | Covered by |
|---|---|---|
| A01 | Project imports | W0-S; every task's `check.ps1`; W4-A step 1 |
| A02 | Offline debug APK launches portrait | W1-H, W4-A steps 4, 5 (emulator); physical device NOT RUN unless a phone is attached |
| A03 | Warden fixed, auto-targets, no manual aim | W1-B tests; W3-A; W4-A step 7 |
| A04 | High top-down 55 to 65 degrees, continuous arena | W1-E `CameraFit` tests and captures; W3-B |
| A05 | Spawn right/top-right, navigate to core | W1-A tests; W2-E debug overlay capture |
| A06 | 50 alive supported, queue preserves all | W1-A cap tests; W2-D stress; W4-A step 10 |
| A07 | Five waves and boss complete correctly | W1-C phases; W2-D integration; W3-A end to end; W4-A step 6 |
| A08 | Four archetypes behave distinctly | W1-A archetype tests; W1-F silhouette tests and capture |
| A09 | Scrap exactly once per kill | W0-S `kill_enemy` test; W1-B; W2-D sum check |
| A10 | Pistol to SMG, damage/rate/piercing purchases | W1-C economy tests; W1-B cadence and damage tests; W3-A |
| A11 | Two turrets, no third | W1-C boundary test; W1-B turret tests |
| A12 | EMP, shield, overdrive timing and effects | W1-C fixed-tick tests; W1-B shield and overdrive effects |
| A13 | Pause freezes simulation and cooldowns | W2-A tests; W3-A; W4-A step 9 |
| A14 | Core 0 defeats; wave 5 clear wins | W1-C; W2-D; W2-A integration |
| A15 | Rewards persist once; corrupt backup recoverable | W1-D; W2-A; W3-A relaunch test; W4-A step 8 |
| A16 | Safe area, 48 dp targets, legible text | W1-G and W2-B tests and captures; W3-B; W4-A steps 7, 12 |
| A17 | Color and material consistency | W1-E, W1-F, W2-E captures; W3-B review (owner approval still required) |
| A18 | FPS measured on physical Android with 50 enemies | W4-A step 10 on the emulator only; physical device NOT RUN |
| A19 | No network, ads, accounts, IAP, extra permissions | W1-H and W4-A permission dumps; offline run in step 11 |
| A20 | Source, scripts, tests, licenses, APK, logs delivered | W3-B `ASSET_LICENSES.csv`; W4-A step 13 |

**Milestone 2 rows (B01 to B12).** The A rows above are the handoff's matrix. After the variety milestone the five-wave behaviour
of A07 (five waves and boss complete), A10 (pistol to SMG, purchases) and A14 (wave 5 clear wins) is covered on the legacy
fixture (SPEC 13.9); the shipped game's equivalents are B01 to B03 and the 15-wave end-to-end suites of V3-I and V5-A.

| ID | Requirement | Covered by |
|---|---|---|
| B01 | **Run plan determinism.** The plan (bosses, both options of every wave, events) is a pure function of the seed; it is identical for the same seed and differs for another; a decision at wave 3 does not change the options of wave 7; thinking time does not change the hash (a bot waiting 0 or 600 calls); replay equality holds with drafts and awaits | V2-A tests (`sim_plan`, `sim_flow`); V2-H `plan_dump`; V3-I and V5-A end-to-end suites |
| B02 | **Drafts.** 1-of-3 offers are seeded, weighted, duplicate-free, with pity, reroll, skip, buy-out and patch; the three stat directives reproduce the golden `hit_damage` values | V2-B tests (`sim_draft`); V4-C (every directive, packs, modifiers, kits); V2-E and V4-U UI tests |
| B03 | **Two weapons and swap.** Two slots, per-slot magazines and heat, swap timing, holster reload; the firing kinds hit exactly the expected sets | V2-C tests (`sim_arsenal`); V4-W (the other seven weapons, levels); V2-E weapon bar |
| B04 | **Each enemy type is distinct.** One behaviour test per type (GDD 6.3); pairwise silhouettes, one optic per mesh, size classes far apart | V4-N tests (`sim_enemies`, `sim_nav`); V4-R view tests and roster capture |
| B05 | **Elites.** One test per affix and the forbidden pairs; an elite is readable by behaviour and one ground cue | V4-N tests; V4-X captures |
| B06 | **Bosses.** Per boss a timeline test over its first 60 s; interrupt and brace rules; no attack above 20% of the core; pools and variants come from the plan | V4-L tests (`sim_boss`); V4-R models; V4-X telegraphs |
| B07 | **Events fairness.** Every fairness rule of GDD 7b is a test; the interaction table row by row; every event warns first | V4-V tests (`sim_events`); V4-X captures |
| B08 | **Resume.** Snapshot, restore and hash equality at each boundary for 3 seeds; tail replay lands on the same hash; hash mismatch falls back to full replay; reward once across resumes; 100 kill-and-resume cycles in memory; resume after `am force-stop` mid-wave and mid-draft on the device | V2-D tests (`game`, `save`, `integration/game`); V6-Q on the device |
| B09 | **Profile migration.** v1 to v2 on the fixture files (plain, `.bak` only, corrupt, newer schema); v1 files left untouched; Data kept, nothing unlocked for free | V4-M tests (`save`); V6-Q on the device |
| B10 | **Unlocks once.** Purchases are atomic (tier gate, not owned, funds); milestones are claimed once; a run is rewarded once; the Daily seed is the same for a date and differs across dates | V4-M tests (`save`, `game`); V2-D reward-once across resumes |
| B11 | **Scorecard PASS.** `scorecard_run.ps1 -Runs 200 -Pool base` and `-Pool full` print `SCORECARD: PASS` (or WARN rows each explained); `balance_run.ps1 -Runs 20` prints `BALANCE: PASS`; the legacy fixture still passes `BALANCE: PASS` | V4-T tool and tests; V5-C balance; V1-S legacy check |
| B12 | **Phone frame budget at 50 + 40.** `--scenario=hold50+40` and `--scenario=chain` on the phone stay within the budget of ARCH 13.2 (go or no-go and the cut list in `PERFORMANCE_REPORT.md`); a 15-minute soak per tier with `[PERF]` lines; anything not run on the device is **NOT RUN** | V2-P (first, before content is built); V4-X (and V4-X2 only if no-go); V6-Q soak |

Test plan coverage: "Unit" rows map to W0-S, W1-A to W1-D and W2-A; "Integration" to W2-D, W2-A, W3-A;
"Stress" to W2-D; "On-device" to W4-A (emulator), with thermal and physical-device items NOT RUN.

---

## 8. Milestone 2: Variety - conventions, shared files and task cards

Design: `docs/design/VARIETY_PITCH.md`, `VARIETY_SPEC.md` (cited as SPEC n) and `VARIETY_CONTENT.md` (CONTENT n); contracts:
ARCH (marked **(V)**); rules and numbers: GDD. Every number in them is a first-pass value that the balance task (V5-C) confirms
with deterministic runs. "Read" below is always: SPEC, CONTENT, ARCH, GDD, plus the sections named. The overview table, the
totals, the critical path and the cut order are in 2.1.

### 8.1 Conventions

- Every task ends with `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two-wt\<ID>\tools\check.ps1` exiting 0
  with last line `CHECK OK`. The commands in the Acceptance tables below are the **additional**, task-specific checks, written
  without the common prefix `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two-wt\<ID>\` (so
  `tools\test.ps1 -Path res://tests/unit/sim_plan` means `powershell -NoProfile -ExecutionPolicy Bypass -File
  C:\dev\tower-two-wt\<ID>\tools\test.ps1 -Path res://tests/unit/sim_plan`). A check passes only when the command exits 0 and
  prints the stated last line (rule 4).
- From a Git Bash shell write `-Out` paths with forward slashes (the captures below do).
- Each task is one worktree `C:\dev\tower-two-wt\<ID>\`, branch `task/<ID>`; the coordinator merges and runs `check.ps1` on
  `main` before the next wave.
- Tests of variety behaviour use `TestContent.variety()` (rule 5). Hours are estimates.
- Same-wave tasks share a few system files in wave V4: `hazard_system.gd` is V4-V's, `status_system.gd` is V4-N's,
  `mod_system.gd` and the hook files (`death_hooks.gd`, `core_hooks.gd`) are V4-C's, `arsenal_system.gd` and `shot_hooks.gd` are
  V4-W's. The scaffold's stubs define the call points; a task that needs a new call point in another task's file reports it
  ("needs owner") instead of editing. `class_name` uniqueness for test helpers stays a rule (the Wave 1 merge lesson in
  `CLAUDE.md`).

### 8.2 Shared files that need a single owner

These files are touched by many features. They are extended **once, by V1-S**, as complete contracts; later tasks fill bodies in
their own files and must not edit these (a needed change is reported as "needs owner" and done by the coordinator between
waves).

| File | Why it is shared |
|---|---|
| `src/shared/{ids,reason,damage_source}.gd` | Ids and enums for every layer |
| `src/content/defs/**`, `src/content/content_loader.gd`, `content_validator.gd` | Every data file |
| `src/sim/sim_world.gd`, `sim_command.gd`, `sim_event_kind.gd`, `sim_config.gd`, `run_stats.gd`, `run_summary.gd` | Tick order, commands, events |
| `src/core/event_bus.gd`, `src/game/run_api.gd`, `src/game/game_event_relay.gd`, `src/debug/fake_run_api.gd` | The door between sim, UI, view and audio |
| `tests/unit/core/test_contracts.gd`, `tests/fixtures/test_content.gd` | Contract tests, fixtures |
| `data/strings/variety_en.json` | V2-E in wave V2, V4-U in wave V4 (one owner per wave; other tasks list the keys they need in their report) |
| `data/run.json`, `data/enemies.json`, `data/weapons.json`, `data/directives.json`, `data/events.json` | One owner per wave as in 2.1 (V4-C owns `run.json` and `directives.json`, V4-N `enemies.json` and `arena.json`, V4-W `weapons.json`, V4-V `events.json`); V5-C owns all values afterwards |
| `src/audio/audio_catalog.gd`, `tools/audio_gen/voices.py` | The audio task of each wave |
| `src/view/vfx/vfx_layer.gd`, `src/view/actors/actor_layer.gd`, `enemy_pool.gd` | V2-F, then V4-X (vfx) and V4-R (actors) |
| `src/ui/combat/combat_hud.gd` | V2-E, then V4-U |
| `project.godot`, `export_presets.cfg` | Nobody (no change is needed: `data/*.json` is already included) |

### 8.3 The vertical slice comes first (waves V1 to V3)

The slice is the whole loop with one of each, playable on the phone:

| Pillar | In the slice |
|---|---|
| Run | Act I only: 4 generated waves and a boss wave (the existing Siege Hulk stands in as the act boss), untimed intermissions |
| Draft | The draft overlay with 8 directives: `hot_loads`, `cyclic_tuning`, `penetrator_cores`, `turret_deploy`, `reinforced_cage`, `emp_capacitor`, `incendiary_tips`, `glass_cannon` (one corrupted, to test the red frame) |
| Weapon | `arc_projector` (it proves chains, heat, a new effect and a new sound), found in the guaranteed crate after wave 2; 2 slots; the weapon bar and swapping |
| Enemy | `burster` (it proves death hooks and chain blasts) and `mote` (it proves minis and the instanced path) |
| Modifier | Route choice before waves 2 to 4 with 3 packs (`pack_tide`, `pack_powder`, `pack_column`) and one modifier (`mod_volatile`) |
| Event | Player-triggered `deadfall_strike` only (it proves delayed hits, telegraphs and the call button) |
| Resume | The run file and RESUME RUN |
| Meta | None yet (Data is still granted as today) |

Slice exit (V3-I acceptance): a `balanced` bot and a human finish a 5-wave run on the desktop and on the phone; two seeds give
visibly different runs (different packs, offers and outcomes); kill the app mid-wave and resume; `sim_run` over 20 seeds shows
wins and losses.

**Status (2026-11-12):** met on the desktop. The `balanced` bot wins 6 of 20 seeds (13 of the 14 defeats are in the boss wave),
two seeds differ in packs, offers and outcomes, kill and resume works in process and through `Game`, and the debug APK exports.
The phone, the emulator and a real OS-process kill and relaunch are NOT RUN; the owner playtest on the phone is the gate.

**Status (2026-11-13), wave V4 done.** All eleven V4 tasks are merged (`main` c5092bb, `check.ps1` green with 3,042 tests). With
the whole content in, the `balanced` bot won **19 of 20** seeds of the 5-wave slice (the scorecard of that build: WARN, 7
pass, 12 warn, 0 fail; the run was 171 s long because it had five waves). The owner played that build on a phone and
approved the 15-wave integration.

**Status (2026-11-13), V5-A: the 15-wave game.** `data/run.json` holds the 15 waves of CONTENT 1.1 (three acts, bosses at 5, 10
and 15 from the act pools), `data/unlocks.json` the whole Archive (24 unlocks), the sim counts the Recovered Data table of
CONTENT 10, and the upgrade drawer is gone. First measurement on the first-pass numbers (nothing tuned):
`tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` gives 10 victories and 10 defeats (the defeats: 1 in wave 5, 3 in wave 6,
5 in wave 10, 1 in wave 15); a win lasts 574 to 669 s in all, about 560 s of combat, which is short of the 780 to 1,020 s of
scorecard S16. Tuning is V5-C's task (values only). The whole-run suites pin the structure with a debug build (every
unlock, damage x4) for the victory and the `none` bot for the defeat, so they do not move when the numbers are tuned.

**V3-I carry-overs.** V4-U: draft, route and corrupted hints on the choice screens; the empty band (about 140 px at 1080x2400)
between the battlefield and the weapon bar; the combat HUD ghosting through the overlay header; a truncated weapon list on the
draft build button; the wrapped pistol stat line in the salvage card; the boss ANSWER line may only name answers the run can have.
V4-N: `SpawnSystem.begin_wave` uses an insertion sort (0.45 s for a 3,000-entry stress wave, fine for real waves); the elite
stub system gets elites in waves 3 and 4 of seed 1 although elites are outside the slice. V4-X: death blasts of volatile
skitters are small at the arena edge; motes are small at phone size.

### 8.4 Wave V1

#### V1-S Contract scaffold

**Goal.** Every contract of ARCH marked **(V)** exists as compiling code and data, so nine tasks can start in parallel.
**Owned.** The whole repository, but functional changes only in the files of 8.2; everything else is new stubs.
**Read.** SPEC 13 (all), 15.4; ARCH 3.1, 4, 5, 6, 7, 12; CONTENT 1 to 13 (the data it transcribes for the slice).
**Deliverables.**
1. Shared and frozen files extended exactly as ARCH describes (SPEC 13.1 to 13.4; append only).
2. Every new def, state class, system, hook file, fire kind, event and boss file as a stub with the final signature,
   `hash_into`, `to_dict`, `from_dict`, marked `# TODO(<task id>)`.
3. `ContentLoader.build` with the 7th parameter; loaders for the six new files (straight mapping).
4. Slice data in `data/` (8.3) and the full schemas with at least one entry per list.
5. `TestContent.variety()` and `tests/fixtures/data_variety/` (slice data).
6. `FakeRunApi` and `SimPuppet` extended; `hud_sandbox.tscn` gains `--state=draft|route|salvage|combat2` and `view_sandbox.tscn`
   gains `--scenario=chain` and `hold<N>+<M>` (driven by the puppet), so V2-E and V2-F can capture without waiting for V2-P,
   which owns `src/debug/` afterwards.
7. `test_contracts.gd` extended.
8. `mission.shop_enabled` false in shipped data; the game still boots and a run still plays as 5 scripted waves until V2-A
   lands (the plan stub returns the legacy waves).

**Tests.** Loader tests for each new file; contract test; "legacy fixture content is byte-for-byte the same `ContentSet` as
before" (compare a hash of the defs); every existing test still green.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Full gate | `tools\check.ps1` -> `CHECK OK` with at least the current 1,063 tests plus 40 new | A01 |
| Contracts and content | `tools\test.ps1 -Path res://tests/unit/core,res://tests/unit/content` passes | - |
| The wrapper detects failures | `tools\test.ps1 -Canary` -> `CANARY OK` | A20 |
| The legacy fixture is intact | `tools\balance_run.ps1 -Runs 5 -Data res://tests/fixtures/data_baseline` still prints `BALANCE: PASS` | A07, B11 |

### 8.5 Wave V2 (nine tasks in parallel; all depend on V1-S)

Every Wave V2 task ends with `check.ps1` exiting 0 with `CHECK OK`.

#### V2-A Sim: run plan, wave builder, phases and awaits

**Goal.** A run is a generated plan; intermissions wait for choices; the sim holds its tick while waiting.
**Owned.** `src/sim/plan/`, `src/sim/systems/{run_plan_system,wave_builder,phase_system,phase_state,spawn_system}.gd`,
`tests/unit/sim_plan/`.
**Read.** SPEC 2.5, 5.3 to 5.5, 9, 13.2; CONTENT 1, 4.1; ARCH 4.1, 6.1, 6.2, 6.6; GDD 7.
**Deliverables.** `RunPlanSystem.build`, `WaveBuilder`, the `Await` flow of ARCH 4.1, `PICK_ROUTE`, acts, `ACT_STARTED`,
`ROUTE_OFFERED`; `SpawnSystem` reads the chosen option and enforces the class and type caps.
**Tests (`tests/unit/sim_plan/`, at least 30).** The plan is identical for the same seed and differs for another; golden plan for
seeds 1 to 3; both options of a wave never share a pack; budgets are met within 10%; composition rules (GDD 6.5); a pick at
wave 3 does not change wave 7's options; awaiting freezes `tick` and every timer; a bot answering after 0 or 600 calls gives the
same hash; caps and FIFO queue with minis; legacy fixture runs unchanged.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Plan, flow and nav tests | `tools\test.ps1 -Path res://tests/unit/sim_plan,res://tests/unit/sim_flow,res://tests/unit/sim_nav` passes | B01 |

#### V2-B Sim: drafts, directives, modifiers

**Goal.** 1-of-3 offers that are seeded, weighted, duplicate-free, with pity, reroll, skip, buy-out and patch.
**Owned.** `src/sim/systems/{draft_system,mod_system,command_system,economy_system}.gd`, `src/sim/stores/{draft_state,mod_state}.gd`,
`tests/unit/sim_draft/`.
**Read.** SPEC 4, 13.2; CONTENT 3; ARCH 6.5, 6.6; GDD 5.2.
**Deliverables.** `DraftSystem`, `DraftState`, `ModSystem`, `ModState`, the `ops` interpreter, the 5 draft commands,
`SHOP_CLOSED`, the legacy level fields fed by the three stat directives.
**Tests (`tests/unit/sim_draft/`, at least 35).** No duplicates over 1,000 offers; rarity frequencies within 3 points of the
weights over 5,000 offers; rare pity fires on the 4th offer; turret pity; requirement filtering; tag lean changes frequencies in
the expected direction; reroll prices 60, 100, 140; buy-out once per draft; skip pays 60; maxed directives never appear; every op
changes exactly its `ModState` field; `hot_loads` x3 gives the golden `hit_damage` values of ARCH 6.5; golden first offer of
seed 1; replay equality with drafts.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Draft and flow tests | `tools\test.ps1 -Path res://tests/unit/sim_draft,res://tests/unit/sim_flow` passes | B02 |

#### V2-C Sim: arsenal, arc projector, blasts, burster, salvage

**Goal.** Two weapon slots, swapping, heat, chain lightning, delayed and area damage, death blasts with a chain delay, crates.
**Owned.** `src/sim/systems/{arsenal_system,weapon_system,damage_resolver,area_damage,hazard_system,status_system,death_hooks,salvage_system,core_attack_system}.gd`,
`src/sim/systems/fire/{fire_hitscan,fire_arc}.gd`, `src/sim/stores/{arsenal_state,hazard_state,enemy_ext_state,salvage_state}.gd`,
`tests/unit/sim_arsenal/`; and `src/sim/systems/events/event_deadfall_strike.gd` (V1-S's stub, filled here).
**Read.** SPEC 3, 5.1 (burster), 7.1 (Deadfall Strike), 9.5, 13.2; CONTENT 2, 4.2, 6, 7; ARCH 6.5, 6.6; GDD 5.1, 5.5.
**Deliverables.** As the owned files; `DamageResolver.hit_ex`; `DeathHooks.on_killed`; the 8-per-tick blast limit;
`deadfall_strike` as the first user of delayed hits.
**Tests (`tests/unit/sim_arsenal/`, at least 40).** Swap timing and per-slot magazines; holster reload at half speed; heat and
vent exact tick counts; arc chain order (nearest, id ties), falloff values, armor ignored; a line of 6 bursters detonates in
6-tick steps and kills exactly the expected set; blasts never recurse; Scrap exactly once per kill by a blast; a burster at its
slot arms and hits the core for 70 (shield first); minis burn out with no Scrap; crate progress, contest, loss, bank limit;
`SALVAGE` actions; the legacy pistol and SMG cadence tests unchanged; determinism over 3,600 ticks with 50 + 40; micro-benchmark:
the tick with 50 + 40 and a blast per second averages under 1.0 ms on the dev machine.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Arsenal and combat tests | `tools\test.ps1 -Path res://tests/unit/sim_arsenal,res://tests/unit/sim_combat` passes | B03 |

#### V2-D Game flow, run file, resume

**Goal.** The app drives the new intermission, writes the run file, resumes after a kill.
**Owned.** `src/game/**`, `src/core/game.gd`, `src/save/**`, `tests/unit/{game,save}/`, `tests/integration/game/`,
`tests/fixtures/saves/`.
**Read.** SPEC 2.8, 8.4, 13.3, 13.4; ARCH 6.7, 7; GDD 3, 8.2.
**Deliverables.** `SimRunApi` additions, `GameEventRelay` additions, run file read and write, `start_resumed`, RESUME RUN wiring
(the menu button itself is V2-E's stub signal), boundary snapshot calls, the fallback chain of ARCH 6.7.
**Tests.** Snapshot, restore, hash equal at each boundary (3 seeds); tail replay lands on the same hash; hash mismatch falls
back to full replay; wrong build closes the run and pays once; reward-once across resumes; app-pause writes `resume_tick`; 100
kill-and-resume cycles in memory.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Game, save and integration tests | `tools\test.ps1 -Path res://tests/unit/game,res://tests/unit/save,res://tests/integration/game` passes | B08, B10 |

#### V2-E UI: draft, route and salvage overlays, weapon bar

**Goal.** The three choice screens and the new bottom band, built against `FakeRunApi`.
**Owned.** `src/ui/run/**`, `src/ui/combat/**`, `assets/icons/`, `data/strings/variety_en.json`, `tests/unit/ui/`.
**Read.** SPEC 11.1 to 11.4, 13.5; ARCH 9; GDD 9, 10.1, 10.5.
**Deliverables.** The draft, route, salvage and boss-briefing screens and the combat HUD of GDD 10.1 and 10.5 (ticker and call
button in their first form), two-tap confirm, long-press detail, safe areas, the drawer hidden (not deleted).
**Tests.** Touch sizes at least 132 px for every control at 1080x1920, 1080x2400 and 1080x1120; text at least 30 px; a
selection never commits without CONFIRM; the right command and argument reach the API for every button; corrupted cards show the
price line; High Contrast variants.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| UI tests | `tools\test.ps1 -Path res://tests/unit/ui` passes | B02, B03, A16 |
| Draft screen | `tools\capture.ps1 -Scene "res://src/debug/hud_sandbox.tscn --state=draft" -Out C:/dev/tower-two-wt/V2-E/build/shots/draft.png -Size 1080x2400` prints `CAPTURE OK`; also `--state=route`, `--state=salvage`, `--state=combat2`; each PNG opened and listed in the report | A16, A17 |

#### V2-F View: arc projector, burster, minis, blast and arc effects

**Goal.** The first new models and effects, at the readability and budget rules.
**Owned.** `src/view/**` except `battle_view.gd`, `tests/unit/view/`.
**Read.** SPEC 5.6, 10.2 to 10.4, 12.2, 12.3, 13.6; ARCH 8, 13.2; GDD 6.7, 12.3 to 12.5.
**Deliverables.** The two models (arc projector, burster), `MiniSwarm`, `fx_blasts`, `fx_arcs`, the telegraph ring for the
strike, the crate and its ring, pools sized by tier, data-driven `EnemyPool` sizes.
**Tests.** Triangle budgets; one optic material surface per enemy mesh; pool caps by tier; no allocation after `setup` (a
counter test as in the existing vfx tests); a blast never draws on a recycled slot twice in a frame.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| View tests | `tools\test.ps1 -Path res://tests/unit/view` passes | B04 |
| Chain capture | `tools\capture.ps1 -Scene "res://src/debug/view_sandbox.tscn --scenario=chain" -Out C:/dev/tower-two-wt/V2-F/build/shots/chain.png -Size 1080x2400` prints `CAPTURE OK`; the capture shows countable optics during the chain | A17, B12 |

#### V2-G Audio: slice sounds and voice classes

**Goal.** The sounds the slice needs, and the voice rules that keep a warning audible in a chain blast.
**Owned.** `src/audio/**`, `tools/audio_gen/**`, `assets/audio/**`, `tests/unit/audio/`.
**Read.** SPEC 12.1, 10.5, 13.7; ARCH 10; GDD 11.
**Deliverables.** 14 slice sounds (14 of the 60 new ids of ARCH 10, chosen to cover the slice of 8.3; list them in the report);
the voice classes and limits (3 voices reserved for alerts, the weapon class at most 8, the big-blast substitution); held voices
(`AudioDirector.hold`, `release`); `AudioEventRouter` for the new signals the slice raises; `AudioLoopPad` for every new loop.
**Tests.** Every new id in the catalog has a file; alert voices are never starved (a test that floods weapon sounds); a held
voice starts and stops with its slot; the generator is byte-identical on a second run.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Generator is deterministic | `py -3.12 -I C:\dev\tower-two-wt\V2-G\tools\audio_gen\gen.py --check` exits 0 | A20 |
| Audio tests | `tools\test.ps1 -Path res://tests/unit/audio` passes | - |

#### V2-H Bots and tools for drafts

**Goal.** Deterministic bots that answer every choice, and the tools to run and inspect a seed.
**Owned.** `src/sim/ai/**`, `tools/{sim_run,balance_run,plan_dump}.*`, `tests/unit/sim_ai/`.
**Read.** SPEC 14.1, 13.8; CONTENT 13; ARCH 6.7, 12; GDD 8.4.
**Deliverables.** Policies `none`, `greedy`, `random`, `balanced` (slice scope: draft, route, salvage, weapons), `plan_dump`;
`sim_run` accepts a policy and prints the build signature and the death wave.
**Tests.** Each policy is deterministic and never draws from a sim stream; every await is answered on the next tick; the
`random` bot's RNG is seeded outside the world.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Runs | `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` prints `SIM SUMMARY:` with both victories and defeats possible | B01, B11 |
| Plan | `tools\plan_dump.ps1 -Seed 1` prints the plan | B01 |

#### V2-P Phone baseline and mini stress (uses the physical device)

**Goal.** Know before the content is built whether the phone holds the effect budget at 50 + 40.
**Owned.** `src/debug/**`, `docs/reports/PERFORMANCE_REPORT.md`. **Uses the physical device** (rule 9; the only task of the
wave that may).
**Read.** SPEC 10; ARCH 13.1, 13.2; `docs/reports/PHONE_PERF.md` and its "How to repeat"; `docs/reports/BUILD_INSTRUCTIONS.md`.
**Deliverables.** `PERFORMANCE_REPORT.md` records the baseline at 50 enemies for LOW, MID and HIGH (measured 2026-11-11 in
`PHONE_PERF.md`: LOW 60 fps, MID and HIGH about 56 fps, 137 draw calls and 40.6k primitives on HIGH; copy the three tier rows
and re-measure them if the build changed); then `--scenario=hold50+40` and `--scenario=chain` on the phone with `--debug-perf`:
six `[PERF]` lines per tier, flags set through `user://cinderfall_args.txt` (ARCH 11). Output: a go or no-go on the budget of
ARCH 13.2 (about 165 draw calls on HIGH against the 150 target and the 220 limit) and the cut list if no-go (ghost swarm,
scorch marks, flashes, tether lines, then V4-X2).
**Tests.** None beyond `check.ps1`; the evidence is the report. Anything not run on the device is reported **NOT RUN**.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Baseline recorded | `docs/reports/PERFORMANCE_REPORT.md` has the LOW, MID and HIGH rows at 50 enemies | A18, B12 |
| Mini stress | `--scenario=hold50+40 --debug-perf --quality=0`, `=1`, `=2` on the phone: six `[PERF]` lines per tier | B12 |
| Chain | `--scenario=chain --debug-perf` likewise | B12 |
| Decision | a go or no-go on the ARCH 13.2 budget, with the cut list if no-go | B12 |

### 8.6 Wave V3

#### V3-I Slice integration

**Goal.** The slice of 8.3 plays end to end on desktop and phone.
**Owned.** `src/**`, `data/**`, `tests/**` (fixes only), `tests/fixtures/data_variety/`. Device checks use the emulator or, when
the coordinator attaches it, the phone (`-Serial`); a device check that was not run is reported **NOT RUN**.
**Read.** SPEC 15.2; all Wave V2 reports ("needs owner" lists); `docs/reports/PHONE_PERF.md`.
**Deliverables.** Fixes across layers, the e2e suite for the 5-wave generated run, the frozen `data_variety` fixture (the first
complete variety data set), a debug APK for the owner.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Full gate | `tools\check.ps1` -> `CHECK OK` | A01 |
| Wins and losses | `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` shows at least 1 victory and 1 defeat | B01 |
| Integration | `tools\test.ps1 -Path res://tests/integration` passes | B01, B08 |
| The real process | `Godot --headless --fixed-fps 60 --path . -- --autoplay=balanced --seed=1 --mute --quit-after-run` ends with `[Game] quit after run` | A07 |
| Device | `tools\deploy_android.ps1` and `tools\smoke_android.ps1 -SkipDeploy` -> `SMOKE OK` (V3-I: NOT RUN, no device) | A02 |

**Gate: owner playtest** ("is the loop fun?"; short form in GDD 8.4).

### 8.7 Wave V4 (eleven tasks in parallel; each ends with `check.ps1`)

#### V4-W Sim: the other 7 weapons and weapon levels

**Goal.** The whole arsenal of ten weapons, levels 1 to 3.
**Owned.** `src/sim/systems/fire/{fire_cone,fire_line,fire_shell,fire_missiles,fire_beam}.gd`,
`src/sim/systems/{arsenal_system,shot_hooks}.gd`, `data/weapons.json`, `tests/unit/sim_arsenal/`.
**Read.** SPEC 3 (all), 13.2; CONTENT 2; ARCH 6.6 (V); GDD 5.1.
**Deliverables.** The firing kinds cone, line, shell, missiles and beam (one file each); the scattergun, assault rifle, hornet
rack, LMG, slag mortar, cutting torch and rail lance with their special fields and the values of `weapons.json`; weapon levels 1
to 3 and the level-3 perks; `ShotHooks` for the weapon directives that hook shots; cluster targeting (`Targeting.pick_cluster`,
`pick_many`) for the shell and missile kinds. A change needed in `fire_hitscan.gd` is "needs owner".
**Tests.** Per firing kind: exact hit sets on hand-placed enemies; cadence, magazine, heat; level multipliers; level-3 perks;
cluster targeting ties.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Arsenal tests | `tools\test.ps1 -Path res://tests/unit/sim_arsenal` passes | B03 |

#### V4-N Sim: the other 8 enemy types, elites

**Goal.** Every enemy type behaves as its row of GDD 6.3, and elites carry affixes.
**Owned.** `src/sim/systems/{status_system,elite_system,movement_system,core_attack_system,targeting}.gd`, `src/sim/nav/**`,
`data/{enemies,arena}.json`, `tests/unit/sim_enemies/`, `tests/unit/sim_nav/`.
**Read.** SPEC 5 (all), 13.2; CONTENT 4; ARCH 6.6 (V); GDD 6.
**Deliverables.** `spitter`, `splitter`, `shard`, `shieldbearer`, `reclaimer`, `jammer`, `borer` and `ward_pylon`; the ten
affixes and their combination rules; standoff points, breach spawns, ward maths, the mini rule and the MAGNETIC and SHROUDED
effects in `Targeting`; the values of `enemies.json` and the `arena.json` schema 2 points.
**Tests.** Per type one behaviour test per row of GDD 6.3; standoff points never overlap slots; ward maths with exact numbers;
splitter with a full mini cap queues shards; affix tests one per affix and the forbidden pairs; mini movement cost benchmark.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Enemy and nav tests | `tools\test.ps1 -Path res://tests/unit/sim_enemies,res://tests/unit/sim_nav` passes | B04, B05 |

#### V4-L Sim: bosses

**Goal.** The five bosses, their telegraphs and counterplay.
**Owned.** `src/sim/systems/boss_system.gd`, `src/sim/systems/bosses/**`, `src/sim/stores/boss_state.gd`, `tests/unit/sim_boss/`.
**Read.** SPEC 6, 13.2; CONTENT 5; ARCH 6.4, 6.6 (V); GDD 7a.
**Deliverables.** `BossSystem` and one script per boss (`brood_carrier`, `lance_platform`, `aegis_array`, `tremor_rig`,
`siege_hulk` with its three variants), phase pips and telegraph events, escorts, boss pools and variants taken from the plan.
**Tests.** Per boss a timeline test over its first 60 s (telegraph ticks, attack ticks, phase thresholds); interrupt and brace
rules; no attack above 20% of the core; boss pools and variants from the plan.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Boss tests | `tools\test.ps1 -Path res://tests/unit/sim_boss` passes | B06 |

#### V4-V Sim: events and hazards

**Goal.** Ten telegraphed events and the fuel drums, under the fairness rules.
**Owned.** `src/sim/systems/{event_system,hazard_system,ability_system,turret_system}.gd`, `src/sim/systems/events/**`,
`src/sim/stores/event_state.gd`, `data/events.json`, `tests/unit/sim_events/`.
**Read.** SPEC 7 (all), 13.2; CONTENT 6; ARCH 6.6 (V); GDD 7b.
**Deliverables.** `EventSystem` and the ten event files (the player calls Core Vent and Freight; the world events), the fuel
drums, the schedule and mercy rules, the Static Front lock and cooldown rates in `AbilitySystem`, offline timers and rate
multipliers in `TurretSystem`.
**Tests.** Per event: warn, start, end ticks; every fairness rule of GDD 7b as a test; the interaction table row by row; drums
chain with bursters.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Event and flow tests | `tools\test.ps1 -Path res://tests/unit/sim_events,res://tests/unit/sim_flow` passes | B07 |

#### V4-C Sim: the other 52 directives, packs, modifiers, kits

**Goal.** All 60 directives, the packs, modifiers, rewards and kits.
**Owned.** `src/sim/systems/{mod_system,draft_system,death_hooks,core_hooks,wave_builder,run_plan_system}.gd`,
`data/{directives,run}.json`, `tests/unit/sim_draft/`, `tests/unit/sim_plan/`.
**Read.** SPEC 4, 9.3, 13.1; CONTENT 1, 3, 11; ARCH 5.2, 6.6 (V); GDD 5.2, 7.2, 7.3.
**Deliverables.** The directives of GDD 5.2 beyond the 8 of the slice (the 34 pure-data ones and the HOOK ones), the packs,
modifiers, route rewards and kits, the plan patches of `chorus_handshake`, `static_pact` and `open_gate`, and the validator
rules with their bad fixtures.
**Tests.** Every directive: one test of its effect with numbers; every modifier and reward; kits; plan patches reproducible; the
validator rejects each bad fixture.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Directive, plan and content tests | `tools\test.ps1 -Path res://tests/unit/sim_draft,res://tests/unit/sim_plan,res://tests/unit/content` passes | B02 |

#### V4-M Save v2, unlocks, rewards, daily seed

**Goal.** The Archive's rules: profile v2, atomic unlocks, milestones, the Daily seed.
**Owned.** `src/save/**`, `src/game/{game_rewards,game_launch}.gd`, `data/unlocks.json`, `tests/unit/save/`, `tests/fixtures/saves/`.
**Read.** SPEC 8, 13.3; CONTENT 10 to 12; ARCH 7.5; GDD 8.
**Deliverables.** `Profile` v2 and its codec, the migration and `MIGRATED_FROM_V1`, `purchase_unlock`, tier gates, milestones,
the `extras` of `grant_run_reward`, the Daily seed (the UTC date hashed in the game layer; the sim never reads the clock), and
the values of `unlocks.json`.
**Tests.** v1 to v2 migration on 6 fixture files; purchase atomicity; tier gates; milestones once; daily seed same for a date,
different across dates; reward extras.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Save and game tests | `tools\test.ps1 -Path res://tests/unit/save,res://tests/unit/game` passes | B09, B10 |

#### V4-U UI: Archive, kits, results, ticker, boss bar, hints

**Goal.** The remaining screens and HUD parts of GDD 10.
**Owned.** `src/ui/**`, `assets/icons/`, `data/strings/{variety,screens,combat,lore}_en.json`, `tests/unit/ui/`.
**Read.** SPEC 11.4 to 11.7, 13.5; ARCH 9; GDD 8.5, 9, 10.
**Deliverables.** `ArchiveScreen`, `KitSelector`, the results additions (build recap, what broke the line, SAME SEED, the Archive
hook), the threat ticker and edge arrows, boss-bar phase pips, the menu, briefing and pause additions, the first-run hints, the
approved story strings of GDD 2.3, and optionally the SWAP ASSIST setting.
**Tests.** Archive, kit selector, results additions, ticker (3 lines, priorities), boss pips, hints once per profile; sizes and
safe areas on 3 aspects.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| UI tests | `tools\test.ps1 -Path res://tests/unit/ui` passes | A16 |
| Captures | 8 captures (Archive, kit selector, results, ticker, boss bar and others) opened and listed in the report | A16, A17 |

#### V4-R View: weapon, enemy and boss models

**Goal.** Every new model, readable from above, inside its triangle budget.
**Owned.** `src/view/actors/**`, `tests/unit/view/actors_*`.
**Read.** SPEC 3.5, 5.1, 6, 12.2, 13.6; ARCH 8; GDD 6.3, 12.4, 12.5; the lookdev recipe in `docs/reports/lookdev/README.md`.
**Deliverables.** The seven remaining weapon models and the holstered weapon, the enemy models, `ward_pylon`, the four boss
models, all by the budgets of section 6.1; data-driven pools stay as V2-F left them.
**Tests.** Budgets, surfaces, one optic per mesh, silhouettes differ (the existing silhouette test pattern, pairwise).
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| View tests | `tools\test.ps1 -Path res://tests/unit/view` passes | B04, B06 |
| Roster capture | a roster capture of every enemy and boss, opened and listed in the report | A17 |

#### V4-X View: effects, zones, events, cosmetic chaos, tiers

**Goal.** Everything that happens to the yard is drawn, telegraphed and tier-scaled.
**Owned.** `src/view/{vfx,arena,kit}/**`, `tests/unit/view/{vfx,arena,kit}_*`.
**Read.** SPEC 7.2, 10.3, 10.4, 12.3, 13.6; ARCH 8, 13.2; GDD 6.7, 7b, 12.3.
**Deliverables.** `fx_beams`, `fx_lobs`, `fx_zones`, `fx_strike`, `fx_cosmetic`, the rail lines, freight car and fuel drums, the
telegraph decals, the tier tables of ARCH 13.2, Reduced Flash and High Contrast variants.
**Tests.** Pool caps by tier; a danger decal is drawn on every tier; Reduced Flash removes flashes and shake; legibility capture
at 50 + 40 during a chain.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| View tests | `tools\test.ps1 -Path res://tests/unit/view` passes | B05, B07, B12 |
| Captures | 6 captures (a chain on each tier and the event warnings), opened and listed in the report | A17, B12 |

#### V4-A Audio: the remaining sounds

**Goal.** All 60 new sound ids.
**Owned.** As V2-G.
**Read.** As V2-G.
**Deliverables.** The remaining 46 ids, the routing for the remaining signals, the combat drone driven by act and wave budget.
**Tests.** `gen.py --check`; every new id in the catalog has a file; alert voices are never starved (a test that floods weapon
sounds).
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Generator and audio tests | `py -3.12 -I C:\dev\tower-two-wt\V4-A\tools\audio_gen\gen.py --check` exits 0; `tools\test.ps1 -Path res://tests/unit/audio` passes | A20 |

#### V4-T Bots, scorecard tool

**Goal.** The eight policies and the predictability scorecard.
**Owned.** `src/sim/ai/**`, `tools/{scorecard_run,sim_run,balance_run}.*`, `tests/unit/sim_ai/`.
**Read.** SPEC 14, 13.8; CONTENT 13; ARCH 6.7, 12; GDD 8.4.
**Deliverables.** `hoarder`, `spammer`, `turret_rush`, `risk` and the full `balanced`; `scorecard.gd`, `build_signature.gd`;
`scorecard_run.ps1 -Runs n [-Pool base|full]`; `balance_run` reading the redefined targets.
**Tests.** Each policy is deterministic and never draws from a sim stream (a test compares `world.rng` hashes with and without
the bot's idle decisions); the scorecard maths on synthetic results.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Scorecard runs | `tools\scorecard_run.ps1 -Runs 5` prints a `SCORECARD:` line | B11 |

Optional, outside the path: **V4-X2** instanced bodies (10 hours), only if V2-P says the draw-call budget fails: draw all enemies
of a type as one transform-only MultiMesh (about 50 to 100 draw calls fewer). It replaces the material-swap hit flash with a
transform pop and needs the hard-surface look ported; its owned paths are set by the coordinator when it starts. Decide after the
phone baseline is measured.

**Gate after V4: owner playtest** ("can I read it?").

### 8.8 Waves V5 and V6

#### V5-A Gameplay integration and cleanup

**Goal.** The 15-wave game works end to end through `Game`, and the legacy HUD is gone.
**Owned.** `src/{sim,game,core,content,save,shared}/**`, `data/*.json`, `tests/**` except view, ui, audio; and, as the one
exception, the drawer: `src/ui/combat/{hud_upgrade_drawer,hud_upgrade_card}.gd`, the drawer members of `combat_hud.gd`
(`is_drawer_open`, `close_drawer`) and the HUD tests of the drawer in `tests/unit/ui/` (V5-B does not touch them).
**Read.** SPEC 13.5, 13.9, 15.3; all Wave V4 reports.
**Deliverables.** Full-run e2e tests for the 15-wave game (a scripted policy with a debug build, `--unlock=all` and
`debug_damage_mult`, for a fast deterministic victory, and a `none` run for a defeat; the suites that read `res://data/` on purpose
are rewritten here and in V3-I); the stress variant at 50 + 40 with blasts every second (limit 1.0 ms per tick on the desktop);
delete the drawer and its dead paths together with `BackPolicy`'s drawer branch; fix cross-layer defects.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Full gate | `tools\check.ps1` -> `CHECK OK` | A01 |
| Integration | `tools\test.ps1 -Path res://tests/integration` passes | B01, B08 |
| Runs | `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` | B01, B11 |

#### V5-B Presentation integration

**Goal.** What the player sees and hears is correct, legible and consistent on every supported screen shape.
**Owned.** `src/{view,ui,audio,debug}/**`, `assets/**`, `data/strings/**`, `tests/unit/{view,ui,audio}/`, `docs/reports/screenshots/`.
**Read.** SPEC 5.6, 12.3; GDD 6.7, 10, 12; all Wave V4 reports.
**Deliverables.** The screenshot set (at least 24 PNGs: every overlay, every boss, every event warning, a 50 + 40 chain on each
tier, Reduced Flash, High Contrast, 3 aspects), the accessibility audit against GDD 6.7 and 12.3, audio routing gaps.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Full gate | `tools\check.ps1` -> `CHECK OK` | A01 |
| Captures | the screenshot set under `docs/reports/screenshots/`, each opened and listed with a pass or issue note | A16, A17 |

#### V5-C Balance with the scorecard

**Goal.** The scorecard of GDD 8.4 passes.
**Owned.** `data/*.json` (values only), `docs/reports/BALANCE_REPORT.md`, `tests/fixtures/data_variety/` (refresh).
**Read.** SPEC 14; CONTENT (all); GDD 8.4; `docs/reports/BALANCE_REPORT.md`.
**Deliverables.** Tune `data/*.json` with the levers of GDD 8.4 until the checks below pass; write part 2 of
`BALANCE_REPORT.md` with before and after for every changed value; refresh the frozen fixture (and re-record its goldens).
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| Scorecard | `tools\scorecard_run.ps1 -Runs 200 -Pool base` and `-Pool full` print `SCORECARD: PASS` (or WARN rows each explained) | B11 |
| Balance | `tools\balance_run.ps1 -Runs 20` prints `BALANCE: PASS` | B11 |

**Gate: owner playtest** ("one more run?").

#### V6-Q Release QA, device evidence

**Goal.** The handoff's final delivery list with honest evidence for the 15-wave game.
**Owned.** The whole repository (fixes limited to defects found here). **Uses the physical device and the emulator** (rule 9).
**Read.** The W4-A step list (section 5), `handoff/06_QA_AND_RELEASE/*`, `docs/reports/*`, `docs/reports/PHONE_PERF.md`.
**Deliverables.** The W4-A step list, extended: resume after `am force-stop` mid-wave and mid-draft; a full run by input taps; a
15-minute soak with `--autoplay=balanced` on each tier with `[PERF]` lines; v1 profile migration on the device; reports and the
APK hash.
**Acceptance.**

| Check | Command or evidence | Matrix |
|---|---|---|
| W4-A steps 1 to 13 | as the table of W4-A, run for the 15-wave game; the APK SHA-256 recorded | A01 to A20 |
| Resume | `adb shell am force-stop <pkg>` mid-wave and again mid-draft, relaunch: RESUME RUN restores the same state | B08 |
| Migration | a v1 profile on the device migrates to v2 without loss | B09 |
| Soak | a 15-minute `--autoplay=balanced` run on each tier with `[PERF]` lines (the soak mode of `smoke_android.ps1`: W4-A step 10 used `-Soak 300 -MinFps 20`, here 900 s) | B12 |
| Evidence | reports and screenshots under `docs/reports/`; anything not run is **NOT RUN** | A20 |
