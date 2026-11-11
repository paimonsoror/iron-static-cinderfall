class_name MissionDef
extends RefCounted
## Mission-wide numbers (ARCH 5.3). Times are integer ticks.

var id: StringName
var name_key: String
var core_max_hp: float
var ticks_per_second: int
var enemy_cap: int
var intermission_ticks: int
var prepare_ticks: int
var target_duration_min_s: float
var target_duration_max_s: float
var reward_victory_base: int
var reward_core_hp_divisor: int
var reward_defeat_per_wave: int
var lock_ticks: int
var eta_bucket_ticks: int
var max_spawns_per_tick: int
var stuck_ticks: int
var stuck_min_progress_m: float
