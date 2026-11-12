class_name EnemyDef
extends RefCounted

## Variety (VARIETY_SPEC 5, CONTENT 4.1): bodied enemies take an attack slot and count toward enemy_cap; minis are
## instanced, count toward swarm_cap and burn out on the core; standoff types hold a standoff point instead of a slot.
enum BodyClass { BODIED, MINI, STANDOFF }

const CLASS_NAMES: PackedStringArray = ["bodied", "mini", "standoff"]

var id: StringName
var index: int
var name_key: String
var hp: float
var speed_mps: float
var armor: float
var core_damage: float
var attack_period_ticks: int
var scrap: int
var radius: float
var mass: float
var separation_weight: float
var weave_amp_m: float
var weave_period_ticks: int
var direct_seek: bool
var is_boss: bool
var priority_class: bool
var slot_span: int
var visual_id: StringName  ## == id in the slice
var visual_height_m: float
# --- variety milestone (legacy content keeps these defaults) ---
var enemy_class: int = BodyClass.BODIED
var cost: float = 0.0  ## threat points; 0 = never bought from a wave budget
var min_act: int = 1
var alive_cap: int = 0  ## the most of this type alive at once (= its view pool); 0 = no type cap
var standoff_m: float = 0.0
var behaviour: Dictionary[StringName, float] = {}  ## CONTENT 4.2 fields; enemy ids are stored as their index


func beh(key: StringName, fallback: float = 0.0) -> float:
	return behaviour.get(key, fallback)


func is_mini() -> bool:
	return enemy_class == BodyClass.MINI
