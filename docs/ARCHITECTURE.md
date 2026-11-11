# IRON STATIC: CINDERFALL - Technical Architecture and Contracts

Version 1.0, 2026-11-10. This document is the technical source of truth. `GAME_DESIGN.md` is the source of
truth for rules and numbers. If they conflict, stop and report; do not guess.

**How to use this file.** Sections 4 to 12 are contracts. A task may not change a signature, signal, field
name, file path or schema defined here. If a contract is wrong or missing something, the agent stops, writes
the problem and a proposed fix in its report, and codes against the contract as written.

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
    integration/{sim,game}/   stress/   fixtures/   canary/
  tools/         GODOT_VERSION GDUNIT_VERSION _common.ps1 check.ps1 test.ps1 test_runner.py compile_check.gd
                 compile_gate.py lint_layers.py capture.ps1 sim_run.gd sim_run.ps1 balance_run.gd balance_run.ps1
                 run_emulator.ps1 deploy_android.ps1 smoke_android.ps1 audio_gen/
  build/         outputs; contains `.gdignore`; git-ignored
```

Deviation D3: the handoff proposes `scenes/` + `scripts/`. This layout co-locates each thin scene with its
script under `src/<layer>/` so directory ownership maps one-to-one onto parallel tasks.

---

## 4. Shared enums and ids (`src/shared/`, complete in Wave 0, frozen)

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
enum Id { WARDEN = 0, TURRET_0 = 1, TURRET_1 = 2 }

class_name Reason               # src/shared/reason.gd  (command outcomes)
enum Id { OK, WRONG_STATE, UNKNOWN_ID, MAX_LEVEL, INSUFFICIENT_SCRAP, PREREQ_NOT_MET,
          DUPLICATE_COMMAND, ON_COOLDOWN, ALREADY_ACTIVE, PAUSED }
static func string_key(id: int) -> String        # e.g. "reason.insufficient_scrap"

class_name Ids                  # src/shared/ids.gd  (index = position in these arrays, fixed forever)
const ENEMIES: Array[StringName] = [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk"]
const WEAPONS: Array[StringName] = [&"pistol", &"smg"]
const UPGRADES: Array[StringName] = [&"damage", &"fire_rate", &"armor_piercing", &"auto_turret", &"smg_unlock"]
const ABILITIES: Array[StringName] = [&"emp", &"shield", &"overdrive"]
const UP_DAMAGE := 0; const UP_FIRE_RATE := 1; const UP_ARMOR_PIERCING := 2; const UP_AUTO_TURRET := 3; const UP_SMG := 4
const AB_EMP := 0; const AB_SHIELD := 1; const AB_OVERDRIVE := 2
const EN_SKITTER := 0; const EN_HOLLOW := 1; const EN_RUSHER := 2; const EN_HULK := 3
static func enemy_index(id: StringName) -> int   # -1 if unknown; same for weapon_index, upgrade_index, ability_index
```

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
| `data/strings/*_en.json` | new | flat `{ "key": "text" }` maps; fixed file list `content, combat, screens, lore` |

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
  "camera": { "pitch_down_deg": 60.0, "yaw_deg": 0.0, "frame_margin_m": 0.5, "decor_yaw_deg": 38.0 }
}
```

Slot angle convention: angle 0 points along +X (screen right), positive angles turn toward -Z (screen up).
Slot `k` of a ring with `n` slots sits at `arc_start + (k + 0.5) * (arc_end - arc_start) / n`. Slot indices
run ring 0 first (0..9), then ring 1 (10..23), ring 2 (24..41), ring 3 (42..63).

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

### 5.4 Loader, validator, autoload

```gdscript
class_name ContentLoader extends RefCounted            # src/content/content_loader.gd
static func load_from_dir(dir: String) -> ContentLoadResult     # dir = "res://data"
static func build(balance: Dictionary, waves: Dictionary, tokens: Dictionary, ext: Dictionary,
                  arena: Dictionary, strings: Dictionary) -> ContentLoadResult

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
calls `FlowField.build`); Warden and pads inside bounds; palette has the six tokens.

`Content` autoload (`src/content/content_db.gd`, `extends Node`):

```gdscript
var db: ContentSet                     # valid after _ready; never null in a running game (named db: `set` is an Object method)
var load_errors: PackedStringArray
func reload() -> bool                  # re-reads res://data; true on success
```

