# IRON STATIC: CINDERFALL - Technical Architecture and Contracts

Version 1.1, 2026-11-11. This document is the technical source of truth. `GAME_DESIGN.md` is the source of
truth for rules and numbers. If they conflict, stop and report; do not guess.

**How to use this file.** Sections 4 to 12 are contracts. A task may not change a signature, signal, field
name, file path or schema defined here. If a contract is wrong or missing something, the agent stops, writes
the problem and a proposed fix in its report, and codes against the contract as written.

**The variety milestone (v1.1).** The owner-approved variety milestone (`docs/design/VARIETY_SPEC.md`, cited as SPEC n;
section 13 of the spec is the technical impact) extends these contracts **append only**: enum values and array entries are
added at the end and existing indices never move, existing signatures keep working (new parameters have defaults), existing
signals and event payloads keep their meaning, and new files and schemas are added beside the old ones. Text marked **(V)** is
new in v1.1. Everything here that describes the five-wave game (the fixed waves, the upgrade purchases, the 11-step tick) is
still true of the **legacy fixture** (`tests/fixtures/data_baseline/`, GDD Appendix A): `ContentLoader.build` with no variety
data produces it exactly, and a `shop_enabled` mission without a run plan runs the old way. The new contracts are implemented
once, as compiling stubs, by the scaffold task V1-S (WORK_PLAN section 8); later tasks fill bodies and do not edit them.

All paths are relative to the project root `C:\dev\tower-two` (`res://`).

---

## 1. Engine, toolchain, project settings

| Item | Value |
|---|---|
| Engine | Godot **4.7.2** stable, statically typed GDScript only |
| Godot CLI | `C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` (pin in `tools/GODOT_VERSION` = `4.7.2-stable`) |
| JDK / Android | JDK 17 at `C:\dev\tools\jdk-17`; SDK at `%LOCALAPPDATA%\Android\Sdk`; AVD `tower_phone` (1080x2400, x86_64, host GPU) |
| Tests | GdUnit4 **6.2.3** vendored in `addons/gdUnit4/` (MIT), run only through `tools\test.ps1` |
| Renderer | **Mobile** (`mobile`, Vulkan) on desktop and Android, per the handoff and owner decision 2026-11-11. `fallback_to_opengl3=true` is a safety net only: the boot log must report the Vulkan/Mobile renderer, and any fallback counts as a defect. See D1 |
| Orientation | Portrait (`display/window/handheld/orientation=1`) |
| Base viewport | 1080 x 1920, `stretch/mode="canvas_items"`, `stretch/aspect="expand"` (width stays 1080, height grows to 2400 on 20:9) |
| Desktop window | override 540 x 960 |
| Android | Debug APK, **no Gradle build** (no plugins), arm64-v8a + x86_64, min SDK 24, target = Godot default (36) |
| Package id | `com.normalexception.games.cinderfall.dev`, preset name `Cinderfall`, label "Cinderfall Dev" |
| Permissions | `VIBRATE` only. `INTERNET` off |

### 1.1 `project.godot` (Wave 0 writes exactly these; nobody else edits the file)

```ini
[application]
config/name="IRON STATIC: CINDERFALL"
config/version="0.1.0"
run/main_scene="res://scenes/main.tscn"
config/quit_on_go_back=false
config/features=PackedStringArray("4.7", "Mobile")
config/icon="res://icon.svg"
boot_splash/bg_color=Color(0.0627, 0.0941, 0.1255, 1)

[autoload]            ; order matters
Log="*res://src/core/log.gd"
Events="*res://src/core/event_bus.gd"
Content="*res://src/content/content_db.gd"
Save="*res://src/save/save_manager.gd"
Sfx="*res://src/audio/audio_director.gd"
Game="*res://src/core/game.gd"

[debug]               ; warnings are errors (2), same set as the original project
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/unused_signal=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/untyped_declaration=2
gdscript/warnings/inferred_declaration=1
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/unsafe_call_argument=2
gdscript/warnings/return_value_discarded=1
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/confusable_identifier=2

[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/window_width_override=540
window/size/window_height_override=960
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[editor]
export/convert_text_resources_to_binary=false

[editor_plugins]
enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")

[input_devices]
pointing/emulate_touch_from_mouse=true

[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
rendering_device/driver.windows="vulkan"
rendering_device/fallback_to_opengl3=true
textures/vram_compression/import_etc2_astc=true
environment/defaults/default_clear_color=Color(0.0627, 0.0941, 0.1255, 1)
anti_aliasing/quality/msaa_3d=0
```

`msaa_3d` stays 0 as the project default. The hard-surface looks (W3-C) set MSAA per quality tier at run time through
`LookDevStyle.apply_aa` (LOW off, MID 2x, HIGH 4x; the `CURRENT` look is always 0), called from `ArenaView.set_quality`
and `ArenaView.set_look`. The phone check of 4x on HIGH is done: MSAA is nearly free on the Pixel 11 Pro Fold (section 13.1).

### 1.2 Export preset `Cinderfall` (`export_presets.cfg`, owned by task W1-H)

`platform="Android"`, `runnable=true`, `export_filter="all_resources"`,
`include_filter="data/*.json, data/strings/*.json"`,
`exclude_filter="tests/*, tools/*, docs/*, addons/gdUnit4/*, build/*"`,
`export_path="build/com.normalexception.games.cinderfall.dev.debug.apk"`,
`gradle_build/use_gradle_build=false`, `architectures/arm64-v8a=true`, `architectures/x86_64=true`,
`package/unique_name="com.normalexception.games.cinderfall.dev"`, `package/name="Cinderfall Dev"`,
`package/signed=true`, `screen/immersive_mode=true`, `permissions/vibrate=true`, every other permission false.
No keystore path, alias or password is ever written to a tracked file.

---

## 2. Layering rules (hard, enforced by `tools/lint_layers.py`)

| Layer | Path | May depend on | Must not contain |
|---|---|---|---|
| shared | `src/shared/` | nothing | `extends Node`, autoload names, `randf`, `randi`, `Time.`, `OS.` |
| content defs | `src/content/defs/` | shared | same as shared |
| **sim** | `src/sim/` | shared, content defs | `extends Node`, `Engine.`, `OS.`, `Time.`, `Input`, `get_tree`, `randf(`, `randi(`, `randomize(`, the words `Events.` `Log.` `Content.` `Save.` `Game.` `Sfx.` |
| content, save | `src/content/`, `src/save/` | shared, defs | UI or view classes |
| game | `src/game/`, `src/core/` | everything below | - |
| view | `src/view/` | shared, defs, sim (**read only**), `Events` | any write to sim state |
| ui | `src/ui/` | shared, defs, `RunApi`, `Events`, `Save`, `Content` | `SimWorld` (the UI never touches the sim directly) |
| audio | `src/audio/` | shared, `Events`, `Save` | sim access |
| debug | `src/debug/` | anything | - |

Rules that follow from the original project's experience:

1. **The simulation is pure `RefCounted` code.** Same seed plus the same ordered commands gives the same
   `state_hash()`. The view and audio only read. Animations never apply damage.
2. **One writer per sim field** (table in 6.6).
3. Typed GDScript everywhere. `snake_case` files, `PascalCase` `class_name`, one class per file, past-tense
   signal names, files under 400 lines. Tabs in `.gd`. UTF-8 without BOM, LF.
4. **Scenes are thin.** A `.tscn` holds a root node with its script and nothing else unless stated; children
   are built in code in `_ready()` or `setup()`. This keeps text scenes trivial and mergeable.
5. No `get_node("../..")`. Dependencies arrive through a typed `setup(...)` or `bind(...)` call.
6. Numbers come from `data/*.json` through `ContentSet`. No gameplay constant in UI or view code.
7. Player-facing text comes from `Strings.t(key)`.
8. No Timer node per entity, no allocation inside per-tick enemy loops, no `Vector2` creation per enemy per
   tick in sim hot loops (use the packed x/z arrays).

---

## 3. Directory layout

```
C:\dev\tower-two\
  project.godot  export_presets.cfg  icon.svg  .gitignore  .gitattributes  .editorconfig  CLAUDE.md  README.md
  addons/gdUnit4/                     vendored, MIT
  assets/
    fonts/                            Oxanium-Variable.ttf, ShareTechMono-Regular.ttf, OFL texts, LICENSES.md
    audio/sfx/ audio/loops/           generated .wav (tools/audio_gen)
    icons/                            UI icons as .svg (128x128 viewBox)
    textures/                         generated .png (noise, stencil), optional
  data/
    vertical_slice_balance.json  waves.json  visual_tokens.json     copied from the handoff (then tunable)
    content_ext.json  arena.json                                     new, defined in section 5
    strings/content_en.json  combat_en.json  screens_en.json  lore_en.json
  docs/
    GAME_DESIGN.md  ARCHITECTURE.md  WORK_PLAN.md  HANDOFF_REVIEW.md  copies of the design docs
    handoff/                          full copy of the handoff package incl. PNGs; contains `.gdignore`
    reports/                          TEST_REPORT.md, PERFORMANCE_REPORT.md, BALANCE_REPORT.md, ... (evidence)
  scenes/main.tscn                    root Node + src/core/main.gd, nothing else
  src/
    shared/      game_state.gd game_state_machine.gd reason.gd damage_source.gd run_result.gd ids.gd
    core/        log.gd event_bus.gd game.gd main.gd strings.gd
    content/     content_db.gd content_loader.gd content_validator.gd
    content/defs/ content_set.gd mission_def.gd enemy_def.gd weapon_def.gd upgrade_def.gd ability_def.gd
                 spawn_group_def.gd wave_def.gd arena_def.gd obstacle_def.gd spawn_region_def.gd visual_tokens.gd
    sim/         sim_world.gd sim_config.gd sim_command.gd command_log.gd sim_event.gd sim_event_kind.gd
                 sim_events.gd sim_rng.gd state_hasher.gd formulas.gd run_stats.gd run_summary.gd replay.gd
    sim/stores/  enemy_store.gd turret_store.gd warden_state.gd ability_state.gd
    sim/nav/     nav_state.gd arena_grid.gd flow_field.gd spatial_hash.gd attack_slots.gd
    sim/systems/ spawn_system.gd movement_system.gd targeting.gd weapon_system.gd turret_system.gd
                 damage_resolver.gd core_attack_system.gd combat_state.gd
                 command_system.gd economy_system.gd ability_system.gd phase_system.gd phase_state.gd
    sim/ai/      policy_bot.gd
    save/        save_manager.gd profile.gd profile_codec.gd save_fs.gd disk_save_fs.gd memory_save_fs.gd
    game/        run_controller.gd tick_driver.gd run_api.gd sim_run_api.gd mobile_shell.gd back_policy.gd haptics.gd
    view/        battle_view.gd battle_view.tscn
    view/kit/    mat_lib.gd mesh_builder.gd mesh_kit.gd visual_quality.gd
    view/camera/ camera_rig.gd camera_fit.gd camera_fit_result.gd
    view/arena/  arena_view.gd  (+ floor, props, core, lighting helpers)
    view/actors/ actor_layer.gd  (+ enemy pool, actor meshes, warden view, turret view)
    view/vfx/    vfx_layer.gd    (+ tracers, sparks, rings, floating text)
    ui/kit/      ui_theme.gd ui_kit.gd safe_area.gd hud_layout.gd
    ui/combat/   combat_hud.gd combat_hud.tscn pause_overlay.gd pause_overlay.tscn (+ drawer, cards, ability bar)
    ui/screens/  main_menu_screen.* briefing_screen.* results_screen.* settings_screen.* boot_screen.*
    audio/       audio_director.gd (+ sfx pool, event router, slots)
    debug/       debug_args.gd capture_runner.gd sim_puppet.gd fake_run_api.gd view_sandbox.* hud_sandbox.*
                 perf_hud.gd
  tests/
    unit/{shared,core,content,sim,sim_nav,sim_combat,sim_flow,save,game,view,ui,audio}/
    integration/{sim,game,e2e}/   stress/   fixtures/   canary/
  tools/         GODOT_VERSION GDUNIT_VERSION _common.ps1 check.ps1 test.ps1 test_runner.py compile_check.gd
                 compile_gate.py lint_layers.py capture.ps1 sim_run.gd sim_run.ps1 balance_run.gd balance_run.ps1
                 run_emulator.ps1 deploy_android.ps1 smoke_android.ps1 audio_gen/
  build/         outputs; contains `.gdignore`; git-ignored
```

Deviation D3: the handoff proposes `scenes/` + `scripts/`. This layout co-locates each thin scene with its
script under `src/<layer>/` so directory ownership maps one-to-one onto parallel tasks.

### 3.1 Variety milestone additions (V)

New folders and files, all created by V1-S as stubs and filled by the owning task (WORK_PLAN section 8). The tree above is
otherwise unchanged.

```
  data/
    run.json  weapons.json  enemies.json  directives.json  events.json  unlocks.json     new, schema 1 (section 5.2)
    arena.json                                                                             schema 2 (section 5.2)
    strings/variety_en.json                                                                all new player text
  src/
    shared/      (existing files extended, append only: ids.gd reason.gd damage_source.gd; section 4)
    content/defs/ run_def.gd act_def.gd wave_slot_def.gd pack_def.gd modifier_def.gd reward_def.gd directive_def.gd op_def.gd
                 event_def.gd affix_def.gd boss_def.gd unlock_def.gd kit_def.gd (+ extended enemy/weapon/mission/arena/content_set)
    sim/plan/    run_plan.gd planned_wave.gd route_option.gd planned_event.gd planned_elite.gd
    sim/stores/  draft_state.gd mod_state.gd arsenal_state.gd hazard_state.gd enemy_ext_state.gd salvage_state.gd
                 event_state.gd boss_state.gd
    sim/systems/ run_plan_system.gd wave_builder.gd draft_system.gd mod_system.gd arsenal_system.gd area_damage.gd
                 hazard_system.gd status_system.gd death_hooks.gd core_hooks.gd shot_hooks.gd elite_system.gd
                 event_system.gd boss_system.gd salvage_system.gd
    sim/systems/fire/    fire_hitscan.gd fire_cone.gd fire_arc.gd fire_line.gd fire_shell.gd fire_missiles.gd fire_beam.gd
    sim/systems/events/  event_<id>.gd            one file per event (10)
    sim/systems/bosses/  boss_<id>.gd             one file per boss (5)
    sim/ai/      policy_*.gd (7 files) scorecard.gd build_signature.gd
    ui/run/      draft_overlay.* directive_card.gd route_overlay.* route_card.gd boss_brief_overlay.* salvage_overlay.*
                 build_list.gd
    ui/screens/  archive_screen.* kit_selector.gd
    ui/combat/   hud_weapon_bar.gd hud_weapon_card.gd hud_call_button.gd hud_threat_ticker.gd hud_edge_arrows.gd
    view/actors/ mini_swarm.gd enemy_meshes_2.gd boss_meshes.gd weapon_meshes.gd crate_view.gd
    view/arena/  rail_lines.gd freight_view.gd drum_view.gd
    view/vfx/    fx_blasts.gd fx_arcs.gd fx_beams.gd fx_lobs.gd fx_zones.gd fx_strike.gd fx_cosmetic.gd
  tests/
    unit/{sim_plan,sim_draft,sim_arsenal,sim_enemies,sim_boss,sim_events,sim_ai}/
    fixtures/data_variety/    frozen copy of the first complete variety data set (section 13); fixtures/saves/ gains v1, v2
                              and run-file fixtures
  tools/         scorecard_run.gd scorecard_run.ps1 plan_dump.gd plan_dump.ps1          (section 12)
  assets/        icons/ (about 20 tag, rarity and category SVGs and 10 weapon silhouettes), audio/sfx/ (60 new ids)
  docs/reports/  PERFORMANCE_REPORT.md (V2-P), PHONE_PERF.md (device measurements, section 13), BALANCE_REPORT.md part 2
```

`hud_upgrade_drawer.gd` and `hud_upgrade_card.gd` stay until the cleanup task V5-A deletes them (section 9).

---

## 4. Shared enums and ids (`src/shared/`, complete in Wave 0, frozen; (V) extended once by V1-S, append only)

```gdscript
class_name GameState            # src/shared/game_state.gd
enum Id { BOOT, MENU, BRIEFING, PREPARING, SPAWNING, CLEARING, INTERMISSION, VICTORY, DEFEAT, PAUSED }
static func name_of(id: int) -> String
static func is_run_phase(id: int) -> bool        # PREPARING..DEFEAT
static func is_combat(id: int) -> bool           # SPAWNING or CLEARING
static func is_terminal(id: int) -> bool         # VICTORY or DEFEAT

class_name RunResult            # src/shared/run_result.gd
enum Id { NONE, VICTORY, DEFEAT, ABANDONED }

class_name DamageSource         # src/shared/damage_source.gd
enum Id { WARDEN = 0, TURRET_0 = 1, TURRET_1 = 2,
          WARDEN_OFFHAND = 3, CORE = 4, STRIKE = 5, HAZARD = 6 }          # (V) 3..6 appended; CombatState.SOURCES 3 -> 7

class_name Reason               # src/shared/reason.gd  (command outcomes)
enum Id { OK, WRONG_STATE, UNKNOWN_ID, MAX_LEVEL, INSUFFICIENT_SCRAP, PREREQ_NOT_MET,
          DUPLICATE_COMMAND, ON_COOLDOWN, ALREADY_ACTIVE, PAUSED,
          NOT_AWAITING, INVALID_CHOICE, NO_CHARGES, LOCKED_BY_EVENT, SHOP_CLOSED }   # (V) appended
static func string_key(id: int) -> String        # e.g. "reason.insufficient_scrap"; the new ids get "reason.shop_closed", ...

class_name Ids                  # src/shared/ids.gd  (index = position in these arrays, fixed forever)
const ENEMIES: Array[StringName] = [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk",
    # (V) index 4..17, appended:
    &"mote", &"shard", &"burster", &"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer", &"borer",
    &"ward_pylon", &"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig"]
const WEAPONS: Array[StringName] = [&"pistol", &"smg",
    # (V) index 2..9, appended:
    &"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"arc_projector", &"rail_lance"]
const UPGRADES: Array[StringName] = [&"damage", &"fire_rate", &"armor_piercing", &"auto_turret", &"smg_unlock"]   # legacy, unchanged
const ABILITIES: Array[StringName] = [&"emp", &"shield", &"overdrive"]
const UP_DAMAGE := 0; const UP_FIRE_RATE := 1; const UP_ARMOR_PIERCING := 2; const UP_AUTO_TURRET := 3; const UP_SMG := 4
const AB_EMP := 0; const AB_SHIELD := 1; const AB_OVERDRIVE := 2
const EN_SKITTER := 0; const EN_HOLLOW := 1; const EN_RUSHER := 2; const EN_HULK := 3
# (V) one constant per appended id: EN_MOTE := 4 ... EN_TREMOR_RIG := 17; WP_PISTOL := 0, WP_SMG := 1, WP_SCATTERGUN := 2 ... WP_RAIL_LANCE := 9
static func enemy_index(id: StringName) -> int   # -1 if unknown; same for weapon_index, upgrade_index, ability_index
```

**(V) Append only; indices are fixed forever.** The existing indices do not move: a replay, a golden hash, a save file and a
frozen fixture all depend on them. `UPGRADES` and the `UP_*` constants stay because the three stat directives (`hot_loads`,
`cyclic_tuning`, `penetrator_cores`) feed `upgrade_levels[UP_DAMAGE]`, `[UP_FIRE_RATE]` and `[UP_ARMOR_PIERCING]` through the
same formulas, and `turret_deploy` fills the same turret pads (the legacy HUD and tests keep reading them). Directives, packs, modifiers, events, affixes, unlocks and kits are **not** in `Ids`:
their index is their position in their data list (section 5.2). `GameState`, `GameStateMachine` and `RunResult` are
**frozen** and do not change.

### 4.1 State machine (`src/shared/game_state_machine.gd`)

```gdscript
class_name GameStateMachine extends RefCounted
var current: int = GameState.Id.BOOT
var previous: int = GameState.Id.BOOT
var paused_from: int = -1                       # state to return to on resume
static func can_transition(from: int, to: int) -> bool
func transition(to: int) -> bool                # false and no change when illegal
```

Legal transitions (everything else is illegal and logged):

| From | To |
|---|---|
| BOOT | MENU |
| MENU | BRIEFING |
| BRIEFING | MENU, PREPARING |
| PREPARING | SPAWNING, PAUSED |
| SPAWNING | CLEARING, DEFEAT, PAUSED |
| CLEARING | INTERMISSION, VICTORY, DEFEAT, PAUSED |
| INTERMISSION | SPAWNING, PAUSED |
| PAUSED | `paused_from` (resume), PREPARING (restart), MENU (quit) |
| VICTORY, DEFEAT | PREPARING (retry), MENU |

The simulation owns the run phases (PREPARING to DEFEAT) in `SimWorld.phase`. `Game` owns the application
machine and mirrors sim phase changes into it. PAUSED exists only at application level; the sim does not know
it is paused, it is simply not stepped. This matches the handoff state list (adopted as-is) with the split
of ownership made explicit.

**(V) Intermission sub-steps are not application states.** `GameState.Id` is frozen. The intermission of the variety game
(salvage, draft, route or boss briefing, then a breather) is held in `PhaseState` (owned by the flow systems, hashed):

