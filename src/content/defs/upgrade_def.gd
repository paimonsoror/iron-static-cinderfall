class_name UpgradeDef
extends RefCounted

enum Kind { STAT, TURRET, WEAPON_UNLOCK }

var id: StringName
var index: int
var name_key: String
var kind: int
var base_cost: int
var growth: float
var max_level: int
var per_level: float
var cap: float
var min_wave: int
var weapon_index: int = -1  ## -1 unless WEAPON_UNLOCK
var turret_damage: float
var turret_sps_milli: int
var turret_range_m: float
var turret_lock_ticks: int