On success it logs `content ok enemies=4 waves=5 hash=<sha256 of the raw files, first 12 chars>`.
On failure it logs `ERROR: Content: <message>` per error (this fails tests and the smoke test by design).

`Strings` (`src/core/strings.gd`): `static func t(key: String) -> String` returns the text or the key itself
wrapped as `#key#` (and logs once per missing key); `static func tf(key: String, args: Array) -> String`.

---

## 6. Simulation (`src/sim/`)

### 6.1 Time and determinism

- Fixed **60 ticks per second** (`SimWorld.TICK_RATE`, also in the balance JSON; the loader rejects a mismatch).
- Every timer is an integer tick count. Fire cadence uses an integer accumulator (6.5).
- Randomness only through `SimRng` (seeded `RandomNumberGenerator` instances, one per named stream:
  `spawn`, `steer`). Adding a stream never disturbs the others.
- Positions are `float` (64-bit). Determinism is guaranteed for the same build on the same architecture.
- Ordering ties always break on the stable enemy id (monotonic from 1, never reused within a run).
- Commands are the only external input. They are applied at the start of the tick after they were submitted,
  in submission order, and recorded in `CommandLog` with their tick.

### 6.2 `SimWorld` (Wave 0 writes it completely, including `step()`; systems are filled in by Wave 1)

```gdscript
class_name SimWorld extends RefCounted
const TICK_RATE: int = 60
const DT: float = 1.0 / 60.0

var config: SimConfig
var content: ContentSet                 # == config.content
var tick: int = 0
var phase: int = GameState.Id.PREPARING
var wave: int = 0                       # 0 while PREPARING, then 1..5
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

func _init(cfg: SimConfig) -> void
func step() -> void                                   # exactly one tick; no-op when is_over()
func submit(cmd: SimCommand) -> void                  # queue for the next tick
func is_over() -> bool                                # phase is VICTORY or DEFEAT
func result() -> int                                  # RunResult.Id
func state_hash() -> String                           # sha256 hex over all sim state (see StateHasher)
func summary(run_id: String) -> RunSummary

# shared mutators: the ONLY way these things may change
func set_phase(new_phase: int) -> void                # validates via GameStateMachine.can_transition; pushes PHASE_CHANGED
func add_scrap(delta: int) -> void                    # clamps at 0; pushes SCRAP_CHANGED; updates stats
func spawn_enemy(type_index: int, x: float, z: float) -> int      # store index, or -1 at capacity; pushes ENEMY_SPAWNED (+ BOSS_SPAWNED)
func kill_enemy(index: int, source: int) -> void      # exactly-once: no-op if not alive; scrap, stats, ENEMY_KILLED,
                                                      # NavSystemHooks.on_enemy_removed, store free
func set_core_hp(value: float) -> void                # clamps 0..max; pushes CORE_CHANGED

# read-only queries
func alive_count() -> int
func upgrade_cost(upgrade_index: int) -> int          # -1 at max level
func purchase_block_reason(upgrade_index: int) -> int # Reason.Id; OK when purchasable now
func ability_block_reason(ability_index: int) -> int
func boss_store_index() -> int                        # -1 when no boss alive
```

**Tick order** inside `step()` (fixed; Wave 0 implements it as calls to the static system functions):

```
 1  tick += 1
 2  CommandSystem.apply_queued(self)          # purchases, abilities, skip; in submission order
 3  PhaseSystem.pre_step(self)                # countdowns; PREPARING/INTERMISSION -> SPAWNING; SpawnSystem.begin_wave
 4  SpawnSystem.step(self)                    # scheduled spawns + pending queue, respecting the cap
 5  AbilitySystem.step(self)                  # ability timers, stun and immunity countdowns, shield expiry
 6  MovementSystem.step(self)                 # prev_x/prev_z copy, flow, separation, slots, stuck recovery
 7  WeaponSystem.step(self)                   # Warden: target, fire, reload
 8  TurretSystem.step(self)                   # active turrets: target, fire
 9  CoreAttackSystem.step(self)               # enemies in slots hit the core (shield first)
10  PhaseSystem.post_step(self)               # DEFEAT if core_hp <= 0; SPAWNING -> CLEARING; CLEARING -> INTERMISSION/VICTORY
11  stats.sample(self)                        # peak alive per wave, duration
```

Steps 4 and 6 to 9 are skipped unless `GameState.is_combat(phase)`. Step 5 runs in every non-terminal phase.

