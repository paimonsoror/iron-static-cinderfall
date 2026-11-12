class_name WeaponDef
extends RefCounted

## Firing kinds (VARIETY_SPEC 3.3). ArsenalSystem dispatches on it; the legacy pistol and SMG are HITSCAN.
enum Kind { HITSCAN, CONE, ARC, LINE, SHELL, MISSILES, BEAM }

const KIND_NAMES: PackedStringArray = ["hitscan", "cone", "arc", "line", "shell", "missiles", "beam"]

var id: StringName
var index: int
var name_key: String
var damage: float
var sps_milli: int  ## shots per second x 1000, integer
var magazine: int
var reload_ticks: int
var range_m: float
# --- variety milestone (data/weapons.json, CONTENT 2; legacy content keeps these defaults) ---
var tier: int = 1
var kind: int = Kind.HITSCAN
var min_range_m: float = 0.0
var spread_deg: float = 0.0
var pierce: int = 0  ## -1 = every enemy on the line
var pierce_falloff: float = 1.0
var area_m: float = 0.0
var edge_frac: float = 1.0  ## damage at the edge of the area, as a fraction
var pellets: int = 0
var salvo: int = 0
var splash_damage: float = 0.0
var flight_ticks: int = 0
var chains: int = 0
var chain_range_m: float = 0.0
var chain_falloff: float = 1.0
var charge_ticks: int = 0
var heat_per_shot: int = 0  ## heat is an integer 0..heat_cap (VARIETY_SPEC 9.5)
var cool_per_s: int = 0
var heat_cap: int = 0  ## > 0 = a heat weapon (no magazine)
var vent_ticks: int = 0
var armor_ignore: float = 0.0  ## 0..1 of the armor ignored
var ward_mult: float = 1.0
var stunned_mult: float = 1.0
var spin_up_ticks: int = 0
var sps_min_milli: int = 0  ## the rate at the start of the spin-up (0 = no spin-up)
var stray_chance: float = 0.0
var armor_shred: float = 0.0
var ramp_per_hit: float = 0.0
var ramp_cap: float = 0.0
var pool_ticks: int = 0
var pool_dps: float = 0.0
var pool_slow: float = 0.0
var pool_radius_m: float = 0.0
var knockback_m: float = 0.0
var level_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])  ## damage multiplier at level 1, 2, 3
var level3: Dictionary[StringName, float] = {}  ## the level-3 perk: field name -> value


func is_heat() -> bool:
	return heat_cap > 0
