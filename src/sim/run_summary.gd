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
# --- variety milestone (VARIETY_SPEC 13.2) ---
var act_reached: int = 1
var combat_ticks: int = 0
var directives: PackedInt32Array = PackedInt32Array()  ## stacks per directive index at the end of the run
var weapons: PackedInt32Array = PackedInt32Array()  ## weapon index per slot at the end (-1 = empty)
var route_choices: PackedInt32Array = PackedInt32Array()
var core_damage_by_type: PackedFloat64Array = PackedFloat64Array()
var damage_by_source: PackedFloat64Array = PackedFloat64Array()
var events_seen: PackedInt32Array = PackedInt32Array()
var crates_secured: int = 0
var boss_ids: PackedInt32Array = PackedInt32Array()
