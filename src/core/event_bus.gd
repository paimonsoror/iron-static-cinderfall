extends Node
## `Events` autoload: every cross-layer signal (ARCH 7.1). RunController is the only emitter of the
## gameplay signals. Signals are emitted from other classes, so unused_signal is silenced here.

@warning_ignore_start("unused_signal")
# --- handoff signals (adopted) ---
signal state_changed(previous: int, current: int)  ## GameState.Id, application-level (includes PAUSED)
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
signal reload_finished
signal ability_ended(id: StringName)
signal ability_rejected(id: StringName, reason: int)
signal enemy_stunned(id: int, ticks: int)
signal enemy_stuck(id: int)
signal profile_changed
signal settings_changed(key: StringName)
signal hint_requested(key: String)
# --- variety milestone (VARIETY_SPEC 13.4; append only). Ids are StringNames of the data files. ---
signal act_started(act: int)
signal await_changed(kind: int)  ## RunApi.AWAIT_*
signal draft_offered(ids: Array[StringName])  ## directive id per slot; also after a reroll
signal directive_picked(id: StringName, stacks: int)
signal route_offered
signal route_picked(option: int)
signal crate_dropped(x: float, z: float)
signal crate_secured
signal crate_lost
signal salvage_offered
signal weapon_swapped(slot: int, id: StringName)
signal weapon_vented(slot: int)
signal area_blast(kind: int, x: float, z: float, radius: float)  ## kind = HazardState.K_*, radius in meters
signal chain_arc(from_id: int, to_id: int)  ## enemy ids; from_id 0 = the Warden
signal delayed_hit(kind: int, x: float, z: float, ticks: int)
signal pool_changed(id: int, x: float, z: float, radius: float, on: bool)
signal elite_spawned(id: int, kind: StringName, affixes: int)  ## affixes = bit mask of AffixDef indices
signal ward_changed(id: int, fraction: float)  ## 0.0 = broken
signal event_warned(id: StringName, ticks: int, x: float, z: float)
signal event_started(id: StringName)
signal event_ended(id: StringName)
signal boss_telegraph(attack: int, ticks: int)
signal boss_phase(phase: int)
signal charges_changed(id: StringName, n: int)
signal command_rejected(command_id: int, reason: int)
signal unlock_purchased(id: StringName)
# --- slice integration (V3-I; append only) ---
signal burster_armed(id: int)  ## an enemy with a fuse reached its slot: it goes off when the fuse (1.2 s) ends
@warning_ignore_restore("unused_signal")
