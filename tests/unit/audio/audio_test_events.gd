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
@warning_ignore_restore("unused_signal")
