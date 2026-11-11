# IRON STATIC: CINDERFALL — Android Vertical Slice Technical Specification

**Version:** 1.0 draft · **Date:** 2026-11-09 · **Status:** implementation-ready proposal, not implemented

## 0. Agent execution contract

Build a separate Godot 4.7.2 project or a separate isolated game module; do not modify the original Iron Static game without explicit approval. Preserve established IP names and lore, but do not confuse Cinder (ASH-07) with the new playable Warden. Original repository: https://github.com/paimonsoror/iron-static . Read `README.md`, `CLAUDE.md`, `docs/design/`, `docs/TECH_ARCHITECTURE.md`, and existing test/build scripts before reusing anything. Original repo uses Godot 4.7.2, GdUnit4, Android build scripts and an existing deterministic combat/economy/save framework; inspect APIs before adapting. No assumption of binary compatibility. Prefer a new sibling repository `iron-static-cinderfall` with attribution to source project and no copied third-party assets without license review.

**Definition of done:** a five-wave offline Android APK, 3D portrait battlefield, stationary auto-firing defender, four enemy classes plus boss, scrap upgrades, three active abilities, deployable turret, win/loss, local data persistence, deterministic headless tests, reproducible debug export, and documented performance metrics. Never report a test as passed without executing it.

## 1. Core game loop

1. Main menu → mission briefing → deploy.
2. Spawn the Warden at the left beside a 1,000-HP relay core; enemy spawn positions are at the right.
3. Auto-target and auto-fire without player input. Enemies traverse three visual depth lanes and attack the core on arrival.
4. Kills grant Scrap instantly; tap upgrades to purchase. Upgrades are available during combat; a purchase opens a 0.25-second visual confirmation, **without** changing simulation speed. Between waves there is an 8-second preparation phase with optional early-continue.
5. EMP, Shield and Overdrive are player-triggered and cooldown gated.
6. Complete all five waves and defeat boss and escorts → victory; core HP reaches zero → defeat.
7. Result screen grants Recovered Data; persist mission completion and cumulative data atomically.

Target duration 4:30–6:00 on first completion. This is an experience target, not a fixed wave timer. Wave end is determined by all scheduled spawns exhausted and all live enemies killed; avoid deadlock if an enemy gets stuck by implementing a timeout recovery and debug diagnostics. If player damage is insufficient, the mission can fail by core attrition.

## 2. Visual, camera, screen layout