```gdscript
# PhaseState additions (V)
enum Await { NONE, SALVAGE, DRAFT, ROUTE, BOSS_BRIEF }
var awaiting: int = Await.NONE
var act: int = 1                 # 1..3
var breather: bool = false       # true while INTERMISSION counts breather_ticks
```

| Step | Entered when | Left by | Timers |
|---|---|---|---|
| `SALVAGE` | Wave cleared and a crate is banked (repeats per crate) | `SALVAGE` command | frozen |
| `DRAFT` | After salvage (or directly at wave clear) | `PICK_DIRECTIVE` or `SKIP_DRAFT` (after any `REROLL`, `BUY_OUT`, `PATCH_CORE`) | frozen |
| `ROUTE` | After the draft, when the next wave is normal | `PICK_ROUTE` | frozen |
| `BOSS_BRIEF` | After the draft, when the next wave is a boss wave | `SKIP_INTERMISSION` (the CONTINUE button) | frozen |
| breather | After the last choice | `breather_ticks` (180) elapse, or `SKIP_INTERMISSION` | **running** (cooldowns recover as in the legacy intermission) |

While `awaiting != NONE` the sim treats a `step()` as "apply queued commands only": `tick` does **not** advance, no timer runs,
no event is scheduled (6.2). `RunController` keeps calling `TickDriver.advance`; it is the sim that refuses to move, so the
driver's accumulated time is consumed by steps that do nothing and no burst of ticks follows a long choice. Wave-clear effects
(the `rw_*` reward, `field_weld`, `compound_interest`, the act-clear repair of +15% after a boss) are applied before the first
await. Abilities stay illegal outside SPAWNING and CLEARING (unchanged); `SWAP_WEAPON` is legal in the breather. The legacy
fixture never awaits: its INTERMISSION is the `intermission_ticks` countdown of 6.6.

---

## 5. Content pipeline

### 5.1 Decision