### 6.3 Config, commands, events, hashing, RNG

```gdscript
class_name SimConfig extends RefCounted
var run_seed: int
var content: ContentSet
var debug_invulnerable_core: bool = false
var debug_damage_mult: float = 1.0
var debug_start_scrap: int = 0
static func create(content_set: ContentSet, seed_value: int) -> SimConfig

class_name SimCommand extends RefCounted
enum Kind { PURCHASE, ABILITY, SKIP_INTERMISSION }
var command_id: int            # unique per run, > 0
var kind: int
var arg: int                   # upgrade index or ability index; 0 for SKIP
var tick: int = -1             # filled in by SimWorld when applied
static func purchase(command_id_value: int, upgrade_index: int) -> SimCommand
static func ability(command_id_value: int, ability_index: int) -> SimCommand
static func skip(command_id_value: int) -> SimCommand

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

**Event kinds** (`src/sim/sim_event_kind.gd`, `class_name SimEventKind`, `enum Id`). Payload columns are the
`SimEvent` fields; unused ones are 0.

| Kind | a | b | f | g | Pushed by |
|---|---|---|---|---|---|
| `PHASE_CHANGED` | previous | current | | | `SimWorld.set_phase` |
| `WAVE_STARTED` | wave (1..5) | total enemies | | | PhaseSystem |
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
| `ENEMY_REACHED_SLOT` | enemy id | slot index | | | MovementSystem |
| `ENEMY_STUCK` | enemy id | recovery count | | | MovementSystem |
| `SPAWN_QUEUED` | pending count | | | | SpawnSystem |
| `RUN_FINISHED` | RunResult | waves completed | core hp | | PhaseSystem |

### 6.4 Stores (complete in Wave 0, frozen; a task that needs more state puts it in its own `*State` class)

```gdscript
class_name EnemyStore extends RefCounted
const ST_MOVING: int = 0
const ST_SEEK_SLOT: int = 1
const ST_ATTACKING: int = 2
var capacity: int                         # enemy_cap + 8
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
var kills_by_type: PackedInt32Array           # size 4
var peak_alive_by_wave: PackedInt32Array      # size 6, index = wave
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
`alive_count() >= enemy_cap` the spawn goes to the FIFO pending queue (`SPAWN_QUEUED`).

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

class_name PhaseSystem
static func init_world(world: SimWorld) -> void        # PREPARING with prepare_ticks
static func pre_step(world: SimWorld) -> void
static func post_step(world: SimWorld) -> void
static func skip_intermission(world: SimWorld) -> int  # Reason.Id

class_name PhaseState extends RefCounted
func hash_into(h: StateHasher) -> void
```

Rules: purchases are legal in PREPARING, SPAWNING, CLEARING and INTERMISSION (else `WRONG_STATE`); check
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
`waves_completed += 1`, `INTERMISSION_STARTED`), or to VICTORY after wave 5; INTERMISSION counts
`intermission_ticks` (or is skipped) then the next wave; DEFEAT the tick `core_hp <= 0`, from SPAWNING or
CLEARING, checked before the wave-clear check. Terminal phases push `RUN_FINISHED` once.

### 6.7 Replay and bot (task W2-D)

```gdscript
class_name Replay extends RefCounted
static func run(config: SimConfig, log: CommandLog, max_ticks: int) -> SimWorld      # re-submits each command at its tick
class_name PolicyBot extends RefCounted
enum Policy { NONE, GREEDY }
func _init(policy_value: int) -> void
func act(world: SimWorld) -> void       # submits commands; deterministic; GREEDY = cheapest affordable upgrade by a fixed
                                        # priority, EMP when >= 12 enemies are attacking, shield when core is hit, overdrive when the boss is alive
```

---

## 7. Game layer (`src/core/`, `src/game/`)

### 7.1 Event bus (`Events` autoload, `src/core/event_bus.gd`, complete in Wave 0)

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
```

`RunController` is the only emitter of the gameplay signals. It drains `sim.events` after the ticks of each
frame and emits in order. Subscribers must not assume a signal arrives on the tick it happened, only in order.

### 7.2 Run API (the UI's only door to gameplay; `src/game/run_api.gd`, complete in Wave 0)

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
```

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
func set_paused(value: bool) -> void
func stop() -> void                               # unbinds the view, frees the sim
func _process(delta: float) -> void               # if not paused: driver.advance; drain events -> Events; view.render(alpha)
```