- Portrait reference: 1080×2400 logical reference; use stretch mode canvas_items and appropriate aspect handling, safe-area insets, dynamic anchors and touch target minimum 48dp.
- 3D coordinates: X = battlefield travel axis; Warden at x=-8; core x=-10; spawn x=+12; breach at x=-9. Z = depth lanes [-2.4, 0, +2.4]. Y = vertical. All positions configurable in `battlefield.tres`.
- Camera: fixed orthographic Camera3D at (-1, 17, 19), looking at (1,0,0), orthographic size tuned to show x[-11,+13] and three lanes. The orthographic size and camera framing must be calibrated on an actual portrait device; no fixed pixel-to-world assumption.
- Camera angle should retain readable enemy silhouettes, avoid HUD overlap and preserve left-to-right motion.
- HUD: top 10–12% core HP, wave number, scrap and pause; center 60–65% battlefield; bottom 23–28% upgrades and three ability buttons. Do not show decorative weapon cards that imply equip options unsupported by the slice.
- Cyan = allied/active systems (#39C9DB), amber = core/resources (#F1A34A), red = enemies (#D94D4D), charcoal = background (#101820). High contrast; never use color as sole status signal.
- Rendering: Godot Mobile renderer, baked/static lighting when possible, one key directional light, cheap localized VFX, limited transparent particles, LOD and material instancing. Aim 60 FPS on capable phones, graceful 30 FPS mode. Avoid runtime real-time GI and costly full-screen post-processing.
- 3D art is separate from UI Control nodes. Generated concept images are **not** 3D assets and must not be baked into gameplay screens.

## 3. Proposed project tree

```
project.godot
addons/gdUnit4/                   # if compatible and licensed
assets/
  models/{warden,enemies,weapons,turret,environment}/
  textures/{materials,ui}/
  vfx/  audio/{sfx,music}/  fonts/
scenes/
  app/main.tscn
  ui/{main_menu,mission_briefing,combat_hud,upgrade_panel,pause_menu,results}.tscn
  combat/{battlefield,warden,enemy_base,projectile,auto_turret,relay_core}.tscn
  enemies/{skitter,hollow_warden,rusher,siege_hulk}.tscn
scripts/
  app/{game_root,run_director,save_manager}.gd
  combat/{combat_director,wave_director,target_selector,weapon_controller,
          enemy_controller,enemy_movement,damage_resolver,core_controller,
          turret_controller,ability_system,economy_system,upgrade_system}.gd
  ui/{combat_hud,upgrade_panel,results_screen}.gd
  data/{weapon_def,enemy_def,wave_def,upgrade_def,ability_def,mission_def}.gd
  utilities/{rng_service,object_pool,combat_clock}.gd
data/
  missions/mission_001.tres
  waves/wave_01.tres ... wave_05.tres
  enemies/*.tres weapons/*.tres upgrades/*.tres abilities/*.tres
  balance/vertical_slice_balance.json
tests/{unit,integration,smoke}/
tools/{test_headless.sh,export_android.sh,benchmark.sh}
docs/{README,ART_BIBLE,BALANCE,ANDROID_BUILD,TEST_REPORT}.md
```

## 4. Main scene tree

```
Main (Node)
├── RunDirector (Node)
├── CombatDirector (Node)
│   ├── WaveDirector (Node)
│   ├── EconomySystem (Node)
│   ├── UpgradeSystem (Node)
│   └── AbilitySystem (Node)
├── Battlefield (Node3D)
│   ├── WorldEnvironment
│   ├── DirectionalLight3D
│   ├── Camera3D
│   ├── StaticGeometry (Node3D)
│   ├── RelayCore (Node3D)
│   ├── Warden (CharacterBody3D or Node3D)
│   │   ├── Model (Node3D)
│   │   ├── AnimationTree
│   │   ├── WeaponMount (Marker3D)
│   │   └── WeaponController (Node)
│   ├── EnemyContainer (Node3D)
│   ├── TurretContainer (Node3D)
│   ├── VFXContainer (Node3D)
│   └── SpawnMarkers (Node3D)
└── UI (CanvasLayer)
    ├── CombatHUD (Control)
    ├── UpgradePanel (Control)
    ├── PauseOverlay (Control)
    └── ResultsOverlay (Control)
```

Avoid mixing node ownership with singleton responsibilities. `SaveManager` can be an Autoload; all other systems should be scene-owned for clean resets. Prefer explicit injected references over brittle absolute NodePaths.

## 5. State machine and time

States: `BOOT`, `MENU`, `BRIEFING`, `PREPARING`, `SPAWNING`, `CLEARING`, `INTERMISSION`, `VICTORY`, `DEFEAT`, `PAUSED`. Legal transitions must be centrally validated. `SPAWNING` changes to `CLEARING` after final scheduled spawn; `CLEARING` to `INTERMISSION` when alive count is zero; wave 5 clears to `VICTORY`. Defeat preempts all combat states. Paused stops simulation, spawns, cooldowns, and damage; UI stays responsive.

Use fixed 60 Hz simulation ticks (accumulator with maximum catch-up ticks per render frame) for combat, with a seeded `RandomNumberGenerator`. Track cooldowns in simulation ticks, not wall-clock time. Store all calculations in typed game logic; visual animations only consume events. Record seed and ordered input commands for deterministic replay tests.

Signals (illustrative): `state_changed(old,new)`, `wave_started(index)`, `enemy_spawned(id,type)`, `enemy_killed(id,source)`, `scrap_changed(total)`, `core_integrity_changed(current,max)`, `ability_activated(id)`, `run_completed(result)`.

## 6. Data models and contracts

Prefer typed `Resource` classes for authored game content, with JSON snapshots for testing and balance reports. No freeform strings for core enum-like identifiers outside import boundaries.

```
EnemyDef: id:StringName, max_hp:float, speed:float, armor:float,
          core_damage:float, attack_period:float, scrap_reward:int,
          target_radius:float, prefab:PackedScene
WeaponDef: id:StringName, damage:float, shots_per_second:float,
           magazine:int, reload_seconds:float, armor_pierce:float,
           range:float, target_lock_seconds:float, prefab:PackedScene
SpawnGroup: enemy_id:StringName, count:int, start_seconds:float,
            interval_seconds:float, lane_mode:int
WaveDef: wave_index:int, groups:Array[SpawnGroup], intermission_seconds:float
UpgradeDef: id:StringName, base_cost:int, cost_growth:float,
            max_level:int, modifier_type:int, modifier_value:float
AbilityDef: id:StringName, cooldown_seconds:float, duration_seconds:float
RunState: seed:int, wave_index:int, core_hp:float, scrap:int,
          weapon_id:StringName, upgrade_levels:Dictionary,
          ability_cooldown_ticks:Dictionary, enemies_remaining:int
ProfileSave: schema_version:int, cumulative_data:int,
             missions_completed:int, best_core_hp:int,
             unlocked_weapon_ids:Array[String], settings:Dictionary
```

All combat damage is nonnegative; HP clamped [0,max]. Purchase commands are atomic and idempotent within a frame. Save data is versioned and validated. Never trust serialized data as executable class names or file paths.

## 7. Combat formulas

Initial Warden pistol: 30 raw damage, 2 shots/s, 12-round magazine, 1.25s reload, 0% pierce, 25m range. Initial SMG unlock (one-time Scrap cost 300, available after wave 1): 15 damage, 6 shots/s, 30-round magazine, 1.6s reload, 0% pierce. Upgrade effects apply to the equipped weapon. Weapon unlock replaces pistol for remainder of run; permanent unlock is out of scope.

`effective_damage = base_damage * (1 + 0.20 * damage_level)`

`effective_fire_rate = base_fire_rate * (1 + 0.15 * fire_rate_level)`

`effective_armor = max(0, target_armor * (1 - min(0.90, 0.15 * piercing_level)))`

`applied_damage = max(1, effective_damage - effective_armor)`

Each enemy is targetable if alive, in range and in active lane. Choose highest-priority threat by deterministic tuple: attacking_core first, then shortest ETA to breach, then Rusher priority, then shortest distance, then stable spawn ID. Retain lock for 0.4s unless target dies or breaches; no target thrashing. The Warden can fire across lanes, rotates upper body visually. Hitscan resolves instantly in simulation and spawns a pooled tracer visually. No player aim or touch targeting.

Enemy arrival at breach triggers periodic core attacks (rather than instantaneous deletion) until killed. Enemy collision avoidance can be approximate lane offset/spacing, not full navigation meshes. Clamp attack rate and never let duplicate hit events occur from one attack tick.

## 8. Enemy definitions — initial balance

| Enemy | HP | Speed (m/s) | Armor | Core damage/attack | Period | Scrap |
|---|---:|---:|---:|---:|---:|---:|
| Skitter | 45 | 2.3 | 0 | 12 | 1.5s | 20 |
| Hollow Warden | 150 | 1.1 | 8 | 30 | 2.0s | 35 |
| Rusher | 65 | 3.6 | 2 | 28 | 1.2s | 25 |
| Siege Hulk | 2,800 | 0.65 | 12 | 90 | 2.5s | 400 |

Shieldbearer and Reclaimer are **future content**, not in the five-wave vertical slice. Four archetypes includes boss. No random enemy stat scaling in this slice; all authored values explicit.

## 9. Wave configuration

Three lanes with deterministic round-robin lane assignment plus seeded jitter within ±0.25m. Spawn schedule is relative to wave start. A group's `count` spawns at `start + i * interval`. If multiple spawn same tick, order by group index then enemy index.

| Wave | Groups (count × type) | Start(s) / interval(s) per group | Target active time |
|---|---|---|---|
| 1 | 12 Skitters | 0 / 2.5 | ~45s |
| 2 | 20 Skitters; 4 Hollow Wardens | 0 / 1.5; 12 / 7 | ~50s |
| 3 | 16 Skitters; 8 Hollow Wardens | 0 / 2; 4 / 5 | ~60s |
| 4 | 25 Skitters; 10 Rushers | 0 / 1.5; 8 / 3.5 | ~70s |
| 5 | 1 Siege Hulk; 20 Skitters | 12 / 1; 0 / 2.5 | ~75s |

Intermissions 8s (allow Continue to skip). Wave spawn schedules and DPS are hypotheses requiring simulator tuning; do not assert 5-minute balance until tested. Wave 5 is cleared only when boss AND escorts are eliminated. Boss can enter core attack state if it reaches breach. No enemy despawns silently while alive.

## 10. Economy and upgrades

Scrap starts at 0; all Scrap awarded on confirmed kills exactly once. Approximate total rewards: wave 1 240; wave 2 540; wave 3 600; wave 4 750; wave 5 800 (including boss) = 2,930 total, before upgrades. No Scrap for failed kills or abandoned runs.

`cost(level) = round(base_cost * pow(growth, level))` where level is current purchased count starting at 0. Purchase allowed if `scrap >= cost`, `level < max_level`, and required unlock met. All upgrades apply immediately.

| Upgrade | Base cost | Growth | Max | Effect |
|---|---:|---:|---:|---|
| Damage | 175 | 1.7 | 5 | +20% base damage per level |
| Fire Rate | 150 | 1.6 | 5 | +15% fire rate per level |
| Armor Piercing | 200 | 1.8 | 5 | -15% effective enemy armor per level (cap 90%) |
| Auto Turret | 350 | 2.0 | 2 | Adds one turret, max two |
| SMG unlock | 300 | — | 1 | Replaces pistol with SMG |

Turret stats: 12 damage, 3 shots/s, range 17m, independent targeting, no ammo/reload. Placement uses authored left-side turret markers and deterministic slot selection. Two turret cap. Cannot purchase when slots full.

The initial cost curve makes some options inaccessible in wave 1; this is intentional. UI must show exact cost, current level, max level, projected next-level effect and unavailable reason.

## 11. Abilities

| Ability | Effect | Duration | Cooldown |
|---|---|---|---|
| EMP | Stun normal enemies; boss interrupt | 3s normal / 1s boss | 35s |
| Shield | Absorb up to 100 core damage | 8s or depleted | 50s |
| Overdrive | ×2 current weapon fire rate | 6s | 60s |

All three unlocked at start for test coverage; tutorial introduces them progressively. Cooldowns begin **after effect ends** (except instant EMP, cooldown begins on activation). EMP stun does not stack duration: refresh only if longer than remaining. Boss stun has diminishing immunity of 5s after recovery to prevent chain lock. Shield does not heal the core. Overdrive affects Warden only, not turrets; reloading still occurs. Ability activation fails cleanly if paused, on cooldown, or run ended; failed activations do not start cooldown.

## 12. UI interaction specification

- Top HUD: core current/max and percentage; wave index/5; Scrap amount; pause. Use safe area margins.
- Combat bottom panel: a collapsible Upgrade button showing affordable count; three large ability buttons with icons, cooldown radial fill and numeric countdown. An intermission panel opens automatically.
- Upgrade overlay: five cards (Damage, Fire Rate, Piercing, Turret, SMG), cost, level, effect, purchase button; underlying combat **continues** unless explicitly paused in settings. To avoid surprise, UI shows 'Combat continues' banner. Optional intermission pause is a later feature.
- Feedback: short purchase pulse, floating +Scrap label, enemy impact flash, boss health bar, clear warnings when core <25%, audio/haptic toggle.
- Menu: Start Mission, Settings, Exit; result screen: Victory/Defeat, waves cleared, kills, core remaining, Recovered Data, Retry, Main Menu.
- Accessibility: font sizes scale, no critical text below 14sp equivalent, contrast 4.5:1 where practical, reduced flash setting, no information conveyed by color alone, touch areas >=48dp.
- Portrait cutouts/foldables: use DisplayServer safe area / Android insets via supported Godot APIs, test both folded/unfolded sizes; never position controls by hard-coded pixel offsets.

## 13. Persistence

Store at `user://profile_v1.json`. Data: `schema_version`, cumulative recovered data, missions completed, best remaining core HP, audio/visual settings. Save after result screen via write-temp, flush/close, rename/replace; keep backup of last good save. On corrupt JSON, recover backup and show non-blocking warning; do not crash. Persist **only** completed run rewards for slice; mid-run resume is out of scope. Recovered Data formula: victory 100 + floor(core_hp / 20), defeat 10 × completed_waves, no negative values. Ensure rewards granted exactly once even if result screen reopened. Save migration from unknown versions must not silently overwrite profile.

## 14. Asset manifest

### Required 3D models

| Asset ID | Quantity | Animation/variant requirements |
|---|---:|---|
| `warden_defender` | 1 | idle, aim, fire, reload, hit, death; upper-body aim pivot |
| `enemy_skitter` | 1 | locomotion, attack, hit, death |
| `enemy_hollow` | 1 | locomotion, attack, hit, death |
| `enemy_rusher` | 1 | sprint, attack, hit, death |
| `boss_siege_hulk` | 1 | heavy walk, attack, stagger, death |
| `weapon_pistol` | 1 | muzzle mount, optional slide |
| `weapon_smg` | 1 | muzzle mount, reload |
| `auto_turret` | 1 | yaw/pitch, fire, deployment |
| `relay_core` | 1 | idle pulse, damage states, failure |
| `industrial_battlefield` | 1 modular set | floor, walls, gantries, crates, lights, pipes, barricades |

### Required textures/materials

PBR gunmetal, worn bone ceramic, black rubber, orange emissive core, cyan ally emissive, red hostile emissive, wet concrete, caution stripes, damaged painted steel. Prefer texture atlases and material reuse; use compressed textures appropriate for Android. Enemy/ally silhouettes and colors must remain clear at native mobile viewing size.

### Required effects and audio

Pistol/SMG muzzle flash, ballistic tracer, impact sparks, hit flash, enemy death burst, scrap pickup text, EMP radial pulse, shield shimmer, overdrive glow, turret muzzle flash, boss impact, core hit warning. Audio: two weapons, four enemy attack/death families, turret, three abilities, UI purchase/error, wave transition, boss stinger, victory/defeat, ambient industrial loop. All effects must be poolable or rate-limited.

### Asset performance budgets (initial targets)

Warden 12–20k triangles; Skitter 2–4k; Hollow 4–6k; Rusher 3–5k; Hulk 15–25k; turret 3–5k. Target ≤50 visible enemies for first slice and a fallback crowd LOD; budgets are targets to profile, not hard engine limits. Keep animated bone counts economical. Avoid unique 2K textures on every enemy; prefer 512–1024 maps, atlas sharing and mipmaps. Use mesh instancing for non-skinned props. Profile memory and draw calls on device before setting release caps.

## 15. Testing and acceptance matrix

Unit tests (headless GdUnit4 or equivalent):
1. Target selection ordering and deterministic tie-break; target lock and dead-target release.
2. Weapon shot cadence, magazine/reload behavior, armor math, upgrade modifiers and cap.
3. Enemy spawn counts, ordering and lane assignment for fixed seed; no duplicate spawn.
4. Enemy damage to core only after reaching breach, attack interval, HP clamp.
5. Scrap granted exactly once on death; purchase atomicity, insufficient funds, max level, cost growth.
6. EMP duration and boss resistance, Shield depletion and expiry, Overdrive expiry and reload interaction.
7. Victory only when wave 5 schedule and all enemies cleared; defeat preemption; pause freezes simulation.
8. Save round-trip, corruption fallback, schema mismatch, idempotent rewards.

Integration tests:
- Fresh start → 5 waves → victory with boosted debug damage; verify save.
- Fresh start → no upgrades → defeat under controlled fixture; verify no victory grant.
- Purchase SMG/turret and verify actual combat behavior, not only UI labels.
- Tap each ability during cooldown and while paused; verify rejected commands.
- Reset/retry 100 times in headless mode; no leaked enemies/turrets/signals.
- Fixed seed + fixed command stream produces identical kill order, Scrap, core HP and result.

Android manual smoke:
- Cold launch, pause/resume, home/background/foreground, screen lock/unlock, orientation lock, back gesture, safe-area/cutout, foldable dimensions, sound toggle, airplane mode, reinstall persistence expectation (uninstall clears app data), 15-minute thermal test.
- Verify no network permission is necessary for gameplay.
- Performance: median frame time ≤16.7ms on target high-tier device, 95th percentile ≤33.3ms in worst wave; no multi-second hitches, crash, or memory runaway. Record actual device, OS, build, renderer, resolution, quality preset, max concurrent enemies and capture logs. Do not claim 60 FPS merely because editor runs at 60.

## 16. Implementation phases / agent milestones

**P0 — Repository and build foundation:** create isolated project, Godot 4.7.2 pin, lint/test/export scripts, portrait Android boot. Exit: debug APK launches, CI runs tests.

**P1 — Deterministic simulation:** state machine, fixed tick, Warden auto-fire, enemy lanes, core damage, wave scheduler. Exit: five waves can run headless with deterministic seed; win/loss reproducible.

**P2 — Economy and abilities:** Scrap, upgrade costs, SMG, turret, EMP, shield, overdrive. Exit: all effects measurable in simulation; unit tests green.

**P3 — UI and persistence:** combat HUD, upgrades, pause, results, local save. Exit: complete end-to-end playable run with placeholder geometry and no network.

**P4 — Cinematic 3D pass:** models, rigs, VFX, sound, lighting, optimized environment. Exit: silhouettes readable, no gameplay logic dependent on visuals.

**P5 — Android hardening:** profiling, LOD, pool sizing, safe area/foldables, accessibility, thermal test, export. Exit: acceptance matrix passes on physical Android device and benchmark report attached.

Each phase should produce a small PR with screenshots, test logs, reproducible commands, known issues and a clear rollback path. No phase is complete without running the applicable tests.

## 17. Agent coding conventions

- Use static typing in GDScript, avoid `Variant` where practical; `class_name` for data resources and domain services where appropriate.
- Prefer `@export` authored parameters and `.tres` data, no gameplay constants hidden in UI scripts.
- Keep enemy presentation decoupled from health/combat logic; no damage applied by animation signals.
- Use a seeded RNG service; no global random calls in simulation.
- Signals should be disconnected on teardown; pooled objects reset all state before reuse.
- No per-frame dynamic allocations in high-volume enemy loops where avoidable; avoid one `Timer` node per enemy.
- Log wave and purchase events in debug builds; suppress verbose logs in release.
- Explicitly document renderer differences, Android SDK/NDK requirements and exported package IDs.
- Do not introduce analytics, ads, login, online services or paid assets into the slice.

## 18. Known open decisions and risks

1. **Canon:** Cinder/ASH-07 is the original Warden; this spin-off needs a new Warden designation. `The Breach of Cinder` is a proposed event name, not established canon. Confirm with lore owner before final story copy.
2. **Core label:** Concept art saying `RELAY CORE ASH-07` conflates the character ID and relay core; replace with `RELAY CORE B-4` in production.
3. **Visual feasibility:** cinematic concept art is not a real-time asset specification. Mobile rendering quality and enemy counts must be validated on physical devices.
4. **Balance:** five-minute duration and economy must be established through deterministic simulations and playtests, not assumed from spreadsheets.
5. **Wave scope:** five waves, not ten; only Skitter, Hollow Warden, Rusher, Siege Hulk are included.
6. **Upgrade UI behavior:** combat continues while upgrade overlay is open; assess whether this is too punishing in playtests.
7. **Repository reuse:** the original project's license is unspecified; treat third-party content separately and avoid unreviewed copying.

## 19. Final delivery checklist

Deliver: Godot source, `.tres` content, Android debug APK, export documentation, asset manifest with license/source provenance, unit/integration tests, deterministic balance simulation report, on-device performance report, screenshots of main menu/combat/upgrade/boss/results, and a `KNOWN_ISSUES.md` file. Record exact Godot, Android SDK, Java and plugin versions. The coding agent must distinguish verified working behavior from planned or mocked UI.