The `03_DATA` JSON files are copied into `res://data/` and **loaded at runtime through a strict schema
adapter** into typed `RefCounted` defs. There is no `.tres` generation step. (Deviation D4. The handoff's
`03_DATA/README.md` allows exactly this; it avoids the original project's `.tres` export pitfalls.)
The export preset includes `data/*.json` explicitly, and the Android smoke test checks the log line
`content ok` to prove the data loaded on a device.

Runtime read: `FileAccess.get_file_as_string("res://data/<file>")` then `JSON.parse_string`.
`data/` must **not** contain a `.gdignore`.

### 5.2 Files

| File | Origin | Content |
|---|---|---|
| `data/vertical_slice_balance.json` | handoff, schema 2 | mission, weapons, enemies, upgrades, abilities, reward, targeting |
| `data/waves.json` | handoff, schema 2 | five waves of spawn groups |
| `data/visual_tokens.json` | handoff | palette, camera band, UI fractions |
| `data/content_ext.json` | new, schema 1 | fields the handoff contracts name but the JSON lacks |
| `data/arena.json` | new, schema 1 | bounds, core, Warden, pads, spawn regions, obstacles, slots, camera |
| `data/strings/*_en.json` | new | flat `{ "key": "text" }` maps; fixed file list `content, combat, screens, lore`; (V) plus `variety` |
| **(V)** `data/run.json` | new, schema 1 | acts, waves, packs, modifiers, route rewards, draft rules, salvage, caps, rewards, mission overrides |
| **(V)** `data/weapons.json` | new, schema 1 | the 10 weapons, the turret types, swap and holster rules |
| **(V)** `data/enemies.json` | new, schema 1 | the 9 new enemy types and 4 new bosses, overrides of the 4 old types, elites, affixes, bosses, Node 9 variants |
| **(V)** `data/directives.json` | new, schema 1 | the 60 directives (index = position) |
| **(V)** `data/events.json` | new, schema 1 | the 10 events, hazards, schedule rules |
| **(V)** `data/unlocks.json` | new, schema 1 | the 24 unlocks, 6 kits, tier gates, 13 milestones |
| **(V)** `data/strings/variety_en.json` | new | all new player text (keys `directive.*`, `weapon.*`, `enemy.*`, `event.*`, `route.*`, `archive.*`, `kit.*`, `hud.*` additions) |
| **(V)** `data/arena.json` | schema 1 to 2 | adds `standoff`, `breach_points`, `drop_points`, `drum_points`, `rail_lines` |

`data/content_ext.json` (Wave 0 writes this verbatim):

```json
{
  "schema_version": 1,
  "mission": { "prepare_seconds": 3.0, "eta_bucket_seconds": 0.5, "max_spawns_per_tick": 4,
               "stuck_seconds": 4.0, "stuck_min_progress_m": 0.5 },
  "enemies": {
    "skitter":       { "radius": 0.35, "mass": 0.5,  "separation_weight": 1.0, "weave_amp_m": 0.5, "weave_period_s": 1.2,
                       "direct_seek": false, "is_boss": false, "priority_class": false, "slot_span": 1, "visual_height_m": 0.9 },
    "hollow_warden": { "radius": 0.55, "mass": 3.0,  "separation_weight": 0.4, "weave_amp_m": 0.0, "weave_period_s": 1.0,
                       "direct_seek": false, "is_boss": false, "priority_class": false, "slot_span": 1, "visual_height_m": 1.7 },
    "rusher":        { "radius": 0.40, "mass": 1.0,  "separation_weight": 0.3, "weave_amp_m": 0.0, "weave_period_s": 1.0,
                       "direct_seek": true,  "is_boss": false, "priority_class": true,  "slot_span": 1, "visual_height_m": 1.4 },
    "siege_hulk":    { "radius": 1.60, "mass": 50.0, "separation_weight": 0.0, "weave_amp_m": 0.0, "weave_period_s": 1.0,
                       "direct_seek": false, "is_boss": true,  "priority_class": false, "slot_span": 3, "visual_height_m": 3.4 }
  },
  "upgrades": {
    "damage": { "kind": "stat", "min_wave": 1 }, "fire_rate": { "kind": "stat", "min_wave": 1 },
    "armor_piercing": { "kind": "stat", "min_wave": 1, "cap": 0.90 },
    "auto_turret": { "kind": "turret", "min_wave": 1, "lock_seconds": 0.4 },
    "smg_unlock": { "kind": "weapon_unlock", "weapon": "smg", "min_wave": 2 }
  },
  "abilities": {
    "emp": { "cooldown_starts": "on_activate", "boss_immunity_s": 5.0 },
    "shield": { "cooldown_starts": "on_end" },
    "overdrive": { "cooldown_starts": "on_end" }
  }
}
```

`data/arena.json` (Wave 0 writes this verbatim; X = screen right, Z = screen down, meters):

```json
{
  "schema_version": 1,
  "id": "quiet_yards_b4",
  "bounds": { "min_x": -10.0, "max_x": 10.0, "min_z": -16.0, "max_z": 12.0 },
  "grid": { "cell_m": 1.0, "margin_cells": 2 },
  "core": { "x": -7.5, "z": 3.0, "radius": 2.0 },
  "warden": { "x": -5.2, "z": 7.0 },
  "turret_pads": [ { "x": -2.5, "z": -1.5 }, { "x": -1.0, "z": 8.0 } ],
  "approach_radius": 9.0,
  "slots": { "arc_start_deg": -40.0, "arc_end_deg": 130.0, "ring_radii": [3.0, 4.2, 5.4, 6.6], "ring_counts": [10, 14, 18, 22] },
  "spawn_regions": {
    "right":       { "x0": 10.8, "z0": -8.0,  "x1": 10.8, "z1": 9.0 },
    "upper_right": { "x0": -1.0, "z0": -16.8, "x1": 10.0, "z1": -16.8 }
  },
  "obstacles": [
    { "id": "barrier_a", "shape": "box", "x": 1.5,  "z": -5.0, "size_x": 3.2, "size_z": 0.8, "rot_deg": 30.0,  "visual": "jersey_barrier" },
    { "id": "barrier_b", "shape": "box", "x": 3.0,  "z": 6.5,  "size_x": 3.2, "size_z": 0.8, "rot_deg": -25.0, "visual": "jersey_barrier" },
    { "id": "crates",    "shape": "circle", "x": 4.5, "z": 0.5, "radius": 1.3, "visual": "crate_stack" },
    { "id": "drums",     "shape": "circle", "x": -0.5, "z": -9.5, "radius": 1.0, "visual": "drum_cluster" }
  ],
  "camera": { "pitch_down_deg": 50.0, "yaw_deg": 0.0, "frame_margin_m": 0.5, "decor_yaw_deg": 38.0 }
}
```

Slot angle convention: angle 0 points along +X (screen right), positive angles turn toward -Z (screen up).
Slot `k` of a ring with `n` slots sits at `arc_start + (k + 0.5) * (arc_end - arc_start) / n`. Slot indices
run ring 0 first (0..9), then ring 1 (10..23), ring 2 (24..41), ring 3 (42..63).

**(V) Variety data files.** All new files carry `schema_version: 1`, are covered by the export preset's `include_filter`
(`data/*.json` already includes them), and are never merged into the handoff-schema balance file (that would break the frozen
baseline fixture). Top-level fields; every number in them is a first-pass value (CONTENT n is the table a build agent
transcribes; when a number is in both SPEC and CONTENT, CONTENT wins):

| File | Top-level fields |
|---|---|
| `data/run.json` | `acts[] {id, name_key, hp_mult, core_dmg_mult, rarity_weights[3], corrupted_chance, elites_min, elites_max, affixes_min, affixes_max}`, `waves[] {index, act, kind, budget, window_s, peak_bodied, peak_minis, event_slots, fixed_pack?}`, `packs[] {id, name_key, min_act, budget_mult, extra_elites, groups[] {enemy, share, region, start, tempo}}`, `modifiers[] {id, name_key, list, ops[]}`, `route_rewards[] {id, name_key, weight_standard, weight_hot, ops[]}`, `draft {offer_size, skip_scrap, reroll_base, reroll_step, buyout_base, buyout_step, patch_frac, patch_base, patch_step, tag_lean, weapon_lean, repeat_penalty, rare_pity}`, `salvage {secure_s, contest_radius_m, lifetime_s, bank_max, scrap_by_act[3], tier_weights[3][4], dupe_bias}`, `caps {swarm_cap, max_elites_alive, max_blasts_per_tick}`, `reward {per_wave, boss_by_act[2], victory_base, victory_core_bonus}`, `mission {shop_enabled, breather_seconds}` |
| `data/weapons.json` | `weapons{} {tier, kind, damage, shots_per_second, magazine, reload_seconds, range_m, min_range_m, spread_deg, pierce, pierce_falloff, area_m, pellets, salvo, flight_s, chains, chain_range_m, chain_falloff, charge_s, heat_per_shot, cool_per_s, heat_cap, vent_s, armor_ignore, ward_mult, stunned_mult, spin_up_s, sps_min, stray_chance, armor_shred, pool{}, knockback_m, level_mult[3], level3{}}`, `turrets{}` (CONTENT 8), `swap_seconds`, `holster_reload_mult` |
| `data/enemies.json` | `enemies{}` = the balance fields plus the `content_ext` fields plus `class, cost, min_act, alive_cap, standoff_m, behaviour{}` for the 9 new types and the 4 new bosses; `overrides{}` (new Scrap values and `class`, `cost`, `alive_cap` for the 4 old types); `elite {hp_mult, scale, scrap_mult}`, `affixes[] {id, name_key, ops[]}`, `affix_rules {forbidden_pairs[], by_act[]}`, `bosses{} {pool_act, hp, behaviour{}, escorts[]}`, `hulk_variants[]` |
| `data/directives.json` | `directives[] {id, category, rarity, max, tags[], requires{}, ops[], hook?, pool}` in a fixed order (the index is the position) |
| `data/events.json` | `events[] {id, who, name_key, warn_s, duration_s, weights[3], boss_safe, harmful, params{}}`, `hazards{}`, `rules {window_min, window_max, mercy_core_frac}` |
| `data/unlocks.json` | `unlocks[] {id, branch, tier, cost, grants[]}`, `kits[] {id, name_key, cost, ops[]}`, `tier_gates[]`, `milestones[] {id, data}` |

`ops[]` is one small grammar shared by directives, modifiers, kits, affixes and rewards:
`{ "stat": "<ModState field>", "add": n }`, `{ "stat": ..., "mul": n }`, `{ "flag": "<name>" }`, `{ "grant": "<kind>", "n": n }`.
34 of the 60 directives need nothing else; the rest name a `hook` (section 6.6, `DeathHooks`, `CoreHooks`, `ShotHooks`).

`data/arena.json` **schema 2** adds, on the same yard: `standoff {radii[], counts[]}` (standoff points for spitters and
reclaimers on the slot arc), `breach_points[]`, `drop_points[]` (the four crate points of CONTENT 7.2), `drum_points[]` (six
fixed points; three are used per act) and `rail_lines[] {z, half_width}` (z = -7.0 and 10.5, CONTENT 6). The loader accepts
schema 1 (the legacy fixture: the new lists are empty) and schema 2.

### 5.3 Def classes (`src/content/defs/`, all `extends RefCounted`, all fields typed, complete in Wave 0)

```gdscript
class_name MissionDef
var id: StringName; var name_key: String
var core_max_hp: float; var ticks_per_second: int; var enemy_cap: int
var intermission_ticks: int; var prepare_ticks: int
var target_duration_min_s: float; var target_duration_max_s: float
var reward_victory_base: int; var reward_core_hp_divisor: int; var reward_defeat_per_wave: int
var lock_ticks: int; var eta_bucket_ticks: int
var max_spawns_per_tick: int; var stuck_ticks: int; var stuck_min_progress_m: float

class_name EnemyDef
var id: StringName; var index: int; var name_key: String
var hp: float; var speed_mps: float; var armor: float
var core_damage: float; var attack_period_ticks: int; var scrap: int
var radius: float; var mass: float; var separation_weight: float
var weave_amp_m: float; var weave_period_ticks: int; var direct_seek: bool
var is_boss: bool; var priority_class: bool; var slot_span: int
var visual_id: StringName; var visual_height_m: float       # visual_id == id in the slice

class_name WeaponDef
var id: StringName; var index: int; var name_key: String
var damage: float; var sps_milli: int                         # shots per second x 1000, integer
var magazine: int; var reload_ticks: int; var range_m: float

class_name UpgradeDef
enum Kind { STAT, TURRET, WEAPON_UNLOCK }
var id: StringName; var index: int; var name_key: String; var kind: int
var base_cost: int; var growth: float; var max_level: int; var per_level: float; var cap: float
var min_wave: int; var weapon_index: int                      # -1 unless WEAPON_UNLOCK
var turret_damage: float; var turret_sps_milli: int; var turret_range_m: float; var turret_lock_ticks: int

class_name AbilityDef
enum CooldownStart { ON_ACTIVATE, ON_END }
var id: StringName; var index: int; var name_key: String
var cooldown_ticks: int; var duration_ticks: int; var cooldown_start: int
var stun_ticks: int; var boss_stun_ticks: int; var boss_immunity_ticks: int   # emp
var absorb: float                                                            # shield
var fire_rate_mult_milli: int                                                # overdrive (2000)

class_name SpawnGroupDef
var enemy_index: int; var count: int; var start_tick: int; var interval_ticks: int; var region_id: StringName

class_name WaveDef
var index: int; var peak_target: int; var groups: Array[SpawnGroupDef]
func total_count() -> int

class_name SpawnRegionDef
var id: StringName; var x0: float; var z0: float; var x1: float; var z1: float

class_name ObstacleDef
enum Shape { CIRCLE, BOX }
var id: StringName; var shape: int; var x: float; var z: float
var radius: float; var size_x: float; var size_z: float; var rot_deg: float; var visual: StringName
func contains(px: float, pz: float, inflate: float) -> bool

class_name ArenaDef
var id: StringName
var min_x: float; var max_x: float; var min_z: float; var max_z: float
var cell_m: float; var margin_cells: int
var core_x: float; var core_z: float; var core_radius: float
var warden_x: float; var warden_z: float
var turret_pads: PackedVector2Array                # (x, z)
var approach_radius: float
var slot_positions: PackedVector2Array             # (x, z), 64 entries, computed by the loader
var slot_ring: PackedInt32Array
var spawn_regions: Array[SpawnRegionDef]
var obstacles: Array[ObstacleDef]
var pitch_down_deg: float; var yaw_deg: float; var frame_margin_m: float; var decor_yaw_deg: float
func region(region_id: StringName) -> SpawnRegionDef

class_name VisualTokens
var palette: Dictionary[StringName, Color]         # obsidian, warden_cyan, core_amber, chorus_red, gunmetal, bone_ceramic
var top_hud_fraction: float; var bottom_controls_fraction: float
var touch_target_min_dp: int; var text_contrast_target: float
var down_angle_min_deg: float; var down_angle_max_deg: float
func color(token: StringName) -> Color

class_name ContentSet
var mission: MissionDef
var enemies: Array[EnemyDef]                       # indexed by Ids.ENEMIES order
var weapons: Array[WeaponDef]
var upgrades: Array[UpgradeDef]                    # 5 entries; smg_unlock is synthesized from weapons.smg.unlock_scrap
var abilities: Array[AbilityDef]
var waves: Array[WaveDef]                          # index 0 = wave 1
var arena: ArenaDef
var tokens: VisualTokens
var strings: Dictionary[String, String]
func enemy(id: StringName) -> EnemyDef             # also weapon(), upgrade(), ability(); null if unknown
```

Conversion rules: `ticks = roundi(seconds * 60.0)`; `sps_milli = roundi(shots_per_second * 1000.0)`;
`weave_period_ticks`, `stuck_ticks`, `eta_bucket_ticks` likewise.

**(V) Def additions.** Typed defs are the project convention, so the new data gets typed defs. EXT = an existing class gains
appended fields (every existing field and call stays valid); NEW = a new class under `src/content/defs/`. The fields of the new
defs map the JSON keys of 5.2 one to one (straight mapping, seconds converted to ticks by the rules above); V1-S writes the
final declarations and this section is updated from them.

| Def | Change |
|---|---|
| `EnemyDef` EXT | `+ enemy_class: int` (B bodied, M mini, S standoff), `cost: float`, `min_act: int`, `alive_cap: int`, `standoff_m: float`, and the fields of `behaviour{}` (death blast, fuse, ward, aura, split, tether, ...) |
| `WeaponDef` EXT | `+` the fields of `weapons.json` `weapons{}` (kind, damage, area, pellets, salvo, chains, charge, heat, pool, level multipliers, ...) |
| `MissionDef` EXT | `+ swarm_cap: int`, `breather_ticks: int`, `shop_enabled: bool` |
| `ArenaDef` EXT | `+` the new point lists of `arena.json` schema 2 (standoff points, breach, drop and drum points, rail lines) |
| `ContentSet` EXT | `+ run: RunDef`, `directives`, `events`, `unlocks` (kits and milestones travel with them), `affixes`, `bosses` |
| NEW | `RunDef`, `ActDef`, `WaveSlotDef`, `PackDef`, `ModifierDef`, `RewardDef`, `DirectiveDef`, `OpDef`, `EventDef`, `AffixDef`, `BossDef`, `UnlockDef`, `KitDef` |

`OpDef` carries the `ops[]` grammar of 5.2: `stat`, `add`, `mul`, `flag`, `grant`, `n`. In the legacy fixture
`ContentSet.waves` is the five scripted waves; in the variety game the waves come from `RunDef.waves` and the plan (6.1).

### 5.4 Loader, validator, autoload

```gdscript
class_name ContentLoader extends RefCounted            # src/content/content_loader.gd
static func load_from_dir(dir: String) -> ContentLoadResult     # dir = "res://data"
static func build(balance: Dictionary, waves: Dictionary, tokens: Dictionary, ext: Dictionary,
                  arena: Dictionary, strings: Dictionary, variety: Dictionary = {}) -> ContentLoadResult
    # (V) `variety` = file name to parsed JSON (run, weapons, enemies, directives, events, unlocks). Empty = today's content
    # exactly (the legacy fixture). The 6-dictionary calls of TestContent.baseline() stay valid.

class_name ContentLoadResult extends RefCounted
var content: ContentSet          # null when errors is not empty
var errors: PackedStringArray    # human-readable, one per problem, with file and JSON path

class_name ContentValidator extends RefCounted         # src/content/content_validator.gd
static func validate(content: ContentSet) -> PackedStringArray
```

Validation (every rule has a unit test with a bad fixture): schema versions match; every number finite and
non-negative; required keys present, unknown top-level keys reported; every enemy id in waves exists; wave
indices are exactly 1..5 and unique; group count >= 1, interval >= 1 tick; region ids exist; cap >= 1;
upgrade costs > 0 and growth >= 1; cooldowns > 0; slots >= enemy cap + 2; no obstacle within
`approach_radius + 1` of the core; every spawn-region cell reaches the core in the flow field (the validator
calls `FlowField.build`); Warden and pads inside bounds; palette has the six tokens. The wave-index rule applies to
`waves.json` (1..5); the waves of `run.json` are exactly 1..15.

**(V) New validation rules**, each with a bad fixture: every id referenced exists; pack shares sum to 1; every wave has a pack
available for its act; `alive_cap` >= 1; weights not all zero; ops name real stats; drop, drum and breach points are free
cells that reach the core; rail lines cross no pad, no core, no Warden; standoff points are free; kits reference
unlocked-or-base items; unlock grants are disjoint; boss pools have at least 1 entry per act. The strings loader reads
`STRING_FILES` plus `variety_en.json`, which is loaded only if present (the legacy fixture has none).

`Content` autoload (`src/content/content_db.gd`, `extends Node`):

```gdscript
var db: ContentSet                     # valid after _ready; never null in a running game (named db: `set` is an Object method)
var load_errors: PackedStringArray
func reload() -> bool                  # re-reads res://data; true on success
```

On success it logs `content ok enemies=4 waves=5 hash=<sha256 of the raw files, first 12 chars>`; with the variety data (V)
the line is `content ok enemies=18 waves=15 directives=60 hash=...` (the legacy fixture still logs the old line). The Android smoke
test greps `content ok` only, so it passes with both.
On failure it logs `ERROR: Content: <message>` per error (this fails tests and the smoke test by design).

`Strings` (`src/core/strings.gd`): `static func t(key: String) -> String` returns the text or the key itself
wrapped as `#key#` (and logs once per missing key); `static func tf(key: String, args: Array) -> String`.

---

## 6. Simulation (`src/sim/`)

### 6.1 Time and determinism

- Fixed **60 ticks per second** (`SimWorld.TICK_RATE`, also in the balance JSON; the loader rejects a mismatch).
- Every timer is an integer tick count. Fire cadence uses an integer accumulator (6.5).
- Randomness only through `SimRng` (seeded `RandomNumberGenerator` instances, one per named stream:
  `spawn`, `steer`, and (V) the streams of the table below). Adding a stream never disturbs the others.
- Positions are `float` (64-bit). Determinism is guaranteed for the same build on the same architecture.
- Ordering ties always break on the stable enemy id (monotonic from 1, never reused within a run).
- Commands are the only external input. They are applied at the start of the tick after they were submitted,
  in submission order, and recorded in `CommandLog` with their tick.
- **(V) The tick does not advance while the world is awaiting a choice** (4.1, 6.2): the tick count of a run is a function of
  the seed and the decisions only, never of thinking time.

**(V) Streams.** `SimRng.stream(name)` creates a stream on first use from `hash("<seed>|<name>")` and hashes every stream state,
so an indexed name such as `draft:7` needs no contract change. The state hash and the snapshot rows order the streams by name
**as text**, never by `StringName` order (that order follows pointers and changes once names are freed and made again, which would
fail the hash check of a resumed run in a new process). A stream is used for **one purpose and one index**, so the
decisions of one part of the run cannot shift the dice of another. Everything that can be decided before the run starts is
decided at tick 0 and stored in the `RunPlan` (6.4). `spawn` and `steer` keep their draw order (it is pinned by existing hashes);
new randomness never reuses them.

| Stream name | Drawn when | Decides |
|---|---|---|
| `spawn`, `steer` | as before | Spawn jitter, steering (unchanged) |
| `plan.boss` | tick 0 | Act I boss, act II boss, Node 9 variant |
| `plan.route:<w>` | tick 0, for w = 2..14 except boss waves | Both options of wave w: pack, modifier, reward, hot flags |
| `plan.wave:<w>:<o>` | tick 0 | Group counts and the group plan of option o of wave w |
| `plan.elite:<w>` | tick 0 | Which scheduled bodies are elites and their affixes |
| `plan.event:<w>` | tick 0 | The world events of wave w and their times |
| `plan.hazard:<act>` | tick 0 | Fuel drum points |
| `plan.patch:<directive>:<w>` | when `chorus_handshake`, `static_pact` or `open_gate` is taken | The patch of the remaining waves' plan |
| `kit` | tick 0 | Random items of `k_gambler` |
| `draft:<n>` | when offer n is made, and on its rerolls | The directives offered |
| `crate:<n>` | when crate n is secured | Its contents |
| `aim` | per shot that needs it | LMG strays (among the neighbours of the target and the fuel drums in reach), pellet scatter ties |
| `proc` | per trigger | `unstable_munitions`, `mine_layer` placement, reload jams |
| `event.place:<w>` | when a world event of wave w needs a place (V4-V) | Drop point, breach points, the rail line of a freight car |

Bots never touch a sim stream: the `random` bot owns an RNG seeded from `hash(seed, "bot")` outside the world.

**(V) Determinism rules for new code** (each is tested):

1. Area queries go through `SpatialHash.query` (already sorted by enemy id). Any list of victims is processed in id order.
2. Delayed effects sit in one queue ordered by (due tick, sequence number); at most 8 blasts resolve per tick (`max_blasts_per_tick`),
   the rest stay queued (a visible ripple, a bounded tick, and the same order on every device).
3. Every new state class implements `hash_into`; a test fails if a new field is not hashed (the "mutate one field, hash must
   change" pattern of `tests/unit/sim/test_stores.gd`).
4. No float accumulates across ticks where an integer can do it: heat, ward pools, fuses and timers are integers (milli-units or
   ticks).
5. The quality tier, the frame rate and the device never reach the sim (unchanged; `lint_layers.py` keeps enforcing it).

**(V) Reproducing a run.** A run is the tuple: build version, content hash (already logged by `Content`), `run_seed`, kit id,
the sorted list of unlocked ids (or the flag `daily`), and the command log. `Replay.run` with a `SimConfig` built from the
first five and the log gives the same `state_hash()` and `event_hash`. A bug report is the run file (7.5) with its tail.

### 6.2 `SimWorld` (Wave 0 writes it completely, including `step()`; systems are filled in by Wave 1)

```gdscript
class_name SimWorld extends RefCounted
const TICK_RATE: int = 60
const DT: float = 1.0 / 60.0

var config: SimConfig
var content: ContentSet                 # == config.content
var tick: int = 0
var phase: int = GameState.Id.PREPARING
var wave: int = 0                       # 0 while PREPARING, then 1..wave count (5 in the legacy fixture, 15 in the shipped game)
var waves_completed: int = 0
var phase_ticks_left: int = 0           # countdown in PREPARING and INTERMISSION, else 0
var core_hp: float
var core_max_hp: float
var shield_hp: float = 0.0              # > 0 only while the shield ability is active
var scrap: int = 0
var upgrade_levels: PackedInt32Array    # size 5, indexed by Ids.UP_*
var enemies: EnemyStore
var turrets: TurretStore
var warden: WardenState
var abilities: AbilityState
var nav: NavState                       # owned by nav systems
var combat: CombatState                 # owned by combat systems
var phase_state: PhaseState             # owned by flow systems
var rng: SimRng
var events: SimEvents
var stats: RunStats
var command_log: CommandLog
var next_enemy_id: int = 1
# (V) appended, all hashed (section 6.4); null/empty in the legacy fixture
var plan: RunPlan                       # built by RunPlanSystem.build(world) inside _init; null in the legacy fixture
var mods: ModState                      # flat typed stats recomputed when a directive, kit or modifier changes
var arsenal: ArsenalState               # weapon slots, active slot, swap, heat
var draft: DraftState                   # offers, pity counters, rerolls, buy-outs
var salvage: SalvageState               # crates on the field and the bank
var ext: EnemyExtState                  # per-enemy extra state (EnemyStore is frozen)
var hazards: HazardState                # the delayed-effect queue, pools, mines, drums
var events_state: EventState            # planned and called events
var boss: BossState                     # the alive boss's script state

func _init(cfg: SimConfig) -> void
func step() -> void                                   # exactly one tick; no-op when is_over(); (V) see the awaiting rule below
func submit(cmd: SimCommand) -> void                  # queue for the next tick
func is_over() -> bool                                # phase is VICTORY or DEFEAT
func result() -> int                                  # RunResult.Id
func state_hash() -> String                           # sha256 hex over all sim state (see StateHasher)
func summary(run_id: String) -> RunSummary

# shared mutators: the ONLY way these things may change
func set_phase(new_phase: int) -> void                # validates via GameStateMachine.can_transition; pushes PHASE_CHANGED
func add_scrap(delta: int) -> void                    # clamps at 0; pushes SCRAP_CHANGED; updates stats
func spawn_enemy(type_index: int, x: float, z: float) -> int      # store index, or -1 at capacity; pushes ENEMY_SPAWNED (+ BOSS_SPAWNED)
                                                      # (V) respects the class, type and elite caps
func kill_enemy(index: int, source: int) -> void      # exactly-once: no-op if not alive; scrap, stats, ENEMY_KILLED,
                                                      # NavSystemHooks.on_enemy_removed, store free
                                                      # (V) calls DeathHooks.on_killed (queues blasts, splits, crate credit; never recursion)
func set_core_hp(value: float) -> void                # clamps 0..max; pushes CORE_CHANGED

# read-only queries
func alive_count() -> int
func upgrade_cost(upgrade_index: int) -> int          # -1 at max level
func purchase_block_reason(upgrade_index: int) -> int # Reason.Id; OK when purchasable now
func ability_block_reason(ability_index: int) -> int
func boss_store_index() -> int                        # -1 when no boss alive
```

**Tick order** inside `step()` (fixed; Wave 0 implements it as calls to the static system functions). **(V)** The variety
milestone extends it to 16 steps; the unchanged steps keep their relative order, and the added systems have nothing to do in
the legacy fixture (no plan, no events, no boss script, no crates), so its behaviour is that of the old 11-step order:

```
 1  (awaiting and no command queued: return)        tick += 1
 2  CommandSystem.apply_queued                       # purchases, abilities, skip, (V) the draft, route, salvage, swap and call commands; in submission order
 3  PhaseSystem.pre_step                             # countdowns, breather countdown; PREPARING/INTERMISSION -> SPAWNING; wave start reads the chosen RouteOption
 4  EventSystem.step                                 # (V) warnings, starts, ends of planned and called events
 5  SpawnSystem.step                                 # scheduled spawns + pending queue, respecting the caps; (V) class, type and elite caps; breach spawns
 6  AbilitySystem.step                               # ability timers, stun and immunity countdowns, shield expiry; (V) lock by static_front, cooldown rate from jammers and modifiers
 7  StatusSystem.step                                # (V) slow, burn, ward regeneration, auras, reclaimer tethers
 8  MovementSystem.step                              # prev_x/prev_z copy, flow, separation, slots, stuck recovery; (V) mini path, standoff points, knockback, boss motion hooks
 9  WeaponSystem.step                                # Warden: target, fire, reload; (V) delegates to ArsenalSystem (active slot, off-hand, swap, heat)
10  TurretSystem.step                                # active turrets: target, fire; (V) offline timers, rate multipliers, turret hooks
11  HazardSystem.step                                # (V) delayed hits, blasts (max 8 per tick), pools, mines, drums
12  CoreAttackSystem.step                            # enemies in slots hit the core (shield first); (V) burnout hits, fuses, spitter bolts landing, core hooks
13  BossSystem.step                                  # (V) the alive boss's script
14  SalvageSystem.step                               # (V) crate progress
15  PhaseSystem.post_step                            # DEFEAT if core_hp <= 0 (after dead_mans_switch); SPAWNING -> CLEARING; CLEARING -> INTERMISSION/VICTORY; (V) the awaits
16  stats.sample                                     # peak alive per wave, duration
```

Of the old rule "steps 4 and 6 to 9 are skipped unless `GameState.is_combat(phase)`; step 5 runs in every non-terminal phase":
the old systems keep their guards (SpawnSystem, MovementSystem, WeaponSystem, TurretSystem and CoreAttackSystem run only in
combat; AbilitySystem runs in every non-terminal phase). Each new system documents its own guard in its class comment.

**(V) Awaiting.** `step()` returns before `tick += 1` when `phase_state.awaiting != NONE` and the command queue is empty. When a
command is queued it advances one tick, applies it, and stops again if still awaiting. Bots therefore answer on the next tick
and the tick count never depends on thinking time. `state_hash` adds the new states in a fixed order after the existing ones.
Store capacity is `enemy_cap + swarm_cap + 8` (98 with the shipped values 50, 40).

### 6.3 Config, commands, events, hashing, RNG

```gdscript
class_name SimConfig extends RefCounted
var run_seed: int
var content: ContentSet
var debug_invulnerable_core: bool = false
var debug_damage_mult: float = 1.0
var debug_start_scrap: int = 0
# (V) appended
var kit_index: int = 0                          # index into the kits of unlocks.json; 0 = k_standard
var unlocked: PackedStringArray                 # sorted ids of the unlocks in force (the pool of the run)
var daily: bool = false                         # the Daily Run: full pool, fixed kit
# (V5-A) appended: the debug starts of section 11, applied by DebugStart at tick 0
var debug_start_wave: int = 0                   # > 1: begin at this wave with a scripted build
var debug_boss: StringName = &""                # a BossDef or Node 9 variant id: begin at its boss wave
func has_unlock(unlock_id: String) -> bool      # daily or in `unlocked`
func is_debug() -> bool                         # any debug switch on: the run leaves no trace in the Archive
static func create(content_set: ContentSet, seed_value: int) -> SimConfig    # (V) keeps working: base pool, standard kit

class_name SimCommand extends RefCounted
enum Kind { PURCHASE, ABILITY, SKIP_INTERMISSION,
            PICK_DIRECTIVE, SKIP_DRAFT, REROLL, BUY_OUT, PATCH_CORE, PICK_ROUTE, SALVAGE, SWAP_WEAPON, CALL_EVENT }   # (V) 3..11 appended
var command_id: int            # unique per run, > 0
var kind: int
var arg: int                   # upgrade index or ability index; 0 for SKIP; (V) see the table below
var tick: int = -1             # filled in by SimWorld when applied
static func purchase(command_id_value: int, upgrade_index: int) -> SimCommand
static func ability(command_id_value: int, ability_index: int) -> SimCommand
static func skip(command_id_value: int) -> SimCommand
# (V) one static constructor per new kind, same style (pick_directive, skip_draft, reroll, buy_out, patch_core, pick_route,
# salvage, swap_weapon, call_event)

class_name CommandLog extends RefCounted
var entries: Array[SimCommand]                 # applied commands, in order, with tick set
func to_dicts() -> Array[Dictionary]           # [{tick, id, kind, arg}]
static func from_dicts(rows: Array) -> CommandLog

class_name SimEvent extends RefCounted
var kind: int; var tick: int; var a: int; var b: int; var f: float; var g: float

class_name SimEvents extends RefCounted
var event_hash: int = 0                        # rolling hash of every event ever pushed (determinism check)
var total: int = 0
func push(kind: int, a: int = 0, b: int = 0, f: float = 0.0, g: float = 0.0) -> void
func drain() -> Array[SimEvent]                # returns and clears the buffer; single consumer (RunController)
func peek() -> Array[SimEvent]                 # for tests

class_name SimRng extends RefCounted
func _init(run_seed: int) -> void
func stream(name: StringName) -> RandomNumberGenerator    # created on first use, seeded from hash(run_seed, name)
func hash_into(h: StateHasher) -> void

class_name StateHasher extends RefCounted
func put_int(v: int) -> void
func put_float(v: float) -> void
func put_ints(v: PackedInt32Array) -> void
func put_bytes(v: PackedByteArray) -> void
func put_floats(v: PackedFloat64Array) -> void
func finish() -> String                        # sha256 hex
```

`NavState`, `CombatState`, `PhaseState`, every store and `SimRng` implement `func hash_into(h: StateHasher) -> void`
and `SimWorld.state_hash()` calls them in a fixed order. A field that affects outcomes and is not hashed is a bug.

**(V) `SimCommand.arg` meanings of the new kinds** (legal states and results: 6.6; every answer is a `Reason.Id`):

| Kind | `arg` | Rule |
|---|---|---|
| `PICK_DIRECTIVE` | slot (0..N-1) | Applies the directive and closes the draft; with `rw_double_pick` the draft stays open for one more pick |
| `SKIP_DRAFT` | - | Closes the draft, +60 Scrap |
| `REROLL` | - | Free charge, else Scrap (`reroll_base + reroll_step * n`); not allowed after `mod_no_breather` |
| `BUY_OUT` | slot | Before picking: also keep this slot for Scrap; once per draft |
| `PATCH_CORE` | - | +10% core for Scrap; the price grows per use |
| `PICK_ROUTE` | option (0 or 1) | Starts the next wave from that `RouteOption` |
| `SALVAGE` | `choice * 16 + action` | action 0..2 = take in slot, 8 = level up, 9 = scrap it; `choice` selects the weapon of a boss crate |
| `SWAP_WEAPON` | slot | Swap takes `swap_seconds` with no fire |
| `CALL_EVENT` | event index | The player-triggered events: Deadfall Strike, Core Vent, Freight |

**Event kinds** (`src/sim/sim_event_kind.gd`, `class_name SimEventKind`, `enum Id`). Payload columns are the
`SimEvent` fields; unused ones are 0.

| Kind | a | b | f | g | Pushed by |
|---|---|---|---|---|---|
| `PHASE_CHANGED` | previous | current | | | `SimWorld.set_phase` |
| `WAVE_STARTED` | wave (1..wave count) | total enemies | | | PhaseSystem |
| `WAVE_CLEARED` | wave | | | | PhaseSystem |
| `INTERMISSION_STARTED` | wave just cleared | ticks | | | PhaseSystem |
| `ENEMY_SPAWNED` | enemy id | type index | x | z | `spawn_enemy` |
| `BOSS_SPAWNED` | enemy id | type index | | | `spawn_enemy` |
| `SHOT_FIRED` | source | target id | | | WeaponSystem, TurretSystem |
| `ENEMY_DAMAGED` | enemy id | source | amount | hp after | DamageResolver |
| `ENEMY_KILLED` | enemy id | source | x | z | `kill_enemy` |
| `SCRAP_CHANGED` | new value | delta | | | `add_scrap` |
| `CORE_HIT` | enemy id | type index | hp damage | absorbed | CoreAttackSystem |
| `CORE_CHANGED` | | | current | max | `set_core_hp` |
| `SHIELD_CHANGED` | | | current | max | AbilitySystem, CoreAttackSystem |
| `PURCHASE_RESOLVED` | command id | Reason | upgrade index | | EconomySystem |
| `UPGRADE_LEVEL_CHANGED` | upgrade index | new level | | | EconomySystem |
| `WEAPON_CHANGED` | weapon index | | | | EconomySystem |
| `TURRET_DEPLOYED` | pad index | | | | EconomySystem |
| `RELOAD_STARTED` | ticks | | | | WeaponSystem |
| `RELOAD_FINISHED` | | | | | WeaponSystem |
| `ABILITY_ACTIVATED` | ability index | command id | | | AbilitySystem |
| `ABILITY_ENDED` | ability index | | | | AbilitySystem |
| `ABILITY_REJECTED` | ability index | Reason | command id | | AbilitySystem |
| `ENEMY_STUNNED` | enemy id | ticks | | | AbilitySystem |
| `ENEMY_REACHED_SLOT` | enemy id | slot index | | | MovementSystem (relayed as `burster_armed` for an enemy with `fuse_s`) |
| `ENEMY_STUCK` | enemy id | recovery count | | | MovementSystem |
| `SPAWN_QUEUED` | pending count | | | | SpawnSystem |
| `RUN_FINISHED` | RunResult | waves completed | core hp | | PhaseSystem |
| **(V)** `ACT_STARTED` | act (1..3) | | | | PhaseSystem |
| `DRAFT_OFFERED` | offer ordinal | slot count | | | DraftSystem (the directive indices are read from `DraftState`) |
| `DIRECTIVE_PICKED` | directive index | stacks | | | DraftSystem |
| `DRAFT_REROLLED` | offer ordinal | | | | DraftSystem |
| `ROUTE_OFFERED` | wave | | | | PhaseSystem |
| `ROUTE_PICKED` | option | | | | PhaseSystem |
| `BOSS_BRIEFED` | boss index | | | | PhaseSystem |
| `AWAIT_CHANGED` | `Await` kind | | | | PhaseSystem |
| `CRATE_DROPPED` | | | x | z | SalvageSystem |
| `CRATE_SECURED` | | | | | SalvageSystem |
| `CRATE_LOST` | | | | | SalvageSystem |
| `SALVAGE_RESOLVED` | command id | Reason | | | SalvageSystem |
| `WEAPON_SWAPPED` | slot | weapon index | | | ArsenalSystem |
| `WEAPON_VENTED` | slot | | | | ArsenalSystem |
| `AREA_BLAST` | kind | radius in cm | x | z | HazardSystem, AreaDamage |
| `CHAIN_ARC` | from enemy id | to enemy id | | | fire kinds, HazardSystem |
| `DELAYED_HIT_LAUNCHED` | kind | ticks | x | z | HazardSystem |
| `POOL_STARTED`, `POOL_ENDED` | pool id | radius in cm | x | z | HazardSystem |
| `ELITE_SPAWNED` | enemy id | affix mask | | | EliteSystem |
| `ENEMY_SPLIT` | enemy id | | x | z | DeathHooks |
| `WARD_CHANGED` | enemy id | | fraction | | StatusSystem |
| `WARD_BROKEN` | enemy id | | | | StatusSystem |
| `ENEMY_HEALED` | enemy id | amount | | | DamageResolver (`heal`) |
| `EVENT_WARNED` | event index | ticks | x | z | EventSystem |
| `EVENT_STARTED`, `EVENT_ENDED`, `EVENT_CANCELLED` | event index | | | | EventSystem |
| `BOSS_TELEGRAPH` | attack | ticks | | | BossSystem |
| `BOSS_PHASE` | phase | | | | BossSystem |
| `CORE_HEALED` | | | amount | | ModSystem, HazardSystem |
| `CHARGES_CHANGED` | event index | charges | | | EventSystem |
| `COMMAND_REJECTED` | command id | Reason | | | CommandSystem |
| **(V5-A)** `WEAPON_CHARGING` | slot | wind-up ticks | line end x | line end z | FireLine.begin (the rail lance's charge starts) |
| **(V5-A)** `TURRET_REMOVED` | pad | | | | ModSystem (`single_point` takes the turrets away) |

**(V)** The existing kinds and their payloads are unchanged. Payload meanings given in SPEC 13.2 (`AREA_BLAST`, `CHAIN_ARC`,
`DELAYED_HIT_LAUNCHED`, `ELITE_SPAWNED`, `EVENT_WARNED`, `BOSS_TELEGRAPH`, `COMMAND_REJECTED`) are exact; the others follow the
arguments of the matching `Events` signal (7.1), the unused fields are 0, and the pushing system is the one named in the last
column. V1-S writes the final table into `sim_event_kind.gd` and this table is updated from it.

### 6.4 Stores (complete in Wave 0, frozen; a task that needs more state puts it in its own `*State` class)

```gdscript
class_name EnemyStore extends RefCounted
const ST_MOVING: int = 0
const ST_SEEK_SLOT: int = 1
const ST_ATTACKING: int = 2
var capacity: int                         # enemy_cap + 8; (V) enemy_cap + swarm_cap + 8 (the minis live in the same store)
var high_water: int = 0                   # iterate indices 0 .. high_water-1 and test alive[i]
var alive: PackedByteArray
var id: PackedInt32Array                  # stable id, 0 = empty
var type: PackedByteArray                 # Ids.EN_*
var x: PackedFloat64Array; var z: PackedFloat64Array
var prev_x: PackedFloat64Array; var prev_z: PackedFloat64Array      # position at the previous tick (interpolation)
var face_x: PackedFloat64Array; var face_z: PackedFloat64Array      # unit facing vector
var hp: PackedFloat64Array; var max_hp: PackedFloat64Array
var state: PackedByteArray
var slot: PackedInt32Array                # attack slot index or -1
var stun_ticks: PackedInt32Array          # > 0 = stunned (no move, no attack, attack timer frozen)
var stun_immune_ticks: PackedInt32Array
var attack_cd: PackedInt32Array           # ticks until the next core hit while ST_ATTACKING
var path_dist: PackedFloat64Array         # meters still to travel to the core ring (for ETA); 0 when attacking
var spawn_tick: PackedInt32Array
func _init(cap: int) -> void
func alloc() -> int                       # lowest free index, or -1
func free_index(i: int) -> void
func index_of(enemy_id: int) -> int       # -1 if not alive
func alive_count() -> int
func hash_into(h: StateHasher) -> void

class_name WardenState extends RefCounted
var x: float; var z: float
var weapon_index: int = 0
var magazine: int
var reload_ticks_left: int = 0
var fire_acc_milli: int = 0
var target_id: int = 0                    # 0 = none
var lock_ticks_left: int = 0
var aim_x: float; var aim_z: float        # last aim point (view uses it for yaw)
var shots_fired: int = 0
func hash_into(h: StateHasher) -> void

class_name TurretStore extends RefCounted     # exactly 2 pads
var active: PackedByteArray
var x: PackedFloat64Array; var z: PackedFloat64Array
var fire_acc_milli: PackedInt32Array
var target_id: PackedInt32Array
var lock_ticks_left: PackedInt32Array
var aim_x: PackedFloat64Array; var aim_z: PackedFloat64Array
func active_count() -> int
func hash_into(h: StateHasher) -> void

class_name AbilityState extends RefCounted    # indexed by Ids.AB_*
var cooldown_left: PackedInt32Array
var active_left: PackedInt32Array
func is_active(ability_index: int) -> bool
func is_ready(ability_index: int) -> bool     # cooldown_left == 0 and not active
func hash_into(h: StateHasher) -> void

class_name RunStats extends RefCounted
var kills_by_type: PackedInt32Array           # size 4; (V) sized from content (one entry per Ids.ENEMIES)
var peak_alive_by_wave: PackedInt32Array      # size 6, index = wave; (V) sized from content (wave count + 1)
var wave_start_tick: PackedInt32Array; var wave_clear_tick: PackedInt32Array
var scrap_earned: int; var scrap_spent: int; var core_damage_taken: float; var damage_absorbed: float
var stuck_recoveries: int; var max_pending: int
func sample(world: SimWorld) -> void

class_name RunSummary extends RefCounted
var run_id: String; var run_seed: int; var result: int; var waves_completed: int
var core_hp: int; var core_max_hp: int; var duration_ticks: int
var kills_by_type: PackedInt32Array; var peak_alive_by_wave: PackedInt32Array
var scrap_earned: int; var scrap_spent: int; var data_reward: int
```

**(V) Additions.** The five stores above are frozen: their field lists do not change (a task that needs more state puts it in
its own `*State` class, which is what the variety milestone does). `RunStats` and `RunSummary` gain, appended: `act_reached`,
`combat_ticks`, `directives: PackedInt32Array` (stacks per directive index), `weapons: PackedInt32Array`, `route_choices`,
`core_damage_by_type`, `damage_by_source` (size 7, indexed by `DamageSource.Id`), `events_seen`, `crates_secured`, `boss_ids`.
**(V5-A)** `RunStats.data: int` is the Recovered Data the run has banked (CONTENT 10: `reward.per_wave` and
`ModState.data_per_wave` at every wave cleared, `reward.boss_by_act` when an act boss dies, `rw_data` with the route
rewards; `RunStats.add_data` is the writer's door). It is not hashed (it changes no outcome) and the boundary snapshot carries
it with the rest of `RunStats`. `SimWorld.data_reward()` is the run's worth now: `stats.data`, plus `victory_base +
floor(victory_core_bonus x core / core max)` on a victory; `summary().data_reward` is that number, `GameRewards` pays it
unchanged, and a run file that cannot be resumed is closed with the `stats.data` of its boundary (`RunFile.closing_reward`).
The legacy content keeps `Formulas.data_reward`. `ArsenalState` gains `kill_chain_stacks` and `kill_chain_ticks` (hashed; the
kill chain no longer shares the bits of `shots_since_proc`).
`WardenState.weapon_index`, `magazine` and `reload_ticks_left` stay and mirror the active weapon slot, so the HUD, the view and
the old tests keep reading them.

New state classes, each with `hash_into`, `to_dict` and `from_dict` (the last two are exercised only at a wave boundary, for
resume, 7.5). One writer each: the system of the same name (6.6).

| Class | File | Holds |
|---|---|---|
| `RunPlan`, `PlannedWave`, `RouteOption`, `PlannedEvent`, `PlannedElite` | `sim/plan/` | The whole run decided at tick 0 (below) |
| `DraftState` | `sim/stores/draft_state.gd` | The current offer, pity counters, rerolls and buy-outs used, free reroll charges |
| `ModState` | `sim/stores/mod_state.gd` | A flat set of typed fields (the `ops[]` stats) recomputed when a directive, kit or modifier changes |
| `ArsenalState` | `sim/stores/arsenal_state.gd` | Slots (weapon index, level, magazine, reload, heat, vent), the active slot, the swap timer, the charge timer |
| `HazardState` | `sim/stores/hazard_state.gd` | The delayed-effect queue ordered by (due tick, sequence number), pools, mines, drums |
| `EnemyExtState` | `sim/stores/enemy_ext_state.gd` | Parallel arrays per enemy store index: `flags`, `affix_mask`, `ward_milli`, `ward_regen_cd`, `slow_ticks`, `slow_milli`, `burn_ticks`, `burn_milli`, `shred_milli`, `fuse_ticks`, `aux_cd`, `anchor_point`, `hp_scale_milli` |
| `SalvageState` | `sim/stores/salvage_state.gd` | Crates on the field and the bank |
| `EventState` | `sim/stores/event_state.gd` | Planned and called events, charges, the cooldown of the world events |
| `BossState` | `sim/stores/boss_state.gd` | The alive boss's phase and timers |

```gdscript
class_name RunPlan extends RefCounted          # built by RunPlanSystem.build(world) inside SimWorld._init; hashed
var boss_ids: PackedInt32Array                 # enemy index per act
var boss_variant: int
var waves: Array[PlannedWave]                  # index 0 = wave 1
class_name PlannedWave extends RefCounted
var index: int; var act: int; var is_boss: bool
var options: Array[RouteOption]                # 1 (fixed or boss) or 2
var events: Array[PlannedEvent]                # event index, start tick offset
class_name RouteOption extends RefCounted
var pack_index: int; var modifier_index: int   # -1 = none
var reward_index: int; var hot: bool
var groups: Array[SpawnGroupDef]               # the existing def: SpawnSystem consumes it unchanged
var elites: Array[PlannedElite]                # group, ordinal, affix mask
```

Directives that change the future (`chorus_handshake`, `static_pact`, `open_gate`) patch the plan of the remaining waves with
their own indexed streams (`plan.patch:<directive>:<w>`, 6.1), so the patch is also reproducible. Both options of every wave
are generated at the start, so what the route screen shows is exactly what spawns and a choice at wave 3 never changes what
wave 7 offers.

### 6.5 Formulas (`src/sim/formulas.gd`, complete with tests in Wave 0)

```gdscript
class_name Formulas extends RefCounted
static func ticks(seconds: float) -> int                              # roundi(seconds * 60)
static func upgrade_cost(base_cost: int, growth: float, level: int) -> int
    # floori(base_cost * pow(growth, level) + 0.5 + 1e-9)
static func effective_armor(armor: float, piercing_level: int, per_level: float, cap: float) -> float
    # max(0, armor * (1 - min(cap, per_level * piercing_level)))
static func hit_damage(base_damage: float, damage_level: int, per_level: float, eff_armor: float) -> float
    # max(1, base_damage * (1 + per_level * damage_level) - eff_armor)
static func sps_milli(base_sps_milli: int, fire_rate_level: int, per_level: float, mult_milli: int) -> int
    # roundi(base_sps_milli * (1 + per_level * fire_rate_level) * mult_milli / 1000.0)
static func data_reward(result: int, waves_completed: int, core_hp: float, m: MissionDef) -> int
    # VICTORY: base + floori(core_hp / divisor);  DEFEAT: per_wave * waves_completed;  else 0
```

Golden values that tests must assert: costs `damage` 175, 298, 506, 860, 1462; `fire_rate` 150, 240, 384, 614,
983; `armor_piercing` 200, 360, 648, 1166, 2100; `auto_turret` 350, 700; `smg_unlock` 300.
`hit_damage(30, 0, 0.2, 8) = 22`; `hit_damage(15, 0, 0.2, 12) = 3`; `hit_damage(12, 0, 0, 12) = 1`;
`effective_armor(12, 5, 0.15, 0.9) = 3.0`; `effective_armor(12, 6, 0.15, 0.9) = 1.2`.

**Fire cadence** (Warden and turrets): each tick `fire_acc_milli += sps_milli`; while
`fire_acc_milli >= 60000` and a shot is allowed, fire one shot and subtract 60000. If no shot is allowed
(no target, reloading, empty) the accumulator is clamped to 60000 so the first shot after a pause is
immediate but never a burst.

**(V) Unchanged and added.** Every function and golden value above stays true; the three stat directives call them with the
stack count as the level (`hot_loads` x3 gives `Formulas.hit_damage` with `damage_level = 3`, the golden values included).
`Formulas.upgrade_cost` and its golden tests stay for the legacy fixture. The prices of the draft screen are plain linear data
in `run.json` `draft{}` (`reroll_base + reroll_step * n`, likewise buy-out and patch), not `upgrade_cost`.

Damage order (one place, `DamageResolver`): weapon damage x weapon level (`level_mult`) x the `hot_loads` formula (unchanged
`Formulas.hit_damage`) x conditional multipliers (full HP, low HP, stunned) - effective armor (unchanged formula; LMG shred and
`armor_ignore` reduce the armor first) x ward and shieldbearer reductions x `debug_damage_mult`.

Integer rules: heat, ward pools, fuses and timers are integers (milli-units or ticks); no float accumulates across ticks where
an integer can do it (6.1). A heat weapon adds `heat_per_shot` per shot, vents for `vent_s` at `heat_cap` and restarts at 0, and
cools by `cool_per_s` whenever it is not firing (a holstered weapon cools at full speed and reloads at `holster_reload_mult`).

### 6.6 System contracts

Every system is a class of static functions taking `world: SimWorld`. Wave 0 creates each file with these
signatures and TODO bodies that compile and do nothing.

**Field ownership (one writer):**

| Field(s) | Writer |
|---|---|
| `phase`, `wave`, `waves_completed`, `phase_ticks_left` | PhaseSystem (via `set_phase`) |
| `enemies.x/z/prev_*/face_*/state/slot/path_dist`, `nav` | MovementSystem, SpawnSystem (initial values) |
| `enemies.hp` | DamageResolver |
| `enemies.attack_cd`, `core_hp` (via `set_core_hp`), `shield_hp` (decrease only) | CoreAttackSystem |
| `enemies.stun_ticks`, `stun_immune_ticks`, `abilities`, `shield_hp` (set and clear) | AbilitySystem |
| `warden.magazine/reload/fire_acc/target/lock/aim/shots_fired`, `turrets.fire_acc/target/lock/aim`, `combat` | WeaponSystem, TurretSystem |
| `scrap` (debit), `upgrade_levels`, `warden.weapon_index` (+ magazine reset on swap), `turrets.active` | EconomySystem |
| `scrap` (credit), enemy alloc and free | `SimWorld.add_scrap`, `spawn_enemy`, `kill_enemy` |
| `stats.core_damage_taken`, `stats.damage_absorbed` | CoreAttackSystem (added at the Wave 1 merge; no writer was listed) |
| `stats.stuck_recoveries` | MovementSystem (added at the Wave 1 merge) |
| `stats.max_pending` | SpawnSystem (added at the Wave 1 merge) |
| `stats.wave_start_tick`, `stats.wave_clear_tick` | PhaseSystem |
| **(V)** `plan` | RunPlanSystem (built once, then read-only; plan patches by ModSystem through their own streams) |
| `phase_state.awaiting`, `act`, `breather` | PhaseSystem |
| `draft` | DraftSystem |
| `mods` | ModSystem |
| `arsenal`, `warden.weapon_index/magazine/reload` (mirrors of the active slot) | ArsenalSystem (WeaponSystem delegates to it) |
| `hazards` | HazardSystem |
| `ext` | StatusSystem (affix and status fields set at spawn by EliteSystem and SpawnSystem) |
| `salvage` | SalvageSystem |
| `events_state` | EventSystem |
| `boss` | BossSystem |
| `enemies.hp` stays written only by `DamageResolver` (heals included, through `DamageResolver.heal`) | DamageResolver |
| **(V5-A)** `stats.data` (Recovered Data banked, 6.4 RunStats) | `RunStats.add_data`, called by PhaseAwaits (a wave cleared), DeathHooks (an act boss killed) and ModSystem.grant (`rw_data`) |
| `arsenal.kill_chain_stacks`, `kill_chain_ticks`, `shots_since_proc` | ShotHooks (the kill chain and the pistol's perk counter; ArsenalSystem ticks them) |
| The active magazine emptied by a Tremor Rig stomp | ArsenalFire.dump_magazine (BossEffects asks for it) |
| `events_state.turret_offline_ticks` | EventSystem.take_turrets_offline (the brownout, `mod_low_power` through ModSystem, the stomp through BossEffects) |
| `turrets.active` cleared by `single_point` | ModSystem (pushes `TURRET_REMOVED` per pad); EconomySystem.sync_turrets deploys |

**(V) Stated exceptions to the one-writer rule** (each is one class that owns the moment; nothing else writes these fields
at that time):

| Fields | Second writer | When, and why it is safe |
|---|---|---|
| A boss body and its parts in `enemies`: `state`, `attack_cd`, `x`, `z`, `face_*`, `path_dist`, `stun_ticks` | `BossEffects` (`park`, `carry`, `advance`, `extend_stun`, `cap_attack_cd`, `restart_attack`) | Tick step 13, after movement and core attacks. A parked body counts as attacking with no slot, so MovementSystem and the stuck recovery leave it alone; the Lance Platform's standoff parking and the Aegis pylons' orbit are the boss script's, never the standoff code's |
| `enemies.x/z` of a pushed enemy, and `state`, `attack_cd` of a pushed attacker | `EventPush.away` (Core Vent, Runaway Freight) | Inside the event's own tick; the full distance for every mass (CONTENT 6), clamped to the yard. An attacker thrown back keeps its slot and walks to it again |
| `enemies.x/z` of the squatters of an Accord Drop | `EventSupplyDrop.steer` (HazardSystem.step) | After MovementSystem in the same tick: the squatter's position of this tick is replaced by a step toward the crate ring |
| `enemies.x/z` of a body shoved by the scattergun, the Core Vent's and the freight's other callers | `MovementSystem.knockback` | The owner's own call point: `FireCone.shove` gates (mass below 3, not attacking, not ANCHORED) and calls it |

The boss, squatter and push writes were found by the V4 reviews; V5-A moved what was cheap to the owner (the magazine dump,
the turret outage, the scattergun shove) and records the rest here instead of hiding it.
| `core_hp` gains two writers, both through `set_core_hp` | HazardSystem (the Core Vent price), ModSystem (max changes, repairs) |

**Nav and spawn (task W1-A)**

```gdscript
class_name ArenaGrid extends RefCounted
var cols: int; var rows: int; var origin_x: float; var origin_z: float; var cell_m: float
var blocked: PackedByteArray
static func build(arena: ArenaDef, inflate: float) -> ArenaGrid
func cell_of(x: float, z: float) -> int          # clamped
func cell_center(cell: int) -> Vector2

class_name FlowField extends RefCounted
var grid: ArenaGrid
var cost: PackedFloat32Array                     # meters to the approach circle; INF when unreachable
var dir_x: PackedFloat32Array; var dir_z: PackedFloat32Array
static func build(arena: ArenaDef) -> FlowField  # Dijkstra, 8-connected, no corner cutting; goal = cells inside approach_radius
func sample_dir(x: float, z: float) -> Vector2
func sample_cost(x: float, z: float) -> float
func unreachable_spawn_cells(arena: ArenaDef) -> int      # must be 0 (validator)

class_name SpatialHash extends RefCounted
func rebuild(store: EnemyStore) -> void
func query(x: float, z: float, radius: float, out: PackedInt32Array) -> int   # fills `out` with store indices sorted by enemy id; returns count

class_name AttackSlots extends RefCounted
func claim(world: SimWorld, enemy_index: int) -> int      # lowest ring with a free run of `slot_span`; nearest in ring; tie -> lower index; -1 never happens when slots >= cap + 2
func release(world: SimWorld, enemy_index: int) -> void
func occupant(slot_index: int) -> int                     # enemy id or 0

class_name NavState extends RefCounted           # holds FlowField, SpatialHash, AttackSlots, spawn schedule, pending queue, stuck trackers
func hash_into(h: StateHasher) -> void

class_name SpawnSystem
static func begin_wave(world: SimWorld, wave_index: int) -> void    # builds the tick-ordered schedule (group order, ordinal)
    # (V) signature FROZEN: reads the groups of the chosen RouteOption instead of content.waves[n - 1] when world.plan exists
static func step(world: SimWorld) -> void
static func is_wave_fully_spawned(world: SimWorld) -> bool          # schedule exhausted AND pending queue empty
static func pending_count(world: SimWorld) -> int

class_name MovementSystem
static func step(world: SimWorld) -> void

class_name NavSystemHooks
static func init_world(world: SimWorld) -> void                     # called from SimWorld._init
static func on_enemy_removed(world: SimWorld, enemy_index: int) -> void   # releases the slot
```

Behavior that tests pin down: stunned enemies do not move; `prev_x/prev_z` hold last tick's position; an
enemy outside `approach_radius` follows the flow field (Rushers with a clear straight line seek the core
directly); inside it, the enemy claims a slot (`ST_SEEK_SLOT`) and walks to it; within 0.25 m it snaps,
becomes `ST_ATTACKING`, sets `attack_cd = attack_period_ticks`, pushes `ENEMY_REACHED_SLOT`; separation uses
at most 6 neighbors; per-tick displacement never exceeds `1.5 * speed_mps * DT`; no enemy center ends a tick
inside an obstacle; positions are always finite and inside the grid; an enemy with less than
`stuck_min_progress_m` of path progress over `stuck_ticks` while `ST_MOVING` or `ST_SEEK_SLOT` gets
`ENEMY_STUCK` and a deterministic recovery (ignore separation for 120 ticks, and if still stuck move to the
nearest free cell center with lower flow cost). Enemies are never removed by nav code. Spawn position for
(wave, group, ordinal) = point on the region segment at `t = fract(ordinal * 0.618034 + jitter)` with
`jitter` in `[-0.08, 0.08]` from the `spawn` stream; at most `max_spawns_per_tick` spawns per tick; when
`alive_count() >= enemy_cap` the spawn goes to the FIFO pending queue (`SPAWN_QUEUED`). **(V)** The queue also enforces the mini
cap (`swarm_cap`, a second counter), the per-type cap (`alive_cap`, equal to the size of that type's view pool) and the elite cap
(4): a spawn that cannot enter waits FIFO, nothing is dropped. Shards that do not fit join the same queue at the splitter's
death position. The attack slots stay 64 (the validator rule `slots >= enemy_cap + 2` is unchanged): minis and standoff types
take no slot.

**Combat (task W1-B)**

```gdscript
class_name Targeting
static func pick(world: SimWorld, from_x: float, from_z: float, range_m: float) -> int   # enemy id or 0
static func is_valid(world: SimWorld, enemy_id: int, from_x: float, from_z: float, range_m: float) -> bool
static func compare(world: SimWorld, i: int, j: int, from_x: float, from_z: float) -> bool  # true if store index i outranks j

class_name DamageResolver
static func hit(world: SimWorld, enemy_index: int, base_damage: float, damage_level: int, source: int) -> float
    # applies Formulas with the current armor_piercing level and debug_damage_mult; clamps hp at 0;
    # pushes ENEMY_DAMAGED; calls world.kill_enemy at hp <= 0; returns damage dealt

class_name WeaponSystem
static func step(world: SimWorld) -> void
static func current_sps_milli(world: SimWorld) -> int

class_name TurretSystem
static func step(world: SimWorld) -> void

class_name CoreAttackSystem
static func step(world: SimWorld) -> void

class_name CombatState extends RefCounted
func hash_into(h: StateHasher) -> void
```

Rules: rank order is (1) `state == ST_ATTACKING`, (2) lower `floor(eta_ticks / eta_bucket_ticks)` where
`eta_ticks = path_dist / (speed_mps * DT)`, (3) `priority_class`, (4) smaller squared distance to the
shooter, (5) lower id. A shooter keeps its target while `lock_ticks_left > 0` and the target is valid (alive,
in range); when the lock expires it re-picks and resets the lock to `lock_ticks`. An invalid target is
dropped at once and a new pick is made the same tick. Warden: one shot costs one round; at 0 rounds a reload
of `reload_ticks` starts (`RELOAD_STARTED`), no shots during it, then the magazine is full
(`RELOAD_FINISHED`). Overdrive doubles `sps_milli` and does not skip reloads. Turrets: no magazine, damage
level 0, their own range, `source = TURRET_0 + pad`. Shots are hitscan and ignore obstacles. Core attacks:
for each alive enemy with `ST_ATTACKING` and `stun_ticks == 0`, `attack_cd -= 1`; at 0, deal `core_damage`
(shield first: reduce `shield_hp`, push `SHIELD_CHANGED`; remainder through `set_core_hp`, unless
`debug_invulnerable_core`), push `CORE_HIT`, reset `attack_cd`. Enemies are processed in ascending id order.

**Economy, abilities, flow (task W1-C)**

```gdscript
class_name CommandSystem
static func apply_queued(world: SimWorld) -> void      # dedups command_id (DUPLICATE_COMMAND); one PURCHASE per upgrade per tick

class_name EconomySystem
static func purchase(world: SimWorld, command_id: int, upgrade_index: int) -> int    # Reason.Id; pushes PURCHASE_RESOLVED always
static func block_reason(world: SimWorld, upgrade_index: int) -> int
static func cost(world: SimWorld, upgrade_index: int) -> int

class_name AbilitySystem
static func activate(world: SimWorld, command_id: int, ability_index: int) -> int    # Reason.Id; pushes ACTIVATED or REJECTED
static func block_reason(world: SimWorld, ability_index: int) -> int
static func step(world: SimWorld) -> void
static func end_all(world: SimWorld) -> void           # W3-A: the run ended; every active ability ends now (ABILITY_ENDED, SHIELD_CHANGED)

class_name PhaseSystem
static func init_world(world: SimWorld) -> void        # PREPARING with prepare_ticks
static func pre_step(world: SimWorld) -> void
static func post_step(world: SimWorld) -> void
static func skip_intermission(world: SimWorld) -> int  # Reason.Id

class_name PhaseState extends RefCounted
func hash_into(h: StateHasher) -> void
```

Rules: purchases are legal in PREPARING, SPAWNING, CLEARING and INTERMISSION (else `WRONG_STATE`); **(V)** when
`mission.shop_enabled` is false (the shipped mission) `EconomySystem.purchase` answers `Reason.Id.SHOP_CLOSED` and changes
nothing; check
order is state, id, max level, `min_wave` (`PREREQ_NOT_MET` while `world.wave < min_wave`), funds; on success
debit exactly once, raise the level, apply the effect (TURRET activates the next pad; WEAPON_UNLOCK sets
`warden.weapon_index`, fills the magazine, clears a reload), push `UPGRADE_LEVEL_CHANGED`. Abilities are
legal only in SPAWNING and CLEARING. EMP: every alive enemy with `stun_immune_ticks == 0` gets
`stun_ticks = max(stun_ticks, def stun)` (boss uses `boss_stun_ticks`); when a boss stun reaches 0 its
`stun_immune_ticks = boss_immunity_ticks`. Shield: `shield_hp = absorb` for `duration_ticks`; it ends when
time runs out or `shield_hp <= 0`; then `shield_hp = 0`, `ABILITY_ENDED`, cooldown starts. Overdrive:
`active_left = duration_ticks`; cooldown starts when it ends. EMP cooldown starts at activation. Phases:
PREPARING counts `prepare_ticks` then wave 1 SPAWNING (`WAVE_STARTED`); SPAWNING to CLEARING when
`SpawnSystem.is_wave_fully_spawned`; CLEARING to INTERMISSION when `alive_count() == 0` (`WAVE_CLEARED`,
`waves_completed += 1`, `INTERMISSION_STARTED`), or to VICTORY after the last wave (5 in the legacy fixture, 15 in the shipped
game, taken from the plan); INTERMISSION counts `intermission_ticks` (or is skipped) then the next wave (**(V)** with a plan it
instead passes through the awaits of 4.1 and the 180-tick breather); DEFEAT the tick `core_hp <= 0`, from SPAWNING or
CLEARING, checked before the wave-clear check. Terminal phases push `RUN_FINISHED` once, after
`AbilitySystem.end_all` (W3-A: `step()` is a no-op after the run, so an ability still active at the last tick would
otherwise stay active forever; ending it pushes `ABILITY_ENDED` and, for the shield, `SHIELD_CHANGED` 0).

**(V) Systems of the variety milestone.** Same convention: a class of static functions taking `world: SimWorld`, every file a
compiling stub with the final signature until its owning task fills it (WORK_PLAN section 8). Contracts that change or are added:

```gdscript
class_name RunPlanSystem          # sim/systems/run_plan_system.gd
static func build(world: SimWorld) -> void              # tick 0: the whole RunPlan from the plan.* streams; WaveBuilder turns packs into SpawnGroupDef
class_name PhaseSystem            # EXT: awaits (4.1), acts, breather; wave count from the plan (content.waves.size() in the legacy fixture). Wave-count readers: `PhaseSystem.wave_count`, `RunApi.wave_count`, `RunRoster.wave_count` (`src/ui/screens/run_roster.gd`: the briefing and results rosters of a generated run)
class_name DraftSystem            # offers (seeded, weighted, no duplicates, pity), reroll, buy-out, skip, patch
class_name ModSystem              # interprets ops[]; recomputes ModState; applies kits, directives, modifiers, affixes
class_name ArsenalSystem          # slots, swap, heat, vent; dispatches on WeaponDef.kind to sim/systems/fire/fire_*.gd
class_name AreaDamage
static func blast(world: SimWorld, x: float, z: float, radius: float, damage: float, edge_frac: float, flags: int, source: int) -> void
class_name HazardSystem           # the delayed-effect queue, pools, mines, drums; step(world)
class_name StatusSystem           # slow, burn, ward regeneration, auras, reclaimer tethers; step(world)
# (V5-A) The jammer's two rates reach the game ONCE, through EventRates (ability cooldown tick: AbilitySystem; turret cadence:
# EventRates.turret_rate_milli, which TurretSystem reads). StatusSystem.cooldown_rate / turret_rate_mult are the same numbers as
# plain queries (only unit tests call them): no system multiplies by them, so nothing is applied twice.
class_name DeathHooks / CoreHooks / ShotHooks    # one function per HOOK directive of CONTENT 3 (e.g. DeathHooks.on_killed)
class_name EliteSystem            # applies affixes at spawn; aura and leech rules
class_name EventSystem            # sim/systems/event_system.gd + events/event_<id>.gd (10 files); step(world)
class_name BossSystem             # sim/systems/boss_system.gd + bosses/boss_<id>.gd (5 files); step(world)
class_name SalvageSystem          # crates on the field, the bank, crate contents; step(world)

# Targeting: the signatures of 6.6 "Combat" are FROZEN. is_valid and compare read world.ext for MAGNETIC, SHROUDED and the mini rule.
class_name Targeting
static func pick_cluster(world: SimWorld, x: float, z: float, min_range: float, max_range: float, radius: float) -> Vector2
static func pick_many(world: SimWorld, x: float, z: float, range_m: float, n: int, out: PackedInt32Array) -> int

# DamageResolver: hit(...) is FROZEN (it calls the new path with no flags).
class_name DamageResolver
const F_IGNORE_ARMOR; const F_HALF_ARMOR; const F_AREA; const F_NO_WARD; const F_BURN     # the `flags` bit set; values fixed by V1-S
static func hit_ex(world: SimWorld, enemy_index: int, amount: float, flags: int, source: int) -> float
static func heal(world: SimWorld, enemy_index: int, amount: float) -> void    # still the only writer of enemies.hp
```

Other changed contracts: `SpawnSystem.begin_wave` (above) keeps its signature; `EconomySystem.purchase` answers `SHOP_CLOSED`
(above); `SimConfig` gains the fields of 6.3; the `CommandSystem` handles the nine new kinds, answers a `Reason.Id` for each
(`NOT_AWAITING`, `INVALID_CHOICE`, `NO_CHARGES`, `LOCKED_BY_EVENT`, `INSUFFICIENT_SCRAP`, `ON_COOLDOWN`, `WRONG_STATE`) and pushes
`COMMAND_REJECTED` on failure. A draft, route or salvage command is legal only while the matching `Await` step is pending; an ability only in
SPAWNING and CLEARING, and a call (`CALL_EVENT`) only during a wave. The mini rule of `Targeting`: a mini is never the Warden's target
while a bodied enemy is in range and attacking, or closer to the core by ETA bucket. Delayed hits (mortar shells, missiles,
spitter bolts, strikes) are queue entries of `HazardState`; none uses physics.

What stays frozen in the sim: `EnemyStore`, `TurretStore`, `AbilityState` and `WardenState` field lists; `Formulas` (all
functions and golden values); `SimRng`, `StateHasher`, `SimEvents`, `CommandLog`; the signature of `Replay.run` (6.7); the fire
cadence accumulator; the flow field, spatial hash and attack slots; the 60-tick rate.

### 6.7 Replay and bot (task W2-D)

```gdscript
class_name Replay extends RefCounted
static func run(config: SimConfig, log: CommandLog, max_ticks: int) -> SimWorld      # re-submits each command at its tick
    # (V) signature unchanged; the loop gains one guard: it returns when the world is awaiting a choice and no logged command
    # remains (a truncated log would otherwise spin forever, because the tick does not advance). Resume relies on the same stop.
class_name PolicyBot extends RefCounted
enum Policy { NONE, GREEDY,
              RANDOM, HOARDER, SPAMMER, TURRET_RUSH, BALANCED, RISK }    # (V) 2..7 appended; parameters in CONTENT 13
func _init(policy_value: int) -> void
func act(world: SimWorld) -> void       # submits commands; deterministic; GREEDY = cheapest affordable upgrade by a fixed
                                        # priority, EMP when >= 12 enemies are attacking, shield when core is hit, overdrive when the boss is alive
var id_source: Callable                 # W3-A, optional func() -> int minting command ids; Game sets it to RunApi.next_command_id so
                                        # the bot and the HUD share one counter (default: the bot's own 1, 2, 3, ...)
```

**(V) Policies, scorecard, snapshot.** `PolicyBot.Policy` grows from `{NONE, GREEDY}` to eight policies: `none`, `greedy` (the old
"cheapest first" habit: lowest rarity, leftmost, standard route), `random`, `hoarder` (weapons), `spammer` (abilities),
`turret_rush`, `balanced` (the reference competent player) and `risk` (hot routes and corrupted directives). Each is one file
under `src/sim/ai/` (`policy_*.gd`) implementing `act(world)`; all are deterministic and none reads a sim stream. The `random`
bot owns an RNG seeded from `hash(seed, "bot")` outside the world. `scorecard.gd` computes the S1 to S18 metrics of GDD 8.4
from run summaries and `build_signature.gd` computes a run's build signature (primary weapon by damage dealt plus the two tags
with most stacks); `tools/scorecard_run` prints the verdict (section 12).

**Snapshot and tail resume.** Every state class of 6.4 has `to_dict` and `from_dict`, exercised only at a wave boundary, when
the world is almost empty (no enemies, no hazards, no pending spawns). Resume restores the boundary snapshot, verifies its
`state_hash`, re-submits the saved command tail with `Replay`-style stepping up to `resume_tick`, then shows the pause overlay.
If the hash check fails the game falls back to a full `Replay.run` from tick 0 (the test oracle and last resort); if that fails
too, or the build or content changed, the run is closed and paid as a defeat at the last saved wave. The file format is in 7.5.

---

## 7. Game layer (`src/core/`, `src/game/`)

### 7.1 Event bus (`Events` autoload, `src/core/event_bus.gd`, complete in Wave 0; (V) extended once by V1-S, append only)

The handoff's ten signals are adopted with the same names. Payload types are made explicit; enemy kind and
upgrade/ability ids are `StringName`; `source` is `DamageSource.Id`; `reason` is `Reason.Id`.

```gdscript
# --- handoff signals (adopted) ---
signal state_changed(previous: int, current: int)                 # GameState.Id, application-level (includes PAUSED)
signal wave_started(index: int)
signal enemy_spawned(id: int, kind: StringName)
signal enemy_damaged(id: int, amount: float, source: int)
signal enemy_killed(id: int, source: int)
signal scrap_changed(value: int)
signal core_changed(current: float, max_value: float)
signal purchase_resolved(command_id: int, success: bool, reason: int)
signal ability_activated(id: StringName)
signal run_finished(result: int, run_id: String)
# --- additions ---
signal run_started(run_id: String, run_seed: int)
signal wave_cleared(index: int)
signal intermission_started(wave_cleared: int, ticks: int)
signal boss_spawned(id: int, kind: StringName)
signal shot_fired(source: int, target_id: int)
signal enemy_died_at(id: int, kind: StringName, x: float, z: float, scrap: int)
signal core_hit(enemy_id: int, kind: StringName, hp_damage: float, absorbed: float)
signal shield_changed(current: float, max_value: float)
signal upgrade_level_changed(id: StringName, level: int)
signal weapon_changed(id: StringName)
signal turret_deployed(pad: int)
signal reload_started(ticks: int)
signal reload_finished()
signal ability_ended(id: StringName)
signal ability_rejected(id: StringName, reason: int)
signal enemy_stunned(id: int, ticks: int)
signal enemy_stuck(id: int)
signal profile_changed()
signal settings_changed(key: StringName)
signal hint_requested(key: String)
# --- (V) variety milestone, appended once by V1-S; GameEventRelay maps the new sim events to them ---
signal act_started(act: int)
signal await_changed(kind: int)                                   # PhaseState.Await
signal draft_offered(ids: Array[StringName])
signal directive_picked(id: StringName, stacks: int)
signal route_offered()
signal route_picked(option: int)
signal crate_dropped(x: float, z: float)
signal crate_secured()
signal crate_lost()
signal salvage_offered()
signal weapon_swapped(slot: int, id: StringName)
signal weapon_vented(slot: int)
signal area_blast(kind: int, x: float, z: float, radius: float)
signal chain_arc(from_id: int, to_id: int)
signal delayed_hit(kind: int, x: float, z: float, ticks: int)
signal pool_changed(id: int, x: float, z: float, radius: float, on: bool)
signal elite_spawned(id: int, kind: StringName, affixes: Array[StringName])
signal ward_changed(id: int, fraction: float)
signal event_warned(id: StringName, ticks: int, x: float, z: float)
signal event_started(id: StringName)
signal event_ended(id: StringName)
signal boss_telegraph(attack: int, ticks: int)
signal boss_phase(phase: int)
signal charges_changed(id: StringName, n: int)
signal command_rejected(command_id: int, reason: int)
signal unlock_purchased(id: StringName)                           # emitted by Save/Game, not by the sim
signal burster_armed(id: int)                                     # the relay makes it from ENEMY_REACHED_SLOT of an enemy with fuse_s
# (V5-A) appended
signal weapon_charging(slot: int)                                 # WEAPON_CHARGING: the rail lance began its wind-up (audio: rail_charge)
signal turret_removed(pad: int)                                   # TURRET_REMOVED: single_point took the turret of that pad
```

`RunController` is the only emitter of the gameplay signals. It drains `sim.events` after the ticks of each
frame and emits in order. Subscribers must not assume a signal arrives on the tick it happened, only in order.

### 7.2 Run API (the UI's only door to gameplay; `src/game/run_api.gd`, complete in Wave 0; (V) extended once by V1-S, append only)

```gdscript
class_name RunApi extends RefCounted
# commands (handoff: purchase_upgrade, activate_ability, skip_intermission, pause, resume)
func next_command_id() -> int
func purchase_upgrade(command_id: int, upgrade_id: StringName) -> void
func activate_ability(command_id: int, ability_id: StringName) -> void
func skip_intermission() -> void
func pause() -> void
func resume() -> void
# queries (cheap; the HUD polls them at 10 Hz and on signals)
func is_paused() -> bool
func phase() -> int
func wave() -> int
func wave_count() -> int
func phase_ticks_left() -> int
func core_hp() -> float
func core_max_hp() -> float
func shield_hp() -> float
func shield_max() -> float
func scrap() -> int
func upgrade_level(id: StringName) -> int
func upgrade_max_level(id: StringName) -> int
func upgrade_cost(id: StringName) -> int                 # -1 at max
func purchase_block_reason(id: StringName) -> int        # Reason.Id
func ability_block_reason(id: StringName) -> int
func ability_cooldown_left(id: StringName) -> int        # ticks
func ability_cooldown_total(id: StringName) -> int
func ability_active_left(id: StringName) -> int
func ability_active_total(id: StringName) -> int
func weapon_id() -> StringName
func magazine() -> int
func magazine_size() -> int
func reload_ticks_left() -> int
func alive_count() -> int
func pending_spawn_count() -> int
func boss_hp() -> float                                  # -1.0 when no boss
func boss_max_hp() -> float
# --- (V) appended once by V1-S; parameter types follow the conventions above ---
# commands: one tap mints one next_command_id() and issues one command
func pick_directive(command_id: int, slot: int) -> void
func skip_draft(command_id: int) -> void
func reroll_draft(command_id: int) -> void
func buy_out(command_id: int, slot: int) -> void
func patch_core(command_id: int) -> void
func pick_route(command_id: int, option: int) -> void
func resolve_salvage(command_id: int, choice: int, action: int) -> void
func swap_weapon(command_id: int, slot: int) -> void
func call_event(command_id: int, event_id: StringName) -> void
func continue_run() -> void                              # CONTINUE: SKIP_INTERMISSION from the boss briefing or the breather
# queries
func awaiting() -> int                                   # PhaseState.Await
func act() -> int
func act_count() -> int
func draft_offer() -> PackedInt32Array                   # directive indices of the current offer
func draft_reroll_cost() -> int
func draft_buyout_cost() -> int
func patch_cost() -> int
func free_rerolls() -> int
func route_option_count() -> int
func route_option(i: int) -> Dictionary                  # pack, counts by type, modifier, elites, hot, reward
func boss_brief() -> Dictionary
func salvage_offer() -> Dictionary
func weapon_slot_count() -> int
func weapon_slot(i: int) -> Dictionary                   # id, level, magazine, size, heat, state
func active_slot() -> int
func event_charges(id: StringName) -> int
func call_block_reason(id: StringName) -> int            # Reason.Id
func active_events() -> Array[Dictionary]
func directive_stacks(id: StringName) -> int
func build_tags() -> Dictionary
func boss_phase() -> int
func boss_phase_count() -> int
func run_seed() -> int
func draft_buyout_used() -> bool
func draft_actions_locked() -> bool
func crate_status() -> Dictionary
func wave_route() -> Dictionary
# (V5-A) appended: the readers of the Archive's field options
func has_unlock(id: StringName) -> bool         # the run counts this unlock (every unlock in a Daily Run); the UI gates
                                                # u_f_boss_intel (show act_boss() at the act start) and u_f_preview on it
func act_boss() -> Dictionary                   # the boss of the act the player is in (between waves: the next wave's act),
                                                # in the shape of boss_brief(); {} when the act has none
func route_preview(i: int) -> Dictionary        # option i of the wave after next, in the shape of route_option(); {} for a
                                                # boss wave or past the end
```

**(V5-A) Field options in the sim** (`SimConfig.has_unlock`): `u_f_reroll` gives one free reroll and `u_f_third_sling` opens
the third weapon slot at tick 0 (`ModSystem.init_world`, before the kit's grants); `u_f_turret_arc` and `u_f_turret_mortar`
decide the turret type of each pad (`TurretTypes.id_of`: one of them puts its type on the second pad, both put the arc turret
on the first and the mortar turret on the second; the "one more tap" of CONTENT 8 is not built). `ability_cooldown_total`
answers with `AbilitySystem.cooldown_ticks_of` (the cooldown with the directive stats, as the one that starts).

**(V)** The old upgrade queries (`upgrade_level`, `upgrade_cost`, `purchase_block_reason`, ...) stay and return the legacy values
(the stat directives feed the same levels). `wave_count()` returns 15 in the shipped game. `FakeRunApi` mirrors every addition
(public vars for each query, commands recorded in `calls`, matching `Events` signals emitted) so the HUD sandbox can show the
draft, the route, the salvage and the weapon bar with no sim.

The base class returns safe defaults. `SimRunApi` (`src/game/sim_run_api.gd`, task W2-A) binds it to a
`RunController`. `FakeRunApi` (`src/debug/fake_run_api.gd`, Wave 0) has public vars for every query, records
commands in `calls: Array[Dictionary]`, and emits the matching `Events` signals so the HUD can be built and
tested with no simulation. Commands issued while paused never reach the sim: the API emits
`purchase_resolved(id, false, Reason.Id.PAUSED)` or `ability_rejected(id, Reason.Id.PAUSED)`.

### 7.3 Tick driver and run controller (task W2-A)

```gdscript
class_name TickDriver extends RefCounted          # src/game/tick_driver.gd
const MAX_TICKS_PER_FRAME: int = 4
var acc: float = 0.0
var dropped_ticks: int = 0
func advance(world: SimWorld, delta: float) -> int      # runs floor(acc / DT) ticks, capped; extra time is dropped, never carried
func alpha() -> float                                   # acc / DT, for interpolation

class_name RunController extends Node             # src/game/run_controller.gd
var sim: SimWorld
var api: SimRunApi
var run_id: String
var paused: bool = false
var bot: PolicyBot = null                         # set by --autoplay
func start(config: SimConfig, run_id_value: String, view: BattleView) -> void
var tick_sink: Callable                          # W3-A, optional func(usec: float): average cost of one tick, per frame that ran ticks
func set_paused(value: bool) -> void
func stop() -> void                               # unbinds the view, frees the sim
func _process(delta: float) -> void               # if not paused: driver.advance; drain events -> Events; view.render(alpha)
```

When the sim pushes `RUN_FINISHED`, `RunController` computes `Formulas.data_reward`, calls
`Save.grant_run_reward(...)` (7.5), then emits `Events.run_finished`. Reward granting never lives in UI code.

**(V) Additions** (no signature above changes): `RunController` writes the run file (7.5) at every wave clear, after every
intermission command, and when the app is paused or backgrounded (the tail including the running wave's commands and
`resume_tick`); it has a resume entry `func start_resumed(doc: Dictionary, view: BattleView) -> void`; it passes the reward
extras (milestones, best wave, boss kills, daily flags) to `Save.grant_run_reward`; and there is no change to the stepping logic
(the sim holds itself while it awaits a choice, 6.2). `GameEventRelay` maps the new sim events to the new signals of 7.1.
`SimRunApi` implements the new members of 7.2.

### 7.4 `Game` autoload (`src/core/game.gd`; Wave 0 stub, task W2-A implements)

```gdscript
var machine: GameStateMachine
var run: RunController                    # null outside a run
var battle_view: BattleView               # null outside a run
func boot(root: Node) -> void             # called once by src/core/main.gd; builds layers; BOOT -> MENU
func goto_menu() -> void
func goto_briefing() -> void
func start_run(run_seed: int = -1, kit_id: StringName = &"k_standard", daily: bool = false) -> void
                                          # -1 = time-based seed; creates the run id "<unix>-<seed>"; (V) kit and daily params default
func resume_run_from_disk() -> void       # (V) loads user://run_v1.json and calls RunController.start_resumed (7.5)
func open_archive() -> void               # (V) the Archive is an overlay on MENU
func restart_run() -> void
func pause_run() -> void
func resume_run() -> void
func quit_to_menu() -> void
func open_settings() -> void
func request_back() -> void               # Android back, via BackPolicy
func state() -> int
```

W3-A additions (no signature above changes): the first `BattleView` is built while the boot screen shows (a short timer
after `boot`), so `ShaderWarmup` runs before the player can deploy (ARCH 8); it waits hidden in a private slot and the first
deploy adopts it, so `battle_view` stays null outside a run. `--debug-perf` adds the `PerfHud` under `DebugRoot` (full rect,
`setup(enemies_source, true)` after it is in the tree) and points `RunController.tick_sink` at `record_tick_usec`;
`--debug-overlay[=spec]` adds a `BattleDebugOverlay` (a `Node3D` child of the view) that is bound to each run's sim and unbound
when the run is torn down. The wiring lives in `GameDebugTools` and `GameViewBuilder` (`src/game/`). `MobileShell` reacts to the
app lifecycle notifications only when `lifecycle_enabled` (default `OS.has_feature("mobile")`; tests switch it on).

Main scene tree at runtime (built in code by `Game.boot`):

```
Main (Node, scenes/main.tscn, src/core/main.gd)
├── World (Node)                      BattleView is added here during a run
├── RunHost (Node)                    RunController is added here during a run
├── MobileShell (Node)                lifecycle + back gesture
└── UI (CanvasLayer)
    ├── ScreenRoot (Control, full rect)     boot / menu / briefing / results screens, one at a time
    ├── HudRoot (Control, full rect)        CombatHud during a run
    ├── OverlayRoot (Control, full rect)    PauseOverlay, SettingsScreen
    └── DebugRoot (Control, full rect)      PerfHud when --debug-perf
```

This keeps the handoff's tree (systems, Battlefield, UILayer) in spirit. Deviation D2: the handoff's
`WaveDirector`, `CombatClock`, `EconomySystem`, `UpgradeSystem`, `AbilitySystem` nodes become static systems
inside the pure sim, and `RunDirector` becomes `RunController` + `Game`.

`src/core/main.gd` (Wave 0, frozen): parses `DebugArgs`; if a capture is requested it adds `CaptureRunner`
and returns; otherwise it calls `Game.boot(self)`.

`MobileShell`: on `NOTIFICATION_APPLICATION_PAUSED` or `NOTIFICATION_APPLICATION_FOCUS_OUT` (mobile builds
only) call `Game.pause_run()` and `Save.flush()`; on `NOTIFICATION_WM_GO_BACK_REQUEST` call
`Game.request_back()`. The game stays paused after returning until the player taps RESUME. **(V)** `MobileShell` also writes
the run file (7.5) on app pause, together with `Save.flush()`.

`BackPolicy` (pure): `static func decide(state: int, overlay_open: bool) -> int` returning
`enum Action { CLOSE_OVERLAY, PAUSE, RESUME, TO_MENU, CONFIRM_QUIT, NONE }`. **(V)** Back on a choice overlay
(salvage, draft, route, boss briefing) means PAUSE: a choice can never be dismissed. Back on the Archive means CLOSE_OVERLAY:
`Game.request_back` first asks the screen on show to close an overlay of its own (`MainMenuScreen.close_overlay()`,
`ResultsScreen.close_overlay()`, through `GameRunFlow.close_screen_overlay`) and passes the result as `overlay_open`.
**(V5-A)** The upgrade drawer of the legacy HUD is gone, and with it the `drawer_open` argument and the `CLOSE_DRAWER` action.

**(V5-A) Launches.** `GameRunFlow` holds the variety entry points of `Game`: `apply_launch` (kit: the one asked for, else
`--kit`, else `Save.profile.kit`; a Daily Run always takes `GameLaunch.DAILY_KIT`), `start_daily` (the menu's DAILY RUN:
`GameLaunch.daily_seed(GameLaunch.utc_date())`, the full pool), `start_same_seed` (the results screen's SAME SEED: the seed and
the kit of the run that ended, never a Daily Run), `setup_results` (`ResultsScreen.show_milestones` with the `milestones` of
`Save.last_reward`), `setup_menu` (`set_resume_wave`, `set_daily_today`) and `resume_from_disk` (plays `resume_link`; a
finished run found on resume is paid with its Archive facts). Debug starts: `--scenario=wave:<n>` and
`--scenario=boss:<id>` set `SimConfig.debug_start_wave` and `debug_boss` (11).

**(V) `GameStateMachine` stays frozen.** The draft, route, salvage and boss-briefing screens are HUD overlays inside
INTERMISSION (their lifecycle is owned by `Game`, not by an application state); the Archive is an overlay on MENU. The sim-side
sub-steps are `PhaseState.Await` (4.1).

`Haptics`: `static func tick(ms: int = 20) -> void` (no-op unless Android and the setting is on).

### 7.5 Save system (`src/save/`, task W1-D)

**(V) Profile v2.** File `user://profile_v2.json` (+ `.tmp`, `.bak`). Plain JSON, human-readable. It replaces
`profile_v1.json`, which is now only the input of the migration (below) and is never written again.

```json
{ "schema_version": 2, "data": 0, "data_lifetime": 0, "missions_completed": 0, "best_core_hp": 0, "runs_played": 0,
  "awarded_run_ids": [], "hints_seen": [], "unlocks": [], "claimed": [], "kit": "k_standard",
  "codex_seen": [], "best_wave": 0, "boss_kills": {}, "victories_by_kit": {}, "victory_weapons": [],
  "daily": { "date": "", "best_wave": 0, "won": false, "rewarded": false },
  "settings": { "sound_on": true, "music_on": true, "haptics_on": true, "reduced_flash": false, "high_contrast": false,
                "quality": 2, "fps_cap": 60, "swap_assist": false } }
```

The legacy v1 file, for reference (the migration reads exactly this):

```json
{ "schema_version": 1, "data": 0, "missions_completed": 0, "best_core_hp": 0,
  "runs_played": 0, "awarded_run_ids": [], "hints_seen": [],
  "settings": { "sound_on": true, "music_on": true, "haptics_on": true, "reduced_flash": false,
                "high_contrast": false, "quality": 2, "fps_cap": 60 } }
```

```gdscript
class_name Profile extends RefCounted
const SCHEMA_VERSION: int = 2                # (V) was 1
var data: int; var missions_completed: int; var best_core_hp: int; var runs_played: int
var awarded_run_ids: PackedStringArray       # newest last, capped at 64
var hints_seen: PackedStringArray
var settings: Dictionary[StringName, Variant]
# (V) appended: data_lifetime: int; unlocks: PackedStringArray; claimed: PackedStringArray; kit: StringName;
# codex_seen: PackedStringArray; best_wave: int; boss_kills: Dictionary; victories_by_kit: Dictionary;
# victory_weapons: PackedStringArray; daily: Dictionary {date, best_wave, won, rewarded}
static func defaults() -> Profile

class_name ProfileCodec extends RefCounted
static func encode(p: Profile) -> String
static func decode(text: String) -> ProfileDecodeResult     # .profile (or null), .error: String, .schema_version: int
    # validates types and ranges; clamps negatives to 0; unknown keys ignored; never executes or loads paths from the file
    # (V) also validates the v2 fields; unknown unlock ids are kept but ignored, so a newer build's file is not destroyed by an older one

class_name SaveFs extends RefCounted          # interface; DiskSaveFs (user://) and MemorySaveFs (tests)
func read(path: String) -> String             # "" when missing
func write(path: String, text: String) -> bool
func exists(path: String) -> bool
func rename(from: String, to: String) -> bool # DiskSaveFs removes the target first (Windows)
func remove(path: String) -> bool

# Save autoload, src/save/save_manager.gd, extends Node
enum LoadStatus { OK, NEW_PROFILE, RECOVERED_FROM_BACKUP, RESET_AFTER_CORRUPTION, NEWER_SCHEMA_SET_ASIDE,
                  MIGRATED_FROM_V1 }                                  # (V) appended
var profile: Profile
var last_load_status: int
func use_fs(fs: SaveFs) -> void                               # tests inject MemorySaveFs, then call load_profile()
func use_content(content: ContentSet) -> void                 # (V) tests inject the content the Archive rules read; null = Content.db
func content_set() -> ContentSet                              # (V) the injected content, else Content.db (the unlock tree, kits, milestones)
var last_reward: Dictionary                                   # (V) what the latest grant added: { run_id, run_data, milestones: [{id, data}],
                                                              # milestone_data, total, daily: "" | "rewarded" | "practice" }; {} after a load
func load_profile() -> int
func flush() -> bool                                          # write tmp, verify by re-reading, keep previous as .bak, rename
func profile_dirty() -> bool                                  # W3-A: true while the profile in memory has changes no successful flush wrote
func grant_run_reward(run_id: String, result: int, data_amount: int, core_hp: int, extras: Dictionary = {}) -> bool
    # false and no change if run_id is already in awarded_run_ids; otherwise adds data, updates
    # missions_completed (victory), best_core_hp (victory, max), runs_played, appends run_id, flushes, emits profile_changed
    # (V) `extras` (optional 5th parameter; RewardLedger.apply, built by GameRewards.extras_of): "best_wave": int,
    # "act_reached": int, "boss_kills": [boss ids], "kit": String, "primary_weapon": String, "weapons": [weapon ids],
    # "daily": { "date": "YYYY-MM-DD" } for a Daily Run. Every key is optional; {} is the plain Data grant (no facts, no
    # milestone). A milestone is granted in the same flush as the run that earned it (the `claimed` list), so a run is
    # rewarded once however often it is resumed. A debug run (SimConfig.is_debug) is granted with {}.
func purchase_unlock(id: StringName) -> int                   # (V) a Reason.Id; atomic: tier gate, not owned, funds; debit; add the id;
                                                              # flush; emit profile_changed (and Events.unlock_purchased). Reasons:
                                                              # UNKNOWN_ID, DUPLICATE_COMMAND = owned, PREREQ_NOT_MET = its tier is
                                                              # closed, INSUFFICIENT_SCRAP = not enough Data
func has_unlock(id: StringName) -> bool                       # (V)
func set_kit(id: StringName) -> void                          # (V)
func save_run(doc: Dictionary) -> bool                        # (V) writes user://run_v1.json (atomic, as the profile)
func load_run() -> Dictionary                                 # (V) {} when there is none
func clear_run() -> void                                      # (V)
func get_setting(key: StringName) -> Variant
func set_setting(key: StringName, value: Variant) -> void     # validates key and type, flushes, emits settings_changed
func mark_hint_seen(key: String) -> void
func has_seen_hint(key: String) -> bool
func mark_codex_seen(key: String) -> void                     # (V) an Archive or threat entry was read (`codex_seen`), flushes
func has_codex_seen(key: String) -> bool
```

Load order: main file; if missing, `NEW_PROFILE`; if unreadable or invalid, try `.bak`
(`RECOVERED_FROM_BACKUP`); if that fails too, move the bad file to `profile_v2.json.corrupt` and start fresh
(`RESET_AFTER_CORRUPTION`). A file with a higher `schema_version` is copied to
`profile_v2.json.newer` and never overwritten in place (`NEWER_SCHEMA_SET_ASIDE`). No status crashes the game. (V) These are
the original rules applied to the v2 file names.

**(V) Migration from v1** (in `SaveManager.load_profile`, with tests on fixture files):

1. If `profile_v2.json` loads: use it.
2. Else if `profile_v1.json` loads (or its `.bak`): copy every v1 field as is; `data_lifetime = data`; the new lists are empty;
   `kit = "k_standard"`; `best_wave = 5` if `missions_completed > 0` else 0; write `profile_v2.json`; **leave the v1 files
   untouched** (a downgrade still finds them). Status `MIGRATED_FROM_V1`.
3. Else: new profile.

Testers keep their Data; nothing is unlocked for free.

**(V) Run file** `user://run_v1.json` (+ `.tmp`, `.bak`; the same atomic write as the profile). It replaces the old statement
"there is no mid-run save": a 15-minute run must survive the process being killed. Resume is a boundary snapshot plus the
command tail (6.7):

```json
{ "schema_version": 1, "build": "0.1.0", "content_hash": "<12 chars>", "run_id": "<unix>-<seed>", "seed": 48211,
  "kit": "k_standard", "unlocked": ["u_w_lmg"], "daily": false,
  "boundary": { "wave": 6, "tick": 21480, "state_hash": "<sha256>", "state": { "...": "to_dict of every state class" } },
  "log": [ { "tick": 12, "id": 3, "kind": 1, "arg": 0 } ],
  "tail": [ { "tick": 21481, "id": 311, "kind": 3, "arg": 1 } ], "resume_tick": 22950,
  "debug": { "invulnerable": false, "damage_mult": 1.0, "start_scrap": 0, "start_wave": 0, "boss": "" } }
```

`log` is every command up to `boundary.tick`; `debug` is optional and only written by debug runs. `boundary.wave` is the number
of waves cleared. The snapshot `VERSION` is 2. In the state dictionary, a float that is not a small whole number travels as `~`
plus 16 hex digits (the exact bits), a 64-bit int as a decimal string, and a packed array as `f:`, `i:` or `b:` plus hex, so a
JSON round trip cannot change a hashed value.

`build` is the `config/version` of the exporting build. It is written (1) at every wave clear: the boundary snapshot, its
`state_hash`, an empty tail; (2) after every intermission command: the tail grows; (3) when the app is paused or backgrounded
(`MobileShell`): the tail including the running wave's commands and `resume_tick`. On launch, if the file exists and matches the
build and the content hash, the menu shows RESUME RUN (WAVE n). If the process died without a pause notification there is no
`resume_tick`: the run resumes at the last recorded choice and the current wave starts again. The file is deleted when the run
ends. A resumed run keeps its run id, so `grant_run_reward` can pay it only once.

### 7.6 Log (`Log` autoload)

`Log.info(tag: String, msg: String)`, `Log.warn(...)`, `Log.error(...)`. Format `[tag] message`; `error`
prints with the `ERROR:` prefix so the test runner and the smoke test see it. Boot prints
`game boot version=<v> renderer=<name>` and, once the menu is up, `boot ok`.

---

## 8. View (`src/view/`)

```gdscript
class_name BattleView extends Node3D               # src/view/battle_view.tscn; Wave 0 writes the composer, frozen
var camera_rig: CameraRig
var arena_view: ArenaView
var actor_layer: ActorLayer
var vfx_layer: VfxLayer
func setup(content: ContentSet) -> void            # builds everything once
func bind(sim: SimWorld) -> void                   # reset pools, start reading this sim (read only)
func unbind() -> void
func render(alpha: float, delta: float) -> void    # once per frame, after the frame's ticks
func fit_camera(viewport_size: Vector2, top_px: float, bottom_px: float) -> void
func world_to_screen(x: float, z: float, height: float = 0.0) -> Vector2
func set_quality(tier: int) -> void                # VisualQuality.Tier
func set_reduced_flash(on: bool) -> void           # forwards to VfxLayer and ArenaView
func set_high_contrast(on: bool) -> void           # added after Wave 1; forwards to ActorLayer (body is W2-E's)

class_name CameraRig extends Node3D                # task W1-E
var camera: Camera3D                               # PROJECTION_PERSPECTIVE (CameraFit.FOV_DEG = 30, vertical), KEEP_HEIGHT; pitch from arena.pitch_down_deg (clamped 40 to 65; shipped 50, owner pick 2026-11-12, the three-quarter view of the concept image)
func setup(arena: ArenaDef, tokens: VisualTokens) -> void
func fit(viewport_size: Vector2, top_px: float, bottom_px: float) -> void
func world_to_screen(world: Vector3) -> Vector2
func pitch_down_deg() -> float

class_name CameraFit extends RefCounted            # pure math, unit-tested without a renderer
static func solve(arena: ArenaDef, viewport_size: Vector2, top_px: float, bottom_px: float) -> CameraFitResult
class_name CameraFitResult extends RefCounted
var ortho_size: float; var position: Vector3; var basis: Basis; var px_per_meter: float
var fov_deg: float                                 # > 0: perspective camera (CameraPersp.solve); 0: orthographic (CameraFit.solve_with_fov(..., 0))

class_name ArenaView extends Node3D                # task W1-E
func setup(arena: ArenaDef, tokens: VisualTokens) -> void
func set_core_state(hp_fraction: float, shield_fraction: float, dead: bool) -> void
func set_pad_state(pad: int, has_turret: bool) -> void
func set_quality(tier: int) -> void

class_name ActorLayer extends Node3D               # task W1-F
func setup(content: ContentSet) -> void
func bind(sim: SimWorld) -> void
func unbind() -> void
func render(alpha: float, delta: float) -> void
func set_quality(tier: int) -> void
func set_high_contrast(on: bool) -> void                 # brighter optics and rims (GDD 10.3); added after Wave 1
func enemy_world_position(enemy_id: int) -> Vector3      # for VFX and floating text; Vector3.INF if unknown

class_name VfxLayer extends Node3D                 # task W1-F
func setup(content: ContentSet, rig: CameraRig, actors: ActorLayer) -> void
func bind(sim: SimWorld) -> void
func unbind() -> void
func render(alpha: float, delta: float) -> void
func set_quality(tier: int) -> void
func set_reduced_flash(on: bool) -> void

class_name VisualQuality extends RefCounted        # src/view/kit/visual_quality.gd
enum Tier { LOW, MID, HIGH }

class_name MatLib extends RefCounted               # src/view/kit/mat_lib.gd; cached, shared materials
static func mat(id: StringName) -> StandardMaterial3D
    # ids: ceramic, gunmetal, dark_frame, rubber, concrete, steel_red, steel_grey, hazard,
    #      emit_cyan, emit_amber, emit_red, flash_white, shadow_blob, add_cyan, add_amber, add_red, add_white
static func configure(tokens: VisualTokens) -> void

class_name MeshBuilder extends RefCounted          # src/view/kit/mesh_builder.gd; merges primitives into ONE ArrayMesh
func box(size: Vector3, xform: Transform3D, mat_id: StringName) -> MeshBuilder
func cylinder(radius_top: float, radius_bottom: float, height: float, sides: int, xform: Transform3D, mat_id: StringName) -> MeshBuilder
func prism(size: Vector3, xform: Transform3D, mat_id: StringName) -> MeshBuilder
func sphere(radius: float, segments: int, xform: Transform3D, mat_id: StringName) -> MeshBuilder
func quad(size: Vector2, xform: Transform3D, mat_id: StringName) -> MeshBuilder
func build() -> ArrayMesh                          # one surface per distinct material, material already set
class_name MeshKit                                 # static func begin() -> MeshBuilder
```

View rules:

- Sim meters map 1:1 to world units: sim `(x, z)` is world `(x, 0, z)`.
- Interpolate every enemy between `prev_x/prev_z` and `x/z` by `alpha`. Never extrapolate.
- **One pooled `Node3D` per bodied enemy** with one `MeshInstance3D` (merged mesh, at most 3 surfaces). Pool sizes:
  skitter 50, hollow_warden 24, rusher 32, siege_hulk 2; **(V)** from the variety milestone `EnemyPool.SIZES` is data-driven from
  `EnemyDef.alive_cap` of the bodied types (those values are the legacy ones, so the pool of a type equals its alive cap and a
  living enemy never loses its visual). Minis are not pooled nodes (below). No allocation after `setup`. Map enemy id to pool
  entry on `enemy_spawned`, release on `enemy_killed`. On `bind`, adopt every enemy already alive in the store.
- Hit flash = swap `material_override` to `flash_white` for 3 frames. No per-instance shader data (the
  original project found per-instance attributes unreliable on a PowerVR phone GPU).
- Blob shadows and world health bars are transform-only `MultiMeshInstance3D`s (one draw call each).
- Motion is procedural: bob, lean, stomp, recoil, Warden upper-body yaw toward `warden.aim_x/aim_z`.
- No physics bodies, no collision shapes, no `NavigationAgent3D`, no `AnimationTree` in the slice.
- `WorldEnvironment`: no glow (the exceptions are bloom on MID and HIGH when the look is `STYLISED_PLUS`:
  `LookDevStyle.glow_enabled`, `ArenaView._apply_glow`, and bloom on HIGH for the styled yard: `EnvStyle.GLOW`,
  `EnvDress.apply_glow`; the styled yard also sets a linear tonemap with contrast 1.06, saturation 0.94 and exposure 0.92 on
  MID and up: `EnvStyle.GRADE_*`), no SSAO, no SSR, no fog volumes. One `DirectionalLight3D`; shadows off on LOW
  and MID, on for static props only on HIGH. At most 4 unshadowed `OmniLight3D` on HIGH, 0 on LOW.
  Everything else is emissive material or additive quads.
- Every shader or material variant is drawn once during the boot screen (`ShaderWarmup` helper in
  `src/view/kit/`, alpha 0.02, 2 frames) so the first shot does not hitch. This includes the hard-surface
  Warden materials (`LookDevMat.warm_materials`, drawn on vertex-colour quads because pipelines are keyed by vertex format).

**The character look.** The look is a process-wide switch, `LookDevStyle.Look { CURRENT, STYLISED, STYLISED_PLUS }`. The shipped
game uses **STYLISED** (hard-surface geometry with ambient occlusion and edge wear baked into vertex colours, one shared
shader on MID and HIGH; the owner pick after the W3-C Warden look-dev, v4, rolled out to the turret, the enemies and the Hulk
in W3-D; `--rollout=0` keeps those in CURRENT for a cost measurement): `GameViewSettings.SHIPPED_LOOK` is the default of
`GameViewSettings.apply_look(args)`, which `Game.boot` calls before any `BattleView` exists, because `ActorLayer` and
`ArenaView` read the look when they are constructed.
`--look=current|stylised|stylised_plus` overrides it for a comparison (11). Quality tiers, Reduced Flash and High Contrast change
only how the battle looks, never an outcome.

**(V) View additions** (SPEC 10 to 13.6). Every sim-relevant visual is drawn on every tier; the quality tier only scales the
cosmetic extras, and **a telegraph, a danger zone or an enemy projectile is never tier-gated** (a test per tier).

- **Minis** (`mote`, `shard`) are transform-only `MultiMeshInstance3D`s: one per mini type, 40 instances, a 40-triangle mesh
  with 2 surfaces (`actors/mini_swarm.gd`). No per-instance shader data (the PowerVR rule above); a mini has no hit flash and no
  health bar. New modules: `actors/enemy_meshes_2.gd`, `boss_meshes.gd`, `weapon_meshes.gd` (the 8 new weapons),
  `crate_view.gd`; `arena/rail_lines.gd`, `freight_view.gd`, `drum_view.gd`; `vfx/fx_blasts.gd`, `fx_arcs.gd`, `fx_beams.gd`,
  `fx_lobs.gd`, `fx_zones.gd` (pools, wards, telegraphs, elite rings, tethers), `fx_strike.gd`, `fx_cosmetic.gd` (scorch, ghost
  swarm, embers). `VfxLayer` gets one `setup` call per new module and stays under 400 lines by delegating.
  `BattleView` signatures stay FROZEN. The ground material gains two faint rail lines, kept low-contrast (GDD 12.3).
- **Materials.** All new enemy materials are the existing `ceramic`, `dark_frame`, `gunmetal`, `hazard`, `emit_red`: no new
  material variant, so no new pipeline to warm. New effect materials reuse `add_cyan`, `add_amber`, `add_red`, `add_white`; the one
  new material is the red hatch for danger decals (unshaded, alpha), which is added to `ShaderWarmup`.
- **Triangle budgets.** 8 new weapons 350 each; `mote`, `shard` 40 each; `burster`, `spitter`, `borer`, `jammer` 400 each;
  `splitter`, `shieldbearer`, `reclaimer` 500 each; `ward_pylon` 150; the 4 new bosses **1,500 each**, like the Hulk (V4-R,
  approved by the owner on 2026-11-13; the spec's 900 was the Hulk's budget before W3-D raised it; one pooled node each); crate
  200, freight car 600, fuel drum 80, strike beacon 100. **The Warden budget** `ActorMeshes.TRI_BUDGET[&"warden"]` is 2,500 today
  (700, then 2,000, then 2,500 in W3-C; it uses 2,448 triangles with the pistol and 2,472 with the SMG) and a long weapon does not
  fit. SPEC Q4 proposes a body budget of 2,300 plus a separate weapon budget of 350; the body must lose about 150 triangles or
  the budget rises to 2,650. The owner of `TRI_BUDGET` decides after a look at the captures; until then 2,500 stands.
- **Warden weapon mounts (V4-R).** The Warden keeps **three** weapon mounts under its hand: `Pistol`, `Smg` and a third one
  that shows the model of whichever other weapon is in the active slot (`WeaponMeshes.model_index` picks the mesh and the
  muzzle point per weapon). The holstered weapon is a `MeshInstance3D` **sibling** of the Warden under the `ActorLayer` (it
  follows the Warden's back; up to 3 extra draw calls on MID and HIGH, none on LOW). `look_dev_view_test` pins the 12
  mesh-instance names of the Warden.
- **Readability rules** are tests, not prose: one red optic per enemy and nothing else on an enemy glows; the colour roles of
  GDD 12.1; red hatched decals for everything that hurts the player's side; at most 3 ticker lines and 1 banner; no damage
  numbers; a flash over 5% of the screen lasts at most 0.25 s and Reduced Flash removes it; friendly beams and arcs are drawn
  thinner than the enemy's danger decals are wide; during a 6-blast chain the optics of survivors stay countable in a fixed-seed
  capture (the `look_dev_legibility.gd` pattern). GDD 6.7 and 12.3 are the source of the rules.
- **Tiers.** `VisualQuality` gets the tier tables of section 13 (pool sizes per tier) and the feature table: blast = ring only
  on LOW, ring + flash on MID, ring + flash + 4 debris streaks on HIGH; scorch marks, ghost swarm, rain bursts, embers and screen
  shake none on LOW, light on MID, full on HIGH (screen shake is off with Reduced Flash).
- **Holstered weapon.** The weapon not in hand sits on the pack (reuses the weapon mesh, MID and HIGH only).

---

## 9. UI (`src/ui/`)

```gdscript
class_name UiTheme extends RefCounted              # src/ui/kit/ui_theme.gd (Wave 0 basic, W2-B polishes)
const TOUCH_MIN: int = 132; const BTN_PRIMARY_H: int = 148
const FONT_SMALL: int = 30; const FONT_BODY: int = 38; const FONT_LARGE: int = 52; const FONT_TITLE: int = 84
static func build(tokens: VisualTokens, high_contrast: bool) -> Theme
static func color(token: StringName) -> Color
class_name UiKit extends RefCounted                # panel(), button(text_key), label(text_key, size), icon(id), bar()
class_name SafeArea extends RefCounted
static func margins(window_px: Vector2i, safe_px: Rect2i, viewport_size: Vector2) -> Vector4   # left, top, right, bottom in viewport units
class_name HudLayout extends RefCounted
static func top_band_px(viewport_size: Vector2, margins: Vector4, tokens: VisualTokens) -> float
static func bottom_band_px(viewport_size: Vector2, margins: Vector4, tokens: VisualTokens) -> float
```

Screens and overlays. Each is a `Control` scene whose root script exposes `setup(...)` and signals. `Game`
instantiates them, connects the signals and frees them.

| Scene (`res://src/ui/...`) | `class_name` | `setup` | Signals |
|---|---|---|---|
| `screens/boot_screen.tscn` | `BootScreen` | `setup(version: String)` | `finished` |
| `screens/main_menu_screen.tscn` | `MainMenuScreen` | `setup(profile: Profile)`, `set_resume_wave(wave: int)` | `start_pressed`, `resume_pressed`, `settings_pressed`, `quit_pressed` |
| `screens/briefing_screen.tscn` | `BriefingScreen` | `setup(content: ContentSet)` | `deploy_pressed`, `back_pressed` |
| `screens/results_screen.tscn` | `ResultsScreen` | `setup(summary: RunSummary, content: ContentSet, profile: Profile, reward_granted: bool)` | `retry_pressed`, `menu_pressed` |
| `screens/settings_screen.tscn` | `SettingsScreen` | `setup()` (reads and writes `Save`) | `closed` |
| `combat/combat_hud.tscn` | `CombatHud` | `setup(api: RunApi, content: ContentSet, view: BattleView)` (`view` may be null) | `pause_requested` |
| `combat/pause_overlay.tscn` | `PauseOverlay` | `setup()` | `resume_pressed`, `restart_pressed`, `settings_pressed`, `quit_pressed` |
| **(V)** `run/draft_overlay.tscn` | `DraftOverlay` | `setup(api: RunApi, content: ContentSet)` | none: it issues `pick_directive`, `skip_draft`, `reroll_draft`, `buy_out` and `patch_core` on the `RunApi` |
| **(V)** `run/route_overlay.tscn` | `RouteOverlay` | `setup(api: RunApi, content: ContentSet)` | none: `pick_route` on the `RunApi` |
| **(V)** `run/boss_brief_overlay.tscn` | `BossBriefOverlay` | `setup(api: RunApi, content: ContentSet)` | none: `continue_run` on the `RunApi` |
| **(V)** `run/salvage_overlay.tscn` | `SalvageOverlay` | `setup(api: RunApi, content: ContentSet)` | none: `resolve_salvage` on the `RunApi` |
| **(V)** `screens/archive_screen.tscn` | `ArchiveScreen` | `setup(content: ContentSet)` (reads and writes `Save`) | `closed` |
| **(V)** `run/build_list.gd` (not a scene) | `BuildList` | `setup(api: RunApi, content: ContentSet)` | `closed`; the list of directives and weapons held |
| **(V)** `screens/kit_selector.gd` (not a scene) | `KitSelector` | `setup(profile: Profile, content: ContentSet)` | `kit_selected(id)` |

`CombatHud` also has `func top_band_px() -> float`, `func bottom_band_px() -> float`. (**V5-A** removed
`is_drawer_open()` and `close_drawer()` with the upgrade drawer.)

**(V) Combat HUD changes** (GDD 10.1). The upgrade tab and the drawer are gone from the shipped HUD; the bottom band grows from
23% to 26% (`visual_tokens.json` `bottom_controls_fraction`; `CameraFit` already takes the band heights as inputs, and the
captures at 1080x1920 must show the whole arena still fits). New components in `src/ui/combat/`: `hud_weapon_bar.gd` and
`hud_weapon_card.gd` (the active card 400 x 150, the holstered card 300 x 150, tap to swap; count or heat bar, RELOADING or
VENTING text, level chevrons), `hud_call_button.gd` (STRIKE and VENT 150 x 150; FREIGHT with `signal_hijack`),
`hud_threat_ticker.gd` (up to 3 lines of icon + text + bar, owns all event text) and `hud_edge_arrows.gd`; `hud_boss_bar.gd`
gains phase pips and `hud_top_bar.gd` shows act and wave of 15. `results_screen.gd`, `main_menu_screen.gd`,
`briefing_screen.gd` and `pause_overlay.gd` are extended (RESUME RUN, ARCHIVE, DAILY RUN, kit selector, build recap, SAME SEED,
the seed line and BUILD button). **V5-A** deleted `hud_upgrade_drawer.gd`, `hud_upgrade_card.gd`, the drawer members of
`CombatHud` and `BackPolicy`'s drawer branch, and migrated the legacy HUD tests of the drawer. The signatures of the (V) rows above are derived from
the layering rule (the UI talks to the sim only through `RunApi`) and are confirmed by tasks V2-E and V4-U, which own `src/ui/`.
Icons in `assets/icons/`: 8 tag glyphs x 4 rarity frames plus a category corner mark (about 20 SVGs) and the 10 weapon
silhouettes; the 60 directive icons are not hand-authored.

UI rules: sizes in 1080-wide base pixels; every interactive control at least `TOUCH_MIN` square; apply
`SafeArea` margins to the top bar and bottom panel (recompute on the root viewport's `size_changed`); a
Control already in the tree uses `set_anchors_and_offsets_preset`, not `set_anchors_preset`; number labels
update on signals or at 10 Hz, never per frame; the HUD must stay usable from 9:20 to 1:1 aspect.

---

## 10. Audio (`Sfx` autoload, `src/audio/audio_director.gd`; Wave 0 no-op stub, task W2-C implements)

```gdscript
var disabled: bool = false                      # --mute
func play(id: StringName) -> void               # pooled, voice-capped, small pitch jitter from its own RNG
func start_ambience() -> void
func stop_ambience() -> void
func set_intensity(level: float) -> void        # 0..1, combat drone layer
func pause_all() -> void
func resume_all() -> void
func apply_settings() -> void                   # reads sound_on / music_on from Save
```

Sound ids (files `assets/audio/sfx/<id>.wav`): `shot_pistol`, `shot_smg`, `shot_turret`, `reload_start`,
`reload_done`, `hit_ceramic`, `hit_armor`, `death_small`, `death_heavy`, `death_boss`, `core_hit_light`,
`core_hit_heavy`, `boss_stomp`, `emp`, `shield_up`, `shield_break`, `overdrive_on`, `overdrive_off`,
`ui_tap`, `ui_purchase`, `ui_deny`, `ui_drawer`, `wave_start`, `wave_clear`, `intermission_tick`,
`core_low`, `boss_stinger`, `victory`, `defeat`. Loops: `assets/audio/loops/ambience.wav`, `combat_drone.wav`.

The director's internal router subscribes to `Events`. UI code calls `Sfx.play(&"ui_tap")` directly.

**(V) Routes of the variety milestone** (V2-G, V4-A). `AudioEventRouter` merges two tables of `signal name -> handler`:
`AudioVarietyRoutes.wiring()` (the weapons, blasts, drafts, crates, the run flow; since V5-A also
`weapon_charging -> on_weapon_charging`, the rail lance's `rail_charge`) and, inside it, `AudioThreatRoutes.wiring()` (the
chaos events with `warn_harm` / `warn_help` and their own sounds, the boss telegraphs and phases, elites, wards, borers).
Every handler is public and read-only; neither class touches the sim. `AudioCatalog.LOOP_IDS` (`lmg_spin`, `torch_loop`)
lists the one-shot files that a held voice loops (`AudioDirector.hold` through `AudioLoopPad.looped_copy`); every looping
stream of the game is one of the two beds or one of these, and a test pins that each is padded. The combat drone follows
the **threat budget**: `AudioVarietyRoutes.intensity_for_act` places the wave inside its act by its budget
(`WAVE_BUDGETS`, a mirror of `data/run.json` `waves[].budget` that a test pins; the boss wave is the top of its act), so
the drone rises through an act instead of by the wave number.

**Looping beds on a phone (`AudioLoopPad`, `src/audio/audio_loop_pad.gd`).** When a looping WAV wraps, the mixer's interpolation
reads a few frames past `loop_end`. With the loop end at the very end of the data that read leaves the buffer: on a phone (the
hardened allocator) it was a SIGSEGV in the audio thread, 16 s into a run, at the second wrap of the 8 s combat drone loop (the
desktop reads garbage silently). `AudioLoopPad.pad(wav: AudioStreamWAV) -> bool` appends `PAD_FRAMES` (256) frames of the loop
start behind the loop end, once, for 8- and 16-bit PCM loops that actually loop and do not already extend that far; those frames
are exactly what the loop plays next, so the wrap stays seamless. `AudioDirector._start_loops` pads both beds before tuning
them. **Every looping stream added later must go through it** (the held weapon loops below included).

**(V) Variety audio** (SPEC 12.1, 10.5, 13.7). 60 new sound ids (29 existed), all from the existing DSP kit in
`tools/audio_gen/voices.py` (noise bursts, filtered sweeps, FM tones), deterministic (`gen.py --check` stays byte-identical):

| Group | New ids |
|---|---|
| Weapons | `shot_scattergun`, `shot_rifle`, `shot_hornet`, `hornet_pop`, `shot_lmg`, `lmg_spin` (loopable 1 s), `shot_mortar`, `mortar_blast`, `torch_loop` (loopable), `shot_arc`, `arc_chain`, `rail_charge`, `shot_rail`, `weapon_vent`, `weapon_swap` |
| Enemies | `burster_arm`, `blast_small`, `blast_big`, `spitter_shot`, `bolt_impact`, `splitter_split`, `ward_hum` (short), `ward_break`, `jammer_pop`, `borer_emerge`, `mote_burn`, `elite_spawn` |
| Bosses | `brood_hatch`, `lance_charge` (3 s rising, stinger class), `lance_fire`, `aegis_exposed`, `tremor_stomp`, `hulk_charge`, `boss_phase` |
| Events | `warn_harm`, `warn_help`, `strike_call`, `strike_impact`, `core_vent`, `freight_horn`, `freight_pass`, `static_front` (crackle bed, 2 s), `surge_up`, `brownout`, `breach_crack`, `recount_tick`, `relay_window`, `crate_land`, `crate_secured`, `crate_lost`, `drum_blast` |
| UI | `draft_open`, `draft_pick`, `draft_pick_corrupted`, `draft_reroll`, `route_pick`, `salvage_open`, `unlock_buy`, `act_start`, `resume_link` |

`AudioCatalog` gains the ids and the voice **classes** (weapon, blast, alert, ui) with per-class voice limits: the 16 voices stay;
3 are reserved for the alert class (event warnings, boss telegraphs, core low); the weapon class may use at most 8; blasts keep
the existing per-id cap of 3 starts per frame and a "big blast" sample replaces 4 or more simultaneous small ones. `AudioEventRouter`
subscribes to the new `Events` signals (7.1). `AudioDirector` gains two held weapon voices for the loop-capable sounds:
`func hold(id: StringName, slot: int) -> void` and `func release(slot: int) -> void` (new methods, nothing existing changes).
The combat drone's intensity follows the act and the wave budget instead of the wave number. Each warning sting is distinct in
rhythm, not only in pitch; nothing is melodic.

---

## 11. Debug, capture and command-line arguments (`src/debug/`)

User arguments come after `--`. On Android they are baked through the preset option
`command_line/extra_args` (never committed with debug values).

| Argument | Effect |
|---|---|
| `--seed=<int>` | Fixed run seed |
| `--autoplay[=<policy>]` | Skip menus, start a run, `PolicyBot` plays. Default `greedy`; (V) accepts the 8 policies `none`, `greedy`, `random`, `hoarder`, `spammer`, `turret_rush`, `balanced`, `risk` (every `PolicyBot.NAMES` entry) |
| **(V)** `--shots=<abs dir>` | With `res://src/debug/game_shots.tscn` (`GameShots`): play a whole run through the real game and save a PNG at every draft, route, salvage, boss brief, strike, blast and results moment. `--capture-scene` is not supported on `scenes/main.tscn` |
| `--scenario=hold<N>` | Debug run: invulnerable core, hold N enemies alive (perf) |
| **(V)** `--scenario=hold<N>+<M>` | As `hold<N>` with M minis as well (N bodied + M minis; `hold50+40` is the perf scenario) |
| **(V)** `--scenario=chain` | A burster line and a strike, for perf and the legibility capture |
| **(V)** `--scenario=event:<id>` | One event on its own, for the view tasks and captures (not built: the puppet scenarios of the sandboxes cover it) |
| **(V5-A)** `--scenario=boss:<id>` | The real game starts at the boss wave of that boss with a scripted build: a `BossDef` id (`brood_carrier`, `lance_platform`, `aegis_array`, `tremor_rig`, `siege_hulk`) or a Node 9 variant (`hulk_plated`, `hulk_fed`, `hulk_overclocked`). `SimConfig.debug_boss`, applied by `DebugStart` |
| **(V5-A)** `--scenario=wave:<n>` (the meaning of `--wave=<n>`; `DebugArgs` does not parse `--wave` yet) | Start at wave n with a scripted build (`DebugStart.BUILD`: one base directive per skipped wave, a second weapon from wave 3). `SimConfig.debug_start_wave`. Skips the menus like `--autoplay` |
| **(V)** `--kit=<id>` | Start with that kit |
| **(V)** `--unlock=all\|none\|<ids>` | The unlocked pool of the run (`all` for a debug victory path) |
| **(V)** `--daily` | Start the Daily Run |
| `--debug-perf` | `PerfHud` + a `[PERF]` log line every 5 s |
| `--mute` | No audio |
| `--quality=<0..2>` | Force a quality tier |
| `--quit-after-run` | Quit with code 0 once the results state is reached (W2-A) |
| `--capture-run=<abs dir>` | With `--autoplay`: save window screenshots at fixed moments of the run (W3-B) |
| `--capture-scene=<res path>` `--capture-out=<abs png>` `--capture-size=<WxH>` `--capture-frames=<n>` | Render the scene in a `SubViewport` of that size, save a PNG after n frames, quit |
| `--look=current\|stylised\|stylised_plus` | The character look. The shipped game uses **STYLISED** (`GameViewSettings.SHIPPED_LOOK`); `--look=current` brings back the old blocky look for comparison. `Game.boot` applies it before any `BattleView` exists |
| `--sfx=0\|1`, `--music=0\|1` | Force the sound effects or the two loop beds off or on, over the saved settings (`GameAudioDebug`; for bisecting an audio problem on a device) |
| `--loop-trim=<frames>`, `--loop-off`, `--audio-trace` | Pull the beds' loop end back by that many frames; play the beds once instead of looping; log every started sound and bed start |
| `--msaa=0\|2\|4`, `--fxaa=0\|1`, `--glow=0\|1` | Force the cost-measurement switches of the look (-1, the default, is by look and tier): the phone perf sweeps of section 13 |
| `--zoom=<f>`, `--view=game\|top\|front\|side`, `--solo`, `--hide-warden`, `--reload-pose`, `--measure=<s>`, `--render-size=<WxH>`, `--tune=<name:value,...>` | Look-dev sandbox switches (W3-C); W3-D adds `--rollout=0\|1` (0 keeps the turret and the enemies in CURRENT while the Warden is styled), `--small-baked=0\|1` and `--focus=warden\|skitter\|hollow_warden\|rusher\|siege_hulk\|turret` (cost measurements and close-up cameras); `--debug-overlay[=spec]`, `--high-contrast`, `--reduced-flash` and `--hud-step=<n>` are also parsed by `DebugArgs` |

**Debug arguments on a device.** `DebugArgs.from_os()` reads, in this order: the user arguments after `--`; the words of the
environment variable `CINDERFALL_ARGS` (desktop only; it is how a wrapper that cannot forward flags, such as `capture.ps1`,
selects a scenario or a quality tier: `CINDERFALL_ARGS="--scenario=boss --quality=2" capture.ps1 ...`); and, **in a debug
build only** (`OS.is_debug_build()`), the words of the file `user://cinderfall_args.txt` if it exists (one line, blank
separated). The file is how the flags of an exported APK change without a rebuild: `adb shell "run-as
com.normalexception.games.cinderfall.dev sh -c 'echo --scenario=hold50 --debug-perf --quality=2 > files/cinderfall_args.txt'"`,
then force-stop and launch; delete the file afterwards (the procedure and the device numbers are in `docs/reports/PHONE_PERF.md`).
`DebugArgs.expand` splits a single argument that carries several flags (`-Scene "<path> <flags>"` of `capture.ps1`).

`[PERF]` line format (parsed by `smoke_android.ps1`):
`[PERF] fps=<avg> min=<worst 1s> frame_ms=<avg> p95_ms=<p95> tick_ms=<avg sim tick> enemies=<alive> draws=<n> prims=<n> vid_mb=<n>`.

`SimPuppet` (`src/debug/sim_puppet.gd`): builds a real `SimWorld`, then drives the stores and `Events`
directly (spawns N enemies of each type, walks them toward the core on straight lines, fires fake shots and
kills) so the view can be built before the simulation exists. `view_sandbox.tscn` = `BattleView` + `SimPuppet`.
`hud_sandbox.tscn` = `CombatHud` + `FakeRunApi` cycling through states. **(V)** `SimPuppet` also drives minis, blasts, pools,
telegraphs and a boss telegraph, so the view tasks do not wait for the sim; `view_sandbox.tscn` gains `--scenario=chain` and
`hold<N>+<M>`, and `hud_sandbox.tscn` gains `--state=draft|route|salvage|combat2` (V1-S), so V2-E and V2-F can capture while
V2-P owns `src/debug/`.

---

## 12. Tooling contracts (`tools/`, Wave 0 unless noted)

| Script | Purpose | Success signal |
|---|---|---|
| `check.ps1 [-Path <res paths>] [-SkipTests]` | import, compile gate (warnings as errors), layer lint, tests | exit 0 and last line `CHECK OK` |
| `test.ps1 [-Path a,b] [-Suite name] [-Canary]` | import, GdUnit4 run, parse output and JUnit XML | exit 0 and last line `TEST SUMMARY: tests=N failures=0 errors=0 skipped=S exit=0` with N > 0 |
| `capture.ps1 -Scene <res> -Out <png> [-Size 1080x2400] [-Frames 90]` | desktop screenshot through the real renderer (not headless) | exit 0, PNG exists, not blank |
| `sim_run.ps1 -Seed n -Policy greedy\|none [-Runs k]` (W2-D) | headless full runs, prints result, duration, peaks, hashes. (V) `-Policy` accepts all 8 policies of 6.7 and the run also prints the build signature and the death wave | exit 0, line `SIM SUMMARY: ...` |
| `balance_run.ps1 -Runs k` (W2-D) | compares runs with the targets in GAME_DESIGN 8.4. (V) Reads the redefined targets of GDD 8.4; `-Data res://tests/fixtures/data_baseline` runs the legacy fixture | exit 0 PASS or WARN, 1 FAIL |
| **(V)** `scorecard_run.ps1 -Runs n [-Pool base\|full] [-Jobs k]` | the predictability scorecard (GDD 8.4): `n` seeds x 8 policies, plus 3 more `balanced` runs per seed for the route rows S14 and the pool row S15 (the gate version is `-Runs 30`, the full card `-Runs 200`). **19 rows**: an `integrity` row in front (a run that did not finish, or broke an invariant of the harness checker, is a structural break and a FAIL) and S1 to S18. S8 is WARN when any policy but `none` falls before wave 3 (or more than 2% before wave 4) and FAIL only when `balanced`, the reference player, falls before wave 3. `-Jobs k` plays the card in `k` Godot processes at once (shards of the job list) and joins their records in one more process; the verdict is the same as with `-Jobs 1` | exit 0; last line `SCORECARD: PASS\|WARN\|FAIL rows=19 pass=.. warn=.. fail=.. runs=..`; exit 1 on FAIL |
| **(V)** `plan_dump.ps1 -Seed n` | prints a seed's whole plan (bosses, both options of every wave, events) for bug reports and design review | exit 0 |
| `run_emulator.ps1`, `deploy_android.ps1`, `smoke_android.ps1` (W1-H) | emulator boot; export, install, launch; log and screenshot checks | `== RUNNING (pid n)`; `SMOKE OK` |

Exit codes of `test.ps1`: 0 pass, 1 test failure, 2 script or parse error in the output, 3 zero tests,
4 tool failure. Headless Godot can exit 0 after an error, so **nothing may judge a run by Godot's own exit
code**; the wrappers parse the output. `test.ps1` sets `APPDATA` to `build\test_appdata` so parallel
checkouts never share `user://`. `-Path` accepts a comma-separated list and splits it itself.

---

## 13. Performance budgets (reference: mid-range 2020 phone; measured numbers go in `docs/reports/`)

| Budget | Target | Hard limit |
|---|---|---|
| Frame time, 50 enemies (the old wave 5; **(V)** 50 + 40 minis in the variety game) | 16.7 ms | 33.3 ms (30 FPS fallback: `fps_cap` 30, quality LOW) |
| Sim tick, 50 enemies (desktop headless) | 0.3 ms | 1.0 ms |
| Sim tick on phone | 1.0 ms | 3.0 ms |
| **(V)** Sim tick at 50 bodied + 40 minis, desktop headless | 0.6 ms | 1.0 ms |
| **(V)** Sim tick at 50 + 40 on phone | 2.0 ms | 3.0 ms |
| Ticks per frame | 1 at 60 FPS, 2 at 30 FPS | 4 (then time is dropped) |
| Draw calls in combat (3D + UI) | 150 (stays; **(V)** the variety worst case is estimated at about 165 on HIGH, see below) | 220 |
| Triangles on screen | 120 k | 200 k |
| Live particles / VFX quads | 200 | 400 |
| Tracers alive | 24 | 48 |
| Floating texts | 12 | 24 |
| Lights | 1 directional + 4 omni (HIGH) | - |
| MSAA (hard-surface looks only; CURRENT is always off) | LOW off, MID 2x, HIGH 4x (`LookDevStyle.apply_aa`) | Measured on the dev iGPU: +2.9 ms at 2x, +4.2 ms at 4x on HIGH. **Measured on the phone (Pixel 11 Pro Fold): nearly free, at most about 0.15 ms**, so the per-tier plan stands (`MSAA_HIGH` would become 2 only if a phone showed more than about 1 ms for 4x) |
| Texture memory | 48 MB | 96 MB |
| Resident memory | 300 MB | 450 MB |
| Cold start to menu | 3 s | 6 s |
| Debug APK size | 70 MB | 120 MB |

Pools (allocated once at `setup`): enemy views 108, tracers 48, impact sparks 64, death bursts 24, floating
texts 24, EMP rings 2, SFX voices 16. Pool exhaustion drops the oldest visual; it never affects the sim.

Quality tiers change the view only (shadow on or off, omni lights, particle counts, rain, 3D render scale).
They never change the tick rate or any outcome.

### 13.1 Measured baseline on a real phone (`docs/reports/PHONE_PERF.md`)

The first real-device numbers, taken 2026-11-11 on the owner's phone (the Android emulator cannot present Vulkan, so no earlier
device number exists). One device, one run per row, **not a certification**; re-measure after every visual wave and before
release. Device: Pixel 11 Pro Fold (`yogi`), Android 17 (SDK 37), Tensor G6, ImgTec PowerVR C-Series CXTP-48-1536 MC1, Vulkan
1.4.317; the outer panel 1080x2342 (120 Hz, the game caps at 60); debug APK, Mobile renderer (`renderer=mobile/vulkan`), main
`74011e6`. Frame time at 50 living enemies (`--scenario=hold50 --debug-perf`, about 50 s per row, averages of the 5-second
`[PERF]` windows; `p95` is the mean of the windows' 95th-percentile frame time):

| Setting | fps | frame_ms | p95_ms | draws | prims |
|---|---:|---:|---:|---:|---:|
| HIGH (`--quality=2`), MSAA 4x (shipped default) | 55.7 | 17.95 | 32.5 | 137 | 40.6k |
| HIGH, MSAA off | 56.2 | 17.80 | 30.1 | 137 | 40.6k |
| HIGH, MSAA 2x | 56.0 | 17.85 | 31.7 | 137 | 40.6k |
| HIGH, `--look=current` (the old blocky Warden) | 56.5 | 17.70 | 29.3 | 130 | 38.5k |
| MID (`--quality=1`), MSAA 2x (default) | 57.0 | 17.54 | 28.3 | 131 | 28.7k |
| MID, MSAA off | 57.2 | 17.49 | 26.8 | 131 | 28.7k |
| LOW (`--quality=0`) | 60.0 | 16.67 | 21.8 | 131 | 28.7k |

What it says: MSAA is nearly free on this tile-based GPU (at most about 0.15 ms); the hard-surface look costs nothing
measurable for the Warden, the only styled actor at the time (17.95 against 17.70 ms is inside the noise); LOW holds a clean 60 fps; MID and HIGH sit near 56 fps with about 30 ms
hitches every 20th frame, so they are just over the 16.7 ms budget. The limiter is not MSAA and not the look; LOW renders at 0.75
scale, so pixel count is the leading suspect (**not yet proven**: no GPU profile was taken), and a render-scale option for MID
and HIGH is the next experiment. These numbers predate the character rollout (W3-D, since merged) and the environment look (W3-E, in progress), which add cost:
re-measure before choosing the default tier. A full autoplay run (`--autoplay=greedy --seed=1`) finishes in 4:53 with VICTORY, 5/5 waves, core 704/1000, 384
kills, +135 Recovered Data on the phone as on the desktop, with no crash since the audio loop fix (section 10). Not measured yet:
thermal throttling over a long session, battery drain, background and resume, safe areas on other devices, other GPUs (Adreno,
Mali), touch input by a human.

### 13.2 Variety milestone budgets (V)

Draw calls are the cost that scales with enemies (one pooled `MeshInstance3D` per bodied enemy, up to 3 surfaces), and MID and
HIGH are already at the edge, so the variety design does **not** raise the bodied cap: it adds up to 40 instanced minis (about
4 draw calls) instead of 40 more bodied enemies (up to 120). The sim cost of a mini is about a quarter of a body (it skips
separation, slots and stuck checks), so the estimated tick at 50 + 40 is the 0.6 ms / 2.0 ms row of the table above.

New pools, allocated once at `setup`; exhaustion drops the oldest visual and never affects the sim. Caps are per tier:

| Pool | Cap LOW / MID / HIGH | Draw calls | Used by |
|---|---|---:|---|
| Mini bodies (2 types) | 40 / 40 / 40 each | 4 | mote, shard |
| Blast rings (FLAT) | 8 / 12 / 16 | 1 | every blast |
| Blast flashes (BILLBOARD) | 0 / 8 / 12 | 1 | every blast (not on LOW) |
| Arc segments (SEGMENT) | 18 / 30 / 45 | 1 | arc projector, shock rounds, pylons, core lash |
| Beam segments | 2 / 2 / 3 | 1 | torch, lance charge and shot, Lance Platform beam |
| Lobbed projectiles (BILLBOARD), three pools with one colour each (V4-X): shells 4 + hornets up to 20, together 12 / 18 / 24; spitter bolts 12 on every tier (an enemy projectile is never tier-gated) | 12 / 18 / 24 + 12 | 3 | mortar shells (amber), hornets (cyan), spitter bolts (red) |
| Ground pools (FLAT) | 6 / 8 / 10 | 1 | slag, burn |
| Telegraph decals (FLAT, hatched) | 8 / 8 / 8 | 1 | lanes, rings, cracks |
| Ward and aura rings (FLAT) | 8 / 10 / 12 | 1 | shieldbearer, warded, overclocker, jammer |
| Elite rings | 4 / 4 / 4 | 1 | elites |
| Tether lines (SEGMENT) | 6 / 9 / 12 | 1 | reclaimer, magnetic |
| Scorch marks (FLAT, persistent ring) | 0 / 8 / 16 | 1 | after blasts |
| Ghost swarm (cosmetic) | 0 / 40 / 80 | 1 | outside the playable rectangle |
| Crate, strike column, freight car, drums | 1 + 1 + 1 + 3 nodes | 6 to 8 | events |
| Existing: tracers 48, sparks 64, bursts 24, texts 24 | unchanged | - | - |

The existing EMP ring pool is 2 (SPEC 10.3 lists "2 to 6" for it; V2-F fixes the final number together with the blast rings).
Worst-case addition: about 22 draw calls on LOW and 28 on HIGH. With the measured 137 on HIGH that is about 165: over the 150
target, under the 220 limit. That is the number task V2-P measures first on the phone (including `--scenario=hold50+40` and
`--scenario=chain`); if it does not hold, the cut order is: ghost swarm, scorch marks, flashes, tether lines, then the optional
task V4-X2 (draw **all** enemies of a type as one transform-only MultiMesh, which would cut about 50 to 100 draw calls but
replaces the material-swap hit flash with a transform pop and needs the hard-surface look ported). Per-effect guesses to be
measured at the cap on HIGH: minis 0.3 ms; a 6-blast chain 0.4 ms for 0.3 s; 45 arc segments 0.2 ms; 10 pools 0.3 ms (alpha
overdraw is the risk: pools are small and never stacked more than 2 deep by a view rule); ghost swarm 0.2 ms; bloom is unchanged.

Audio budget: 16 voices stay; 3 are reserved for the alert class and the weapon class may use at most 8 (section 10).
Stress: `test_stress_ten_minutes` (the flood of the generated run) and its variant `test_stress_chain` (V5-A: 50 bodied and 40 minis held alive with a blast every second) both hold the limit of 1.0 ms per tick on the desktop. They are wall-clock benchmarks: on a loaded machine they are run again, their budget is never edited.

---

## 14. Reconciliation with the handoff technical docs

Adopted as written: Godot 4.7.2 and GDScript; portrait; 60 Hz fixed tick with a capped accumulator; seeded
RNG; stable integer enemy ids and id tie-breaks; command stream for replay; presentation reads events and
interpolates; the combat and cost formulas; the targeting priority list and 0.4 s lock; attack slots near the
core; flow field + spatial hash + capped separation instead of per-agent navigation; purchase transaction
rules and command ids; `user://profile_v1.json` with temp write, backup and reward-once per run id; the ten
signals; the five commands; the state list and the wave-complete rule; pooled visuals, shared materials, few
lights, no GI; the UI zones, 48 dp targets and safe areas; the test plan and acceptance matrix.

Deviations:

| # | Handoff says | This architecture | Why |
|---|---|---|---|
| D1 | Mobile renderer (Vulkan) | **Adopted as-is: Mobile (Vulkan).** Owner decision 2026-11-11, which overrides the earlier Compatibility proposal | Vulkan has never been validated on the `tower_phone` emulator (Intel iGPU), so W1-H must prove it early. The boot line `game boot version=<v> renderer=<name>` must show the Mobile/Vulkan renderer on desktop and on the emulator. `rendering_device/fallback_to_opengl3=true` keeps the app from crashing on a device with no Vulkan, but a fallback on the test targets is a defect to report, not a pass. Content stays on `StandardMaterial3D` plus simple unshaded shaders, and per-instance MultiMesh data stays transform-only, so the look holds if a fallback ever happens |
| D2 | Scene-owned system nodes; `SaveManager` the only autoload | Pure `RefCounted` sim with static systems; six autoloads (`Log`, `Events`, `Content`, `Save`, `Sfx`, `Game`) | A node-free sim is what makes headless determinism tests fast and exact (proven in the original). A fresh `SimWorld` per run gives the clean reset the handoff wanted. Named autoloads let parallel agents code against fixed entry points |
| D3 | `scenes/` + `scripts/` tree | `src/<layer>/` with co-located thin scenes | Directory ownership for parallel tasks |
| D4 | Typed `Resource` (`.tres`) for authored data | JSON loaded through a strict adapter into typed `RefCounted` defs | Allowed by `03_DATA/README.md`; avoids export pitfalls with `.tres`; one source of truth |
| D5 | Def fields `visual_scene`, `pierce`, `seed_offset`, per-wave `intermission_seconds`, `effect` | `visual_id` (procedural builders), piercing is an upgrade level, spawn randomness derives from (wave, group, ordinal), one mission-wide intermission, ability effect is the ability id | The JSON has none of these fields; simpler and equivalent for the slice |
| D6 | Steering at 10 to 20 Hz, interpolated | Steering every tick (60 Hz) | 50 agents cost well under 0.3 ms per tick; one rate is simpler and exact |
| D7 | `RunState` data class | `SimWorld` is the run state; `RunSummary` is the exported result | Avoids a second copy |
| D8 | `purchase_upgrade(command_id, upgrade_id)` etc. as free commands | Same names and parameters, on `RunApi`; `pause`/`resume` are application-level and never enter the replay log | Pausing does not change sim outcomes |
| D9 | Raycast obstruction policy "explicit and tested" | Hitscan ignores props, by rule and by test | Keeps targeting deterministic and cheap; props are low cover |
| D10 | `tools/*.sh` | PowerShell + Python wrappers adapted from the original project | The host is Windows; the originals already handle Godot's exit-code and hang problems |
| D11 (V) | Five fixed waves and a fixed upgrade tree (the handoff's `waves.json`, five upgrades bought with Scrap, `profile_v1.json`, "the five commands") | Generated 15-wave, three-act runs from a seeded run plan; 1-of-3 directive drafts replace the upgrade purchases; ten weapons; profile v2 and a resumable run file. The five-wave content stays as the legacy test fixture, and every change to the contracts above is append-only | Owner decision 2026-11-11 (the variety milestone, decisions D1 to D8 of GDD 14; SPEC 17.2). It supersedes the handoff decision log's fixed-five-waves scope and its "other weapons are future roadmap only" |

The "adopted as written" list above describes the five-wave slice; where it names the fixed waves, the upgrade purchases, the
five commands or `profile_v1.json`, D11 applies on top of it (the old behaviour is the legacy fixture, the new one is marked
**(V)** in the sections above).
