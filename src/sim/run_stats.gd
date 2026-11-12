class_name RunStats
extends RefCounted
## Per-run counters. Written by SimWorld mutators and PhaseSystem; read by summary().

var kills_by_type: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var peak_alive_by_wave: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])  ## index = wave
var wave_start_tick: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var wave_clear_tick: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var scrap_earned: int = 0
var scrap_spent: int = 0
var core_damage_taken: float = 0.0
var damage_absorbed: float = 0.0
var stuck_recoveries: int = 0
var max_pending: int = 0
# --- variety milestone (VARIETY_SPEC 13.2); each field is written by the system that owns the moment ---
var act_reached: int = 1
var combat_ticks: int = 0  ## ticks spent in SPAWNING or CLEARING
var directives: PackedInt32Array = PackedInt32Array()  ## directive indices in pick order
var weapons: PackedInt32Array = PackedInt32Array()  ## weapon indices in the order they were first carried
var route_choices: PackedInt32Array = PackedInt32Array()  ## option picked per wave (index = wave), -1 = no choice
var core_damage_by_type: PackedFloat64Array = PackedFloat64Array()  ## core hp removed, by enemy type
var damage_by_source: PackedFloat64Array = PackedFloat64Array()  ## enemy hp removed, by DamageSource.Id
var events_seen: PackedInt32Array = PackedInt32Array()  ## starts, by event index
var crates_secured: int = 0
var boss_ids: PackedInt32Array = PackedInt32Array()  ## enemy index of every boss that spawned


## Sizes the per-type and per-wave arrays from the content (never smaller than the legacy sizes).
func setup(content: ContentSet) -> void:
	var types: int = maxi(kills_by_type.size(), content.enemies.size())
	var waves: int = maxi(content.waves.size(), content.run.waves.size() if content.run != null else 0)
	var slots: int = maxi(peak_alive_by_wave.size(), waves + 1)
	kills_by_type.resize(types)
	peak_alive_by_wave.resize(slots)
	wave_start_tick.resize(slots)
	wave_clear_tick.resize(slots)
	route_choices.resize(slots)
	route_choices.fill(-1)
	core_damage_by_type.resize(types)
	damage_by_source.resize(DamageSource.COUNT)
	events_seen.resize(content.events.size())


## Called at the end of every tick: peak alive per wave, combat time, the act reached.
func sample(world: SimWorld) -> void:
	if GameState.is_combat(world.phase):
		combat_ticks += 1
	act_reached = maxi(act_reached, world.phase_state.act)
	var w: int = clampi(world.wave, 0, peak_alive_by_wave.size() - 1)
	var alive: int = world.alive_count()
	if alive > peak_alive_by_wave[w]:
		peak_alive_by_wave[w] = alive
