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
@warning_ignore_restore("unused_signal")
