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
# --- variety milestone (data/run.json; legacy content keeps these defaults) ---
var swarm_cap: int = 0  ## minis alive at once; 0 in the legacy content
var breather_ticks: int = 0  ## the countdown after the last intermission choice
var shop_enabled: bool = true  ## false = EconomySystem.purchase answers SHOP_CLOSED (V2-B)
