class_name AudioTestEvents
extends Node
## A stand-in for the `Events` autoload that declares only the signals the audio router listens to (same names
## and payloads as ARCH 7.1), so router tests never touch the real bus or the global `Sfx`.

@warning_ignore_start("unused_signal")
signal run_started(run_id: String, run_seed: int)
signal run_finished(result: int, run_id: String)
signal state_changed(previous: int, current: int)
signal wave_started(index: int)
signal wave_cleared(index: int)
signal intermission_started(wave_cleared: int, ticks: int)
signal enemy_spawned(id: int, kind: StringName)
signal boss_spawned(id: int, kind: StringName)
signal enemy_damaged(id: int, amount: float, source: int)
signal enemy_killed(id: int, source: int)
signal shot_fired(source: int, target_id: int)
signal weapon_changed(id: StringName)
signal core_hit(enemy_id: int, kind: StringName, hp_damage: float, absorbed: float)
signal core_changed(current: float, max_value: float)
signal ability_activated(id: StringName)
signal ability_ended(id: StringName)
signal reload_started(ticks: int)
signal reload_finished
# --- variety milestone (VARIETY_SPEC 13.4) ---
signal act_started(act: int)
signal await_changed(kind: int)
signal draft_offered(ids: Array[StringName])
signal directive_picked(id: StringName, stacks: int)
signal route_offered
signal route_picked(option: int)
signal crate_dropped(x: float, z: float)
signal crate_secured
signal crate_lost
signal salvage_offered
signal weapon_swapped(slot: int, id: StringName)
signal weapon_vented(slot: int)
signal area_blast(kind: int, x: float, z: float, radius: float)
signal chain_arc(from_id: int, to_id: int)
signal delayed_hit(kind: int, x: float, z: float, ticks: int)
signal elite_spawned(id: int, kind: StringName, affixes: int)
signal ward_changed(id: int, fraction: float)
signal event_warned(id: StringName, ticks: int, x: float, z: float)
signal event_started(id: StringName)
signal event_ended(id: StringName)
signal boss_telegraph(attack: int, ticks: int)
signal boss_phase(phase: int)
signal unlock_purchased(id: StringName)
signal burster_armed(id: int)
signal weapon_charging(slot: int)
@warning_ignore_restore("unused_signal")