When the sim pushes `RUN_FINISHED`, `RunController` computes `Formulas.data_reward`, calls
`Save.grant_run_reward(...)` (7.5), then emits `Events.run_finished`. Reward granting never lives in UI code.

### 7.4 `Game` autoload (`src/core/game.gd`; Wave 0 stub, task W2-A implements)

```gdscript
var machine: GameStateMachine
var run: RunController                    # null outside a run
var battle_view: BattleView               # null outside a run
func boot(root: Node) -> void             # called once by src/core/main.gd; builds layers; BOOT -> MENU
func goto_menu() -> void
func goto_briefing() -> void
func start_run(run_seed: int = -1) -> void    # -1 = time-based seed; creates the run id "<unix>-<seed>"
func restart_run() -> void
func pause_run() -> void
func resume_run() -> void
func quit_to_menu() -> void
func open_settings() -> void
func request_back() -> void               # Android back, via BackPolicy
func state() -> int
```

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
`Game.request_back()`. The game stays paused after returning until the player taps RESUME.

`BackPolicy` (pure): `static func decide(state: int, drawer_open: bool, overlay_open: bool) -> int` returning
`enum Action { CLOSE_OVERLAY, CLOSE_DRAWER, PAUSE, RESUME, TO_MENU, CONFIRM_QUIT, NONE }`.

`Haptics`: `static func tick(ms: int = 20) -> void` (no-op unless Android and the setting is on).

### 7.5 Save system (`src/save/`, task W1-D)

File `user://profile_v1.json` (+ `.tmp`, `.bak`). Plain JSON, human-readable.

```json
{ "schema_version": 1, "data": 0, "missions_completed": 0, "best_core_hp": 0,
  "runs_played": 0, "awarded_run_ids": [], "hints_seen": [],
  "settings": { "sound_on": true, "music_on": true, "haptics_on": true, "reduced_flash": false,
                "high_contrast": false, "quality": 2, "fps_cap": 60 } }
```

```gdscript
class_name Profile extends RefCounted
const SCHEMA_VERSION: int = 1
var data: int; var missions_completed: int; var best_core_hp: int; var runs_played: int
var awarded_run_ids: PackedStringArray       # newest last, capped at 64
var hints_seen: PackedStringArray
var settings: Dictionary[StringName, Variant]
static func defaults() -> Profile

class_name ProfileCodec extends RefCounted
static func encode(p: Profile) -> String
static func decode(text: String) -> ProfileDecodeResult     # .profile (or null), .error: String, .schema_version: int
    # validates types and ranges; clamps negatives to 0; unknown keys ignored; never executes or loads paths from the file

class_name SaveFs extends RefCounted          # interface; DiskSaveFs (user://) and MemorySaveFs (tests)
func read(path: String) -> String             # "" when missing
func write(path: String, text: String) -> bool
func exists(path: String) -> bool
func rename(from: String, to: String) -> bool # DiskSaveFs removes the target first (Windows)
func remove(path: String) -> bool

# Save autoload, src/save/save_manager.gd, extends Node
enum LoadStatus { OK, NEW_PROFILE, RECOVERED_FROM_BACKUP, RESET_AFTER_CORRUPTION, NEWER_SCHEMA_SET_ASIDE }
var profile: Profile
var last_load_status: int
func use_fs(fs: SaveFs) -> void                               # tests inject MemorySaveFs, then call load_profile()
func load_profile() -> int
func flush() -> bool                                          # write tmp, verify by re-reading, keep previous as .bak, rename
func grant_run_reward(run_id: String, result: int, data_amount: int, core_hp: int) -> bool
    # false and no change if run_id is already in awarded_run_ids; otherwise adds data, updates
    # missions_completed (victory), best_core_hp (victory, max), runs_played, appends run_id, flushes, emits profile_changed
func get_setting(key: StringName) -> Variant
func set_setting(key: StringName, value: Variant) -> void     # validates key and type, flushes, emits settings_changed
func mark_hint_seen(key: String) -> void
func has_seen_hint(key: String) -> bool
```

