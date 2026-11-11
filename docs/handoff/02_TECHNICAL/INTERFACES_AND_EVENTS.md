# Required data contracts and event API
Use typed GDScript `Resource` for authored data; `03_DATA` JSON is an implementation-neutral baseline and simulator oracle.

`EnemyDef(id, hp, speed, armor, core_damage, attack_period, scrap, collision_radius, visual_scene)`
`WeaponDef(id, damage, shots_per_second, magazine, reload_seconds, range, pierce, visual_scene)`
`SpawnGroup(enemy_id, count, start_seconds, interval_seconds, region_id, seed_offset)`
`WaveDef(index, groups, peak_target, intermission_seconds)`
`UpgradeDef(id, base_cost, growth, max_level, modifier)`
`AbilityDef(id, cooldown_seconds, duration_seconds, effect)`
`RunState(run_id, seed, tick, wave, core_hp, scrap, weapon_id, levels, ability_cooldowns, live_enemy_ids, state)`
`ProfileSave(schema_version, data, missions_completed, best_core_hp, settings, awarded_run_ids)`

**Signals**: `state_changed(previous,current)`, `wave_started(index)`, `enemy_spawned(id,kind)`, `enemy_damaged(id,amount,source)`, `enemy_killed(id,source)`, `scrap_changed(value)`, `core_changed(current,max)`, `purchase_resolved(command_id,success,reason)`, `ability_activated(id)`, `run_finished(result,run_id)`.

**Commands**: `purchase_upgrade(command_id,upgrade_id)`, `activate_ability(command_id,ability_id)`, `skip_intermission()`, `pause()`, `resume()`. All commands validated against state machine; replay logs contain tick, command ID, payload and seed.

**State machine**: BOOT → MENU → BRIEFING → PREPARING → SPAWNING → CLEARING → INTERMISSION → SPAWNING … → VICTORY; DEFEAT preempts combat; PAUSED overlays previous state. Wave only completes when all scheduled spawns finished AND living enemies zero. Guard against stuck enemy deadlock with diagnostics and deterministic reposition fallback.
