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


## Called at the end of every tick: peak alive per wave.
func sample(world: SimWorld) -> void:
	var w: int = clampi(world.wave, 0, peak_alive_by_wave.size() - 1)
	var alive: int = world.alive_count()
	if alive > peak_alive_by_wave[w]:
		peak_alive_by_wave[w] = alive
