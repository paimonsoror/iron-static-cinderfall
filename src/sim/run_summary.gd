class_name RunSummary
extends RefCounted
## The exported result of a run (SimWorld.summary).

var run_id: String
var run_seed: int
var result: int
var waves_completed: int
var core_hp: int
var core_max_hp: int
var duration_ticks: int
var kills_by_type: PackedInt32Array = PackedInt32Array()
var peak_alive_by_wave: PackedInt32Array = PackedInt32Array()
var scrap_earned: int
var scrap_spent: int
var data_reward: int