Load order: main file; if missing, `NEW_PROFILE`; if unreadable or invalid, try `.bak`
(`RECOVERED_FROM_BACKUP`); if that fails too, move the bad file to `profile_v1.json.corrupt` and start fresh
(`RESET_AFTER_CORRUPTION`). A file with a higher `schema_version` is copied to
`profile_v1.json.newer` and never overwritten in place (`NEWER_SCHEMA_SET_ASIDE`). No status crashes the game.
There is no mid-run save.

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
func set_reduced_flash(on: bool) -> void

class_name CameraRig extends Node3D                # task W1-E
var camera: Camera3D                               # PROJECTION_ORTHOGONAL, KEEP_HEIGHT; pitch from arena.pitch_down_deg
func setup(arena: ArenaDef, tokens: VisualTokens) -> void
func fit(viewport_size: Vector2, top_px: float, bottom_px: float) -> void
func world_to_screen(world: Vector3) -> Vector2
func pitch_down_deg() -> float

class_name CameraFit extends RefCounted            # pure math, unit-tested without a renderer
static func solve(arena: ArenaDef, viewport_size: Vector2, top_px: float, bottom_px: float) -> CameraFitResult
class_name CameraFitResult extends RefCounted
var ortho_size: float; var position: Vector3; var basis: Basis; var px_per_meter: float

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
- **One pooled `Node3D` per enemy** with one `MeshInstance3D` (merged mesh, at most 3 surfaces). Pool sizes:
  skitter 50, hollow_warden 24, rusher 32, siege_hulk 2. No allocation after `setup`. Map enemy id to pool
  entry on `enemy_spawned`, release on `enemy_killed`. On `bind`, adopt every enemy already alive in the store.
- Hit flash = swap `material_override` to `flash_white` for 3 frames. No per-instance shader data (the
  original project found per-instance attributes unreliable on a PowerVR phone GPU).
- Blob shadows and world health bars are transform-only `MultiMeshInstance3D`s (one draw call each).
- Motion is procedural: bob, lean, stomp, recoil, Warden upper-body yaw toward `warden.aim_x/aim_z`.
- No physics bodies, no collision shapes, no `NavigationAgent3D`, no `AnimationTree` in the slice.
- `WorldEnvironment`: no glow, no SSAO, no SSR, no fog volumes. One `DirectionalLight3D`; shadows off on LOW
  and MID, on for static props only on HIGH. At most 4 unshadowed `OmniLight3D` on HIGH, 0 on LOW.
  Everything else is emissive material or additive quads.
- Every shader or material variant is drawn once during the boot screen (`ShaderWarmup` helper in
  `src/view/kit/`, alpha 0.02, 2 frames) so the first shot does not hitch.

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
| `screens/main_menu_screen.tscn` | `MainMenuScreen` | `setup(profile: Profile)` | `start_pressed`, `settings_pressed`, `quit_pressed` |
| `screens/briefing_screen.tscn` | `BriefingScreen` | `setup(content: ContentSet)` | `deploy_pressed`, `back_pressed` |
| `screens/results_screen.tscn` | `ResultsScreen` | `setup(summary: RunSummary, content: ContentSet, profile: Profile, reward_granted: bool)` | `retry_pressed`, `menu_pressed` |
| `screens/settings_screen.tscn` | `SettingsScreen` | `setup()` (reads and writes `Save`) | `closed` |
| `combat/combat_hud.tscn` | `CombatHud` | `setup(api: RunApi, content: ContentSet, view: BattleView)` (`view` may be null) | `pause_requested` |
| `combat/pause_overlay.tscn` | `PauseOverlay` | `setup()` | `resume_pressed`, `restart_pressed`, `settings_pressed`, `quit_pressed` |

`CombatHud` also has `func is_drawer_open() -> bool`, `func close_drawer() -> void`,
`func top_band_px() -> float`, `func bottom_band_px() -> float`.

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

---

## 11. Debug, capture and command-line arguments (`src/debug/`)

User arguments come after `--`. On Android they are baked through the preset option
`command_line/extra_args` (never committed with debug values).

| Argument | Effect |
|---|---|
| `--seed=<int>` | Fixed run seed |
| `--autoplay[=none\|greedy]` | Skip menus, start a run, `PolicyBot` plays |
| `--scenario=hold<N>` | Debug run: invulnerable core, hold N enemies alive (perf) |
| `--debug-perf` | `PerfHud` + a `[PERF]` log line every 5 s |
| `--mute` | No audio |
| `--quality=<0..2>` | Force a quality tier |
| `--quit-after-run` | Quit with code 0 once the results state is reached (W2-A) |
| `--capture-run=<abs dir>` | With `--autoplay`: save window screenshots at fixed moments of the run (W3-B) |
| `--capture-scene=<res path>` `--capture-out=<abs png>` `--capture-size=<WxH>` `--capture-frames=<n>` | Render the scene in a `SubViewport` of that size, save a PNG after n frames, quit |

