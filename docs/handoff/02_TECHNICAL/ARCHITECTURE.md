# Implementation architecture
## Engine and target
Prefer Godot 4.7.2 **only if compatible/available**, otherwise report selected stable Godot 4.x version and justification. GDScript, Android portrait, Mobile renderer. Build offline-first; record Android SDK, JDK, Gradle/export template and package ID. Debug APK required; signing for production not in scope.

## Proposed tree
```
project.godot
scenes/app/{main,menu,briefing,results}.tscn
scenes/combat/{battlefield,warden,relay_core,enemy,auto_turret}.tscn
scenes/ui/{combat_hud,upgrade_panel,pause_overlay}.tscn
scripts/app/{run_director,save_manager}.gd
scripts/combat/{combat_clock,wave_director,spawn_manager,enemy_model,enemy_view,enemy_steering,target_selector,weapon_controller,damage_resolver,core_controller,turret_controller,ability_system}.gd
scripts/economy/{economy_system,upgrade_system}.gd
scripts/ui/{combat_hud,upgrade_panel,results}.gd
scripts/data/{enemy_def,weapon_def,spawn_group,wave_def,upgrade_def,ability_def}.gd
scripts/util/{rng_service,object_pool,spatial_grid}.gd
data/{enemies,weapons,waves,upgrades,abilities}/*.tres
assets/{models,materials,vfx,audio,ui}/
tests/{unit,integration,simulation,smoke}/
tools/{test_headless,export_android,benchmark}.sh
```

## Scene tree
```
GameRoot (Node)
├── RunDirector (Node)
├── WaveDirector (Node)
├── CombatClock (Node)
├── EconomySystem (Node)
├── UpgradeSystem (Node)
├── AbilitySystem (Node)
├── Battlefield (Node3D)
│   ├── WorldEnvironment
│   ├── DirectionalLight3D
│   ├── CameraRig/Camera3D
│   ├── RelayCore (Node3D)
│   ├── Warden (Node3D)
│   ├── EnemyContainer (Node3D)
│   ├── TurretContainer (Node3D)
│   ├── VFXContainer (Node3D)
│   ├── SpawnRegion (Node3D)
│   └── StaticObstacles (Node3D)
└── UILayer (CanvasLayer)
    ├── CombatHUD (Control)
    ├── UpgradePanel (Control)
    ├── PauseOverlay (Control)
    └── ResultsOverlay (Control)
```
SaveManager as autoload; scene-owned services reset each run. Use typed signals and injected references, not hard-coded global paths.

## Deterministic simulation
Run combat at fixed 60 ticks/s using a capped accumulator; same seed + ordered commands yields same result. Stable integer enemy IDs; sort ties by ID. All cooldowns/attack timers measured in simulation ticks. RNG via seeded `RandomNumberGenerator`, never global random calls in combat. Store ordered purchase/ability command stream for replay. Presentation reads events and interpolates transforms; animations must never apply damage. Pause freezes simulation clock and cooldowns.

## Continuous arena movement
World bounds and spawn polygons are authored data. Spawn on right and upper-right perimeter; each enemy moves toward a core attack ring, choosing a reachable attack slot via deterministic assignment. For 50 entities, avoid per-agent NavigationAgent3D every frame: static flow field or cached paths around obstacles, with spatial hash neighbor queries and capped local separation. Steering update frequency may be 10–20Hz, interpolated at render rate. Prevent overlaps near core by assigning attack slots. Debug visualize paths/blocked enemies. Stuck recovery must be visible/logged and deterministic, never silently despawn living enemies.

## Targeting
Filter living/in-range targets. Score by: currently attacking core > minimum estimated time to breach > Rusher class > distance > stable enemy ID. Keep lock ~0.4s unless target invalid; avoid rapid switching. Weapon hit calculations use deterministic hitscan; raycast obstruction policy must be explicit and tested. Turrets use independent targeting. Never let one enemy grant Scrap twice.

## Combat formula
`damage = max(1, base_damage * (1 + 0.20 * damage_level) - max(0, enemy_armor * (1 - min(0.90, 0.15 * piercing_level))))`
`shots_per_second = base_sps * (1 + 0.15 * fire_rate_level) * (2.0 if overdrive else 1.0)`
Magazine/reload applies to Warden; turret has no reload. Boss uses standard armor and short EMP interruption with immunity window. HP clamped 0..max.

## Purchase transactions
On command: check current state, prerequisites, max level, funds; calculate price using integer rounding; debit exactly once; increment level; apply modifier; emit event. Command IDs prevent double-tap duplicate purchases in same tick. Failed commands leave state unchanged.

## Persistence
`user://profile_v1.json`, schema version, cumulative Recovered Data, completed missions, best remaining core HP, settings. Atomic temp write/replace plus backup, validate on load, recover corrupt save gracefully. Rewards granted once per run ID; no mid-run resume. Victory reward = 100 + floor(core_hp/20), defeat = 10 * completed waves.

## UI
Portrait design reference 1080x2400; adapt via anchors and safe-area margins. Top: core integrity, wave/5, Scrap, pause. Center: clear battlefield. Bottom: compact upgrade drawer + three large abilities. Cards show exact cost/level/effect/lock state. Use scalable Godot Controls and theme resources, not baked text. Tap target >=48dp equivalent, reduced flash, sound/haptics toggles. Boss health bar only when boss alive. Provide high-contrast status text and icons.

## Performance
Performance target: 50 simultaneous enemies on reference Android device, 60 FPS aspirational/30 FPS fallback. Record actual frame timings, CPU/GPU where available, memory, thermal throttling and effect toggles. Enemy pooled nodes, shared meshes/materials, multi-mesh where animation permits, capped particle emitters, few shadow-casting lights, no real-time GI, LOD/animation tick throttling, cheap impact decals. No promises until measured on hardware.