`[PERF]` line format (parsed by `smoke_android.ps1`):
`[PERF] fps=<avg> min=<worst 1s> frame_ms=<avg> p95_ms=<p95> tick_ms=<avg sim tick> enemies=<alive> draws=<n> prims=<n> vid_mb=<n>`.

`SimPuppet` (`src/debug/sim_puppet.gd`): builds a real `SimWorld`, then drives the stores and `Events`
directly (spawns N enemies of each type, walks them toward the core on straight lines, fires fake shots and
kills) so the view can be built before the simulation exists. `view_sandbox.tscn` = `BattleView` + `SimPuppet`.
`hud_sandbox.tscn` = `CombatHud` + `FakeRunApi` cycling through states.

---

## 12. Tooling contracts (`tools/`, Wave 0 unless noted)

| Script | Purpose | Success signal |
|---|---|---|
| `check.ps1 [-Path <res paths>] [-SkipTests]` | import, compile gate (warnings as errors), layer lint, tests | exit 0 and last line `CHECK OK` |
| `test.ps1 [-Path a,b] [-Suite name] [-Canary]` | import, GdUnit4 run, parse output and JUnit XML | exit 0 and last line `TEST SUMMARY: tests=N failures=0 errors=0 skipped=S exit=0` with N > 0 |
| `capture.ps1 -Scene <res> -Out <png> [-Size 1080x2400] [-Frames 90]` | desktop screenshot through the real renderer (not headless) | exit 0, PNG exists, not blank |
| `sim_run.ps1 -Seed n -Policy greedy\|none [-Runs k]` (W2-D) | headless full runs, prints result, duration, peaks, hashes | exit 0, line `SIM SUMMARY: ...` |
| `balance_run.ps1 -Runs k` (W2-D) | compares runs with the targets in GAME_DESIGN 8.4 | exit 0 PASS or WARN, 1 FAIL |
| `run_emulator.ps1`, `deploy_android.ps1`, `smoke_android.ps1` (W1-H) | emulator boot; export, install, launch; log and screenshot checks | `== RUNNING (pid n)`; `SMOKE OK` |

Exit codes of `test.ps1`: 0 pass, 1 test failure, 2 script or parse error in the output, 3 zero tests,
4 tool failure. Headless Godot can exit 0 after an error, so **nothing may judge a run by Godot's own exit
code**; the wrappers parse the output. `test.ps1` sets `APPDATA` to `build\test_appdata` so parallel
checkouts never share `user://`. `-Path` accepts a comma-separated list and splits it itself.

---

## 13. Performance budgets (reference: mid-range 2020 phone; measured numbers go in `docs/reports/`)

| Budget | Target | Hard limit |
|---|---|---|
| Frame time, 50 enemies, wave 5 | 16.7 ms | 33.3 ms (30 FPS fallback: `fps_cap` 30, quality LOW) |
| Sim tick, 50 enemies (desktop headless) | 0.3 ms | 1.0 ms |
| Sim tick on phone | 1.0 ms | 3.0 ms |
| Ticks per frame | 1 at 60 FPS, 2 at 30 FPS | 4 (then time is dropped) |
| Draw calls in combat (3D + UI) | 150 | 220 |
| Triangles on screen | 120 k | 200 k |
| Live particles / VFX quads | 200 | 400 |
| Tracers alive | 24 | 48 |
| Floating texts | 12 | 24 |
| Lights | 1 directional + 4 omni (HIGH) | - |
| Texture memory | 48 MB | 96 MB |
| Resident memory | 300 MB | 450 MB |
| Cold start to menu | 3 s | 6 s |
| Debug APK size | 70 MB | 120 MB |

Pools (allocated once at `setup`): enemy views 108, tracers 48, impact sparks 64, death bursts 24, floating
texts 24, EMP rings 2, SFX voices 16. Pool exhaustion drops the oldest visual; it never affects the sim.

Quality tiers change the view only (shadow on or off, omni lights, particle counts, rain, 3D render scale).
They never change the tick rate or any outcome.

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
